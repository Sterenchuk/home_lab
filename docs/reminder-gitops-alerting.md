# Reminder GitOps and alerts

Flux watches the `sanses500/reminder-bot` image. Successful pushes to `main`
publish `latest` and `build-<run number>-sha-<full commit SHA>` tags. Flux picks
the highest run number, updates the image in the reminder deployment, commits
that change to `home_lab`'s `main` branch, and then reconciles the deployment.

## One time credentials

The `flux-system` Git credential in the `flux-system` namespace must be a
read/write GitHub deploy key for `Sterenchuk/home_lab`. Flux needs write access
to push image updates; its existing credential may be read-only. Keep the
existing Secret name (`flux-system`) and ensure it contains the SSH identity
and known hosts data required by the `GitRepository`.

Create the Telegram bot and add it to the chat that should receive Flux alerts.
Find the chat ID, then create these Secrets in `flux-system`:

```sh
kubectl -n flux-system create secret generic flux-telegram \
  --from-literal=token='BOT_TOKEN'
kubectl -n flux-system create secret generic flux-notification-config \
  --from-literal=TELEGRAM_CHAT_ID='CHAT_ID'
```

The second Secret is read by Flux Kustomize post-build substitution to fill in
the Telegram Provider channel. Keep both Secrets out of Git.

## Reminder bot CI

The reminder-bot GitHub Actions workflow needs the existing Docker Hub username
variable and token secret. It publishes `latest` and the run-number/SHA tag only
after the test job succeeds on `main`. `ImageRepository` in Flux reads the
public Docker Hub repository `sanses500/reminder-bot`. The deployment starts
from `latest`; Flux image automation replaces it with the highest matching
`build-<run>-sha-<full commit SHA>` tag once it discovers one.

If the pod reports `ImagePullBackOff`, inspect the image policy and repository:

```sh
kubectl -n flux-system get imagerepository,imagepolicy
kubectl -n flux-system describe imagepolicy reminder-bot
```

Check the reminder-bot repository's Actions page for a successful `main`
workflow run and confirm that the matching `build-<run>-sha-<40-character SHA>`
tag exists in Docker Hub. If the image policy has no latest image, the workflow
has not published a matching tag yet. After a successful publish, Flux should
update the deployment image within its one-minute scan/automation intervals.

## Uptime Kuma check

In Uptime Kuma, add an HTTP(s) monitor with:

- URL: `http://reminder.reminder.svc.cluster.local:8000/health`
- Expected status: `200`
- Heartbeat interval: `60` seconds
- Retries: `3`

This internal service address resolves from the `monitoring` namespace. Assign
the monitor to the notification channel you use in Kuma and save it.

## Verify the alerts

After Flux has reconciled these files and the Secrets exist, check that the
`reminder` Flux Kustomization is Ready and that Uptime Kuma shows the endpoint
as up. To verify notifications, temporarily set the reminder deployment image
to an invalid tag in Git and push the change. The `flux-failures` Alert should
send Flux's reconciliation error to Telegram, while Kuma should mark `/health`
down. Restore the valid image and confirm the pod recovers and both alerts
clear.

The reminder PVC is `ReadWriteOnce`, which permits mounting read/write from one
node at a time. The claim is dynamically provisioned and may be backed by
node-local storage, so its PV can have node affinity to the node where it was
created. Pinning the pod to `kubernetes.io/hostname: zotac` keeps it colocated
with that storage and prevents it from being scheduled onto a node that cannot
mount the volume.
