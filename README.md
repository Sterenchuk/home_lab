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
- **Networking and access:** Tailscale connects the nodes; Cloudflare Tunnel
  provides external access to selected services.
- **GitOps:** Flux reconciles cluster configuration from this repository.
- **Applications (“pods”):** app manifests live under
  [`roles/master/apps/`](roles/master/apps/). This includes services such as
  Immich, Nextcloud, Homepage, and the reminder app, plus the monitoring
  stack. The directory name is historical: it contains Kubernetes resources
  such as Deployments, Services, and PersistentVolumeClaims, which create and
  manage pods.
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
roles/master/apps/              Kubernetes manifests for applications
roles/master/ingress/           Cluster ingress resources
roles/nodes/                    Setup for individual machine roles
scripts/common/                 Shared machine setup scripts
roles/master/corn-jobs/backups/ Kubernetes CronJobs for database and file backups
```

Machine setup scripts are still being organized. The shared baseline is
[`scripts/common/setup.sh`](scripts/common/setup.sh), and per-node scripts are
under [`roles/nodes/`](roles/nodes/) and [`roles/master/`](roles/master/).
Before running setup on a new machine, add your SSH public key to its
`~/.ssh/authorized_keys`. The current bootstrap helper expects a different
directory layout than this repo, so it needs updating before it can be used as
a single entry point.
