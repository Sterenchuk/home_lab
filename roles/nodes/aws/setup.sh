sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --auth-key=PASTE_KEY_HERE --ssh --hostname=aws-file-node
tailscale ip -4

sudo tailscale up --reset --ssh --hostname=aws-file-node