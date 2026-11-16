# Backup CronJobs

This page explains the scheduled backup jobs in
[`roles/master/corn-jobs/backups/`](../roles/master/corn-jobs/backups/). The
YAML manifests are the source of truth; check them when changing this document.

## What a Kubernetes CronJob does

A Kubernetes `CronJob` is a schedule for creating short-lived `Job` objects. A
Job starts one or more pods and tracks whether the task completes successfully.
Here, each pod runs a shell script that makes a database dump or copies files
to a disk mounted on the `zotac` node.

The schedule uses the five-field cron format:

```text
minute hour day-of-month month day-of-week
```

All four manifests set `timeZone: Europe/Vienna`, so their times follow local
Vienna time, including daylight-saving changes. The jobs are staggered so
database dumps finish before their corresponding file copies start:

| CronJob | Namespace | Time | Data | Destination on zotac |
|---|---|---:|---|---|
| `postgres-backup` | `database` | 03:00 daily | Main PostgreSQL globals and databases (currently ownCloud) | `/mnt/backup-db/main` |
| `immich-postgres-backup` | `immich` | 03:15 daily | Immich PostgreSQL cluster dump | `/mnt/backup-db/immich` |
| `owncloud-files-backup` | `owncloud` | 03:30 daily | ownCloud files | `/mnt/backup-files/owncloud` |
| `immich-files-backup` | `immich` | 03:45 daily | Immich photo/video library | `/mnt/backup-files/immich` |

Each pod is constrained to the node named `zotac`. The backup disk is provided
to the pod with a `hostPath`, which means that the expected disk mount must
already exist on that node. The scripts check for a `.mounted` marker before
writing. This guards against writing backups into an ordinary empty mount
directory if a disk is missing.

`concurrencyPolicy: Forbid` prevents a new scheduled run from starting while a
previous run of the same CronJob is active. The database jobs have a one-hour
deadline and the file jobs have a one-day deadline. A failed job is retried
according to its `backoffLimit`. Kubernetes keeps the last three successful
and failed Jobs for inspection.

## How the database scripts work

The two database CronJobs are in
[`psql-backups.yaml`](../roles/master/corn-jobs/backups/psql-backups.yaml).
Their pods connect to the database Services using `PGHOST`, `PGPORT`, and
`PGUSER`. `PGPASSWORD` is read from a Kubernetes Secret; the password itself
is not stored in this manifest. The backup volume is mounted at `/backup`.

### Main PostgreSQL

The main job uses `postgres:17`, so its PostgreSQL client tools match the
configured server major version. It performs these steps:

1. Stops immediately on a shell command error (`set -euo pipefail`).
2. Checks `/backup/.mounted`, then writes under `/backup/main`.
3. Uses a timestamp in each output filename. `pg_dumpall --globals-only`
   saves cluster-wide roles and settings to a compressed SQL file.
4. Queries PostgreSQL for every non-template database except the `postgres`
   maintenance database, then writes each database as a custom-format
   `pg_dump` file. Custom format is restored with `pg_restore`.
5. Writes each dump to a `.partial` name first, then renames it when complete.
   The rename avoids presenting an incomplete dump as a finished backup.
6. Deletes completed dump files older than the configured 14-day retention
   period and removes stale `.partial` files older than two hours.

The list of databases is discovered at runtime. In the observed run, the log
reported `dumping owncloud`.

### Immich PostgreSQL

The Immich job uses a pinned Immich PostgreSQL image containing PostgreSQL 14
and its extensions. It checks `/backup/.mounted` and writes one cluster-wide
`pg_dumpall --clean --if-exists` SQL dump, compressed with gzip. This format
includes the database objects and emits cleanup statements for a restore into
an appropriate Immich PostgreSQL instance. As with the main job, it uses a
`.partial` filename until the dump is complete and removes dumps older than
14 days plus stale partial files older than two hours.

Both database jobs read credentials from Secrets (`postgres-secret` and
`immich-secrets`). Keep those values private. The CronJobs create logical
dumps; they do not continuously archive PostgreSQL WAL files, so they do not
provide point-in-time recovery between daily runs.

## How the file copy scripts work

The file CronJobs are in [`owncloud-files.yaml`](../roles/master/corn-jobs/backups/owncloud-files.yaml)
and [`immich-photos.yaml`](../roles/master/corn-jobs/backups/immich-photos.yaml).
They use the `alpine:3` image, install `rsync` at startup, and mount the source
NFS export read-only. The destination is the backup disk mounted at `/backup`.

Both scripts follow the same snapshot procedure:

1. Enable shell error handling (`set -eu`) and install `rsync`.
2. Check the backup disk's `.mounted` marker and verify the source directory
   is not empty. These checks help catch missing mounts or inaccessible NFS
   exports instead of treating an empty source as the real data.
3. Set the snapshot directory to `/backup/<app>/snapshots`. If a `latest`
   snapshot exists, pass it to rsync as `--link-dest`.
4. Run `rsync -aH --delete --numeric-ids` into `.in-progress`. Archive mode
   preserves common file metadata, `-H` preserves hard links, `--numeric-ids`
   keeps numeric ownership IDs, and `--delete` removes from the in-progress
   copy files that no longer exist in the source. With `--link-dest`, unchanged
   files are hard-linked from the prior snapshot, saving space while each
   snapshot still appears as a full directory tree.
5. Accept rsync exit code 24, which means some source files vanished during
   the live copy; fail for other nonzero exit codes. The source may change
   while a snapshot is being made, so these copies are not an atomic
   application-level snapshot.
6. Rename `.in-progress` to a timestamped snapshot, update the `latest`
   symlink, then keep the newest 14 snapshots and delete older ones.
7. Print the snapshots and filesystem usage in the Job log.

ownCloud reads `100.99.212.60:/mnt/nas/owncloud-docs` and skips `cache/`
directories. Immich reads `100.99.212.60:/mnt/nas/immich-photos` and skips
`thumbs/` and `encoded-video/`. Confirm these exclusions are appropriate for
the recovery needs of each application.

The database and file schedules are ordered to run database dumps first. They
are separate jobs, however, and this timing alone does not guarantee that a
database dump and the later file snapshot represent one perfectly consistent
point in time while an application is actively changing data.

## Checking a run

List schedules and recent jobs:

```sh
kubectl get cronjobs -A -o wide
kubectl get jobs -A --sort-by=.metadata.creationTimestamp
```

Get a particular Job's logs (replace the name with the current Job name):

```sh
kubectl logs -n database job/postgres-backup-<job-suffix>
kubectl logs -n immich job/immich-postgres-backup-<job-suffix>
kubectl logs -n owncloud job/owncloud-files-backup-<job-suffix>
kubectl logs -n immich job/immich-files-backup-<job-suffix>
```

On `zotac`, inspect the destination files and mounted filesystems:

```sh
df -h /mnt/backup-db /mnt/backup-files
ls -lah /mnt/backup-db/main /mnt/backup-db/immich
ls -lah /mnt/backup-files/owncloud/snapshots /mnt/backup-files/immich/snapshots
```

A completed Job and plausible files show that a backup ran and wrote output.
They do not prove that the data can be restored. Periodically test restoring
database dumps and file snapshots to a separate location before relying on
them for recovery.
