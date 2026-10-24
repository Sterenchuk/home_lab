#master

V=$(curl -sIL -o /dev/null -w '%{url_effective}' https://github.com/k3s-io/k3s/releases/latest | sed 's|.\*/tag/||; s|%2B|+|')
echo $V

curl -sfL https://get.k3s.io | sudo env INSTALL_K3S_VERSION="$V" sh -s - server \
 --node-name l590 \
 --node-ip MASTER_TS_IP \
 --advertise-address MASTER_TS_IP \
 --tls-san MASTER_TS_IP \
 --tls-san l590 \
 --flannel-iface tailscale0

# agent

curl -sfL https://get.k3s.io | sudo env \
 INSTALL_K3S_VERSION="v1.xx.x+k3s1" \
 K3S_URL=https://MASTER_TS_IP:6443 \
 K3S_TOKEN=PASTE_TOKEN_HERE \
 sh -s - agent --node-name zotac --node-ip THIS_NODES_TS_IP --flannel-iface tailscale0

cloudflared tunnel run --token <token>
