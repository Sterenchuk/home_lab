#!/usr/bin/env bash
# Common baseline for every node. Safe to re-run.
# Optional env vars:
#   TAILSCALE_ONLY=1   do not allow SSH on public interfaces (run only after
#                      you confirmed SSH works over Tailscale)
#   AUTO_REBOOT=0      disable automatic reboots after updates
#   REBOOT_TIME=05:00  reboot time (set it AFTER your nightly backup window)
set -euo pipefail

TAILSCALE_ONLY="${TAILSCALE_ONLY:-0}"
AUTO_REBOOT="${AUTO_REBOOT:-1}"
REBOOT_TIME="${REBOOT_TIME:-05:00}"

echo "== update system =="
sudo apt update && sudo apt full-upgrade -y

echo "== ssh =="
sudo apt install -y openssh-server

# Lockout guard: never disable passwords if no key is installed.
target_user="${SUDO_USER:-$USER}"
home_dir="$(getent passwd "$target_user" | cut -d: -f6)"
if [ ! -s "$home_dir/.ssh/authorized_keys" ]; then
  echo "ERROR: $home_dir/.ssh/authorized_keys is empty or missing."
  echo "Add your public key first (ssh-copy-id), then re-run."
  exit 1
fi

# 00- prefix: sshd uses the FIRST value it sees, and files like
# 50-cloud-init.conf may set PasswordAuthentication yes.
sudo tee /etc/ssh/sshd_config.d/00-hardening.conf >/dev/null <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
sudo sshd -t
sudo systemctl enable --now ssh
sudo systemctl restart ssh
sudo sshd -T | grep -Ei '^(passwordauthentication|permitrootlogin) '

echo "== tailscale =="
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
sudo systemctl enable --now tailscaled
if ! tailscale status >/dev/null 2>&1; then
  echo "Run 'sudo tailscale up' manually and log in, then re-run this script."
fi

echo "== firewall + fail2ban =="
sudo apt install -y ufw fail2ban
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in on tailscale0
if [ "$TAILSCALE_ONLY" = "1" ]; then
  sudo ufw delete allow OpenSSH 2>/dev/null || true
else
  sudo ufw allow OpenSSH
fi
sudo ufw --force enable
sudo systemctl enable --now fail2ban
# NOTE for k3s nodes: ufw blocks forwarded pod traffic by default. The k3s
# role must add: ufw allow from 10.42.0.0/16, ufw allow from 10.43.0.0/16,
# and ufw default allow routed.

echo "== automatic updates =="
sudo apt install -y unattended-upgrades
sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
reboot_flag="false"; [ "$AUTO_REBOOT" = "1" ] && reboot_flag="true"
sudo tee /etc/apt/apt.conf.d/52homelab-upgrades >/dev/null <<EOF
Unattended-Upgrade::Automatic-Reboot "$reboot_flag";
Unattended-Upgrade::Automatic-Reboot-Time "$REBOOT_TIME";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF

echo "common setup done"