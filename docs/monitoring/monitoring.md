# Cluster monitoring <pre docs>

This installs Prometheus, Grafana, and Alertmanager through Flux. Uptime Kuma
continues to check services from the outside (HTTP availability, for example).
Prometheus collects metrics from inside the cluster, such as pod CPU and memory,
and Alertmanager routes metric-based alerts to Telegram. They cover different
views of the system, so the small resource use of this stack adds detail that
Kuma does not provide.

## Before Flux installs it

Create the required secrets in the right namespaces. Keep the Telegram bot
separate from the reminder bot. Supply the chat ID as a Flux substitution in
`flux-system`; store the bot token and Grafana login as Kubernetes Secrets in
`monitoring`. Use SOPS-encrypted Secret manifests if you want these credentials
to be reconciled from Git.

Required keys:

- `flux-system/monitoring-notification-config`: `TELEGRAM_CHAT_ID`
- `monitoring/alertmanager-telegram`: `token`
- `monitoring/grafana-admin`: `admin-user` and `admin-password`

For a quick one-time setup, create a local token file and create the Secrets
with `kubectl` (do not commit the plaintext token file):

```sh
kubectl -n flux-system create secret generic monitoring-notification-config \
  --from-literal=TELEGRAM_CHAT_ID='<your-chat-id>'
kubectl -n monitoring create secret generic alertmanager-telegram \
  --from-file=token='<path-to-telegram-token-file>'
kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password='<choose-a-password>'
```

Create the `monitoring` namespace before creating its Secrets, or create the
Grafana and Telegram Secrets after the namespace appears and before the first
HelmRelease install completes. The chat ID is substituted into the Alertmanager
configuration by the monitoring Flux Kustomization.

## What each file does

### `clusters/homelab/flux-system/`

- `kustomization.yaml` includes both new Flux Kustomization objects in the
  cluster's root reconciliation.
- `monitoring.yaml` points Flux at the monitoring stack manifests and waits for
  them to become ready.
- `monitoring-demo.yaml` points Flux at the demo app and depends on `monitoring`.
  This ordering matters because the stack installs the ServiceMonitor and
  PrometheusRule CRDs that the demo manifests use.

### `roles/master/apps/monitoring/`

- `kustomization.yaml` groups the namespace, chart source, and release.
- `namespace.yaml` creates the shared `monitoring` namespace.
- `helmrepository.yaml` tells Flux where to fetch Prometheus Community charts.
- `helmrelease.yaml` installs pinned chart version `92.8.0` and configures the
  stack. Prometheus is pinned to `l590`, keeps three days of data, requests a
  5 GiB `local-path` volume, and has bounded memory. The selector settings let
  it discover ServiceMonitors, PodMonitors, and PrometheusRules without release
  labels. The four disabled control plane components commonly cannot be scraped
  through k3s, avoiding targets that would stay down. Grafana and Alertmanager
  read credentials from the named Secrets. Telegram uses a separate bot.

The existing Uptime Kuma manifests also use the `monitoring` namespace. This
stack reuses that namespace. If Kuma is reconciled by a separate controller,
keep one controller responsible for the Namespace object to avoid ownership
conflicts; the services themselves can share the namespace.

### `roles/master/apps/monitoring-demo/`

- `kustomization.yaml` groups the app and its monitoring resources.
- `namespace.yaml` keeps this test app and its alerting objects separate from
  the reminder bot.
- `app.yaml` contains a tiny Python HTTP server, its Deployment, and a labeled
  Service. `/metrics` exposes `demo_errors_total`; `POST /cause-error`
  increments it. The named Service port `http` is what the ServiceMonitor
  selects. The ConfigMap-mounted script keeps this demo self-contained without
  building or publishing a custom image.
- `servicemonitor.yaml` scrapes the Service's `/metrics` endpoint every 30
  seconds.
- `prometheusrule.yaml` fires after the counter increases within five minutes
  and remains true for one minute. `increase()` detects new errors rather than
  firing forever just because the counter is nonzero.

## Verify and exercise it

After the secrets exist and Flux has reconciled:

```sh
flux get helmreleases -A
kubectl -n monitoring get pods
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Open `http://localhost:3000` and use the Grafana credentials in
`grafana-admin`. In the shipped Kubernetes / Compute Resources / Pod dashboard,
choose namespace `reminder` for the original pod resource view.

Check the demo target and deliberately fire the alert:

```sh
kubectl -n monitoring-demo port-forward svc/monitoring-demo 8000:8000
curl localhost:8000/metrics
curl -X POST localhost:8000/cause-error
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
```

In Prometheus at `http://localhost:9090`, check Status / Targets for
`monitoring-demo` to be `UP`, and query `demo_errors_total`. Alertmanager is at
`http://localhost:9093`. After the 30-second scrape and one-minute alert hold,
the Telegram bot should send `MonitoringDemoErrorsRising` to the configured
chat. The demo counter resets when its pod restarts.
