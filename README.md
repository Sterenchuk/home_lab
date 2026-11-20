# Home lab

This repository contains the configuration and notes for my home lab: a small
k3s cluster running on repurposed computers, with applications deployed and
managed through Kubernetes and Flux. I use it to learn DevOps by building and
operating a system, documenting the choices I make, and improving it as I go.

## About me

I am a junior DevOps learner. I know the foundations of Linux, Docker,
networking, and Kubernetes with k3s, and I am working to deepen that knowledge
through practice. I have used Docker before this lab. I also worked on two
projects, a secure voting system and an online shop. Those projects introduced
me to the development side, but I found myself especially interested in the
DevOps work: deploying applications, connecting services, and keeping them
running. This lab is where I am continuing to build those skills.

## What is in the lab

- **Cluster:** one k3s server and two agents on physical machines.
- **Networking and access:** Tailscale connects the nodes(will move all ips to LAN); Cloudflare Tunnel
  provides external access to selected services.
- **GitOps:** Flux reconciles cluster configuration from this repository.
- **Applications (“pods”):** app manifests live under `roles/master/`, split
  by category: [`files/`](roles/master/files/) (Immich, Nextcloud, ownCloud),
  [`db/`](roles/master/db/) (Postgres), [`monitoring/`](roles/master/monitoring/)
  (the monitoring stack and its config/demo), [`ai/`](roles/master/ai/)
  (Ollama + Open WebUI), [`backend/`](roles/master/backend/) (the shop app,
  placeholder), and [`apps/`](roles/master/apps/) as a catch-all for
  everything else (Homepage, code-server, Uptime Kuma, the reminder app,
  the system-upgrade controller). Each category directory contains the
  Kubernetes resources — Deployments, Services, PersistentVolumeClaims —
  that create and manage that app's pods.
- **Machine setup:** common setup scripts and per-machine-role scripts live in
  [`scripts/`](scripts/) and [`roles/`](roles/).

I plan to add a `pods/` documentation folder and write up each application
gradually. Each page will explain what the app does, how it is deployed, what
it depends on, how its data is stored and backed up, and how I troubleshoot it.
The existing manifests are the source of truth for what is configured; the
application docs will make that setup easier to understand.

## Documentation

- [Cluster architecture](docs/architecture/arch1-base.md)
- [Physical nodes and hardware](docs/nodes/NODES1-base.md)
- [Tailscale networking](docs/network/N1-tailscale.md)
- [Cloudflare Tunnel ingress](docs/ingress/IN1-cloudflare.md)
- [Cloudflare tunnel setup notes](docs/cloudflare_deploy.md)
- [Monitoring and alerting](docs/monitoring.md)
- [Backup CronJobs](docs/backup-cronjobs.md)
- [Reminder app GitOps and alerts](docs/reminder-gitops-alerting.md)
- [Nextcloud Apache worker tuning](docs/nextcloud-apache-workers.md)

## Learning plans

My next steps are to document the applications, clarify backup and recovery
procedures, and keep improving how the cluster is monitored and operated. I am
also learning how to make the setup more resilient; the current cluster has a
single control-plane node, so it is not highly available.

## Repository map

```text
clusters/homelab/               Flux cluster entry point and reconciliation
docs/                           Architecture, setup, and operations notes
roles/master/apps/              Misc app manifests (Homepage, code-server, Uptime Kuma, reminder, ...)
roles/master/files/             File-storage app manifests (Immich, Nextcloud, ownCloud)
roles/master/db/                Database manifests (Postgres)
roles/master/monitoring/        Monitoring stack, config, and demo app
roles/master/ai/                AI app manifests (Ollama, Open WebUI)
roles/master/backend/           Backend app manifests (shop, placeholder)
roles/master/ingress/           Cluster ingress resources
roles/nodes/                    Setup for individual machine roles
scripts/common/                 Shared machine setup scripts
roles/master/cron-jobs/backups/ Kubernetes CronJobs for database and file backups
```

Machine setup scripts are still being organized. The shared baseline is
[`scripts/common/setup.sh`](scripts/common/setup.sh), and per-node scripts are
under [`roles/nodes/`](roles/nodes/) and [`roles/master/`](roles/master/).
Before running setup on a new machine, add your SSH public key to its
`~/.ssh/authorized_keys`. The current bootstrap helper expects a different
directory layout than this repo, so it needs updating before it can be used as
a single entry point.
