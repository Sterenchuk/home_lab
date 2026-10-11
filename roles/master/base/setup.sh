#!/usr/bin/env bash
set -euo pipefail

echo "== hostname =="
sudo hostnamectl set-hostname masterserver

echo "== ignore lid close =="
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/99-lid.conf >/dev/null <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

echo "== disable sleep =="
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

sudo systemctl restart systemd-logind
echo "master-laptop setup done"
