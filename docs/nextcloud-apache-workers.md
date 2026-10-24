# Nextcloud Apache worker limit

The Nextcloud pod uses Apache's prefork MPM. The `AH00161` warning means all
configured Apache child processes were busy, so new requests were queued. The
Nextcloud Deployment has a 4 GiB memory limit; this raises the worker cap from
the common prefork default of 150 to 200. Watch pod memory after applying it:
each prefork worker is a separate process, so a higher cap can use more RAM.

Apply the Nextcloud Kustomize directory from the repository checkout that has
the local `secret.yaml`:

```sh
kubectl apply -k roles/master/apps/nas/nextcloud
kubectl -n nextcloud rollout status deployment/nextcloud
kubectl -n nextcloud exec deployment/nextcloud -- apachectl -t
kubectl -n nextcloud exec deployment/nextcloud -- apachectl -t -D DUMP_RUN_CFG
kubectl -n nextcloud top pod
kubectl -n nextcloud logs deployment/nextcloud --since=30m | grep AH00161
```

The active Apache config should report `MaxRequestWorkers: 200`. No matching
`AH00161` entries after a period of normal use means the cap is no longer being
hit. If memory is near the 4 GiB limit or the warning returns, check traffic
and slow PHP/database requests before raising the limit again.
