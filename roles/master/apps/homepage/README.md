# Homepage monitoring

The Lab group links to Grafana's dashboard browser at
`https://grafana.sansesdevelopment.uk/dashboards`. Sign in using the existing
`monitoring/grafana-admin` credentials, then choose a Node Exporter / Nodes or
Kubernetes / Compute Resources dashboard to view graphs.

The Servers group uses Homepage's built-in Custom API dynamic lists and the
existing Prometheus service. It follows the dark/slate theme, refreshes every
30 seconds, and lists monitored Kubernetes nodes automatically:

- CPU: percentage busy, averaged across cores over five minutes.
- RAM: percentage used, calculated from total minus available memory.
- Temperature: hottest hwmon sensor in degrees Celsius, falling back to the
  hottest thermal-zone sensor when hwmon is unavailable. This can be a CPU,
  motherboard, or disk sensor; it is not specifically RAM temperature. Nodes
  without supported hardware sensors are omitted. If none expose sensors,
  Homepage displays "No items found".
- Storage: bytes available to ordinary users per node and mounted filesystem.
  Temporary filesystems and Kubernetes container mounts are excluded. Separate
  disks stay separate instead of showing a misleading combined free-space total.

The existing CPU/RAM header widgets remain available. The new cards measure the
host through node-exporter, so their memory accounting can differ from the
Kubernetes metrics API used by the header. Offline exporters eventually disappear
from these lists; absence does not mean zero usage. Servers outside the monitored
cluster are not included.

## Enable

1. Reconcile the monitoring HelmRelease with the changes in
   `../monitoring/helmrelease.yaml`. This adds the Grafana Traefik ingress and a
   `node` label to node-exporter metrics. Wait for new scrapes; CPU needs at least
   two samples and settles over five minutes.
2. In the existing Cloudflare tunnel's public hostnames, add
   `grafana.sansesdevelopment.uk`, service type **HTTP**, destination
   `traefik.kube-system.svc.cluster.local:80`. This follows the existing Homepage
   routing. Grafana keeps its existing login; no anonymous access is enabled.
3. Deploy Homepage through its existing deployment process, or run from the repo
   root: `kubectl apply -k roles/master/apps/homepage`. Its generated ConfigMap
   name changes, which rolls out the Deployment with the updated configuration.

The widgets call Prometheus inside the cluster through Homepage's server-side
proxy. They do not need the Grafana hostname, a Grafana API token, or a public
Prometheus endpoint. The monitoring stack must already be running with its
required secrets (see `docs/monitoring.md` at the repo root).

## Verify

Open Homepage and check the Servers cards against Grafana. If all lists are
empty, check Prometheus targets and query `up{job="node-exporter"}`; its results
should include a non-empty `node` label. If only temperature is empty, query
`node_hwmon_temp_celsius` and `node_thermal_zone_temp` to check sensor availability.
The readable PromQL for each card is beside its URL in `config/services.yaml`.

References: [Homepage Custom API](https://gethomepage.dev/widgets/services/customapi/)
and [monitoring chart values](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml).
