#!/usr/bin/env bash
set -euo pipefail

echo "== update system =="
sudo apt update && sudo apt full-upgrade -y

echo "== ssh =="
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf >/dev/null <<'EOF'
PasswordAuthentication no
PermitRootLogin no
EOF
sudo systemctl restart ssh

echo "== firewall + fail2ban =="
sudo apt install -y ufw fail2ban
sudo ufw allow OpenSSH
sudo ufw --force enable
sudo systemctl enable --now fail2ban

echo "== tailscale =="
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
sudo systemctl enable --now tailscaled
if ! tailscale status >/dev/null 2>&1; then
  echo "Run 'sudo tailscale up' manually and log in."
fi

echo "== automatic updates =="
sudo apt install -y unattended-upgrades
echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null
sudo tee /etc/apt/apt.conf.d/52homelab-upgrades >/dev/null <<'EOF'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF

echo "common setup done"
