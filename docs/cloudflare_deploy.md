1. Create the tunnel (in the browser)
   Cloudflare dashboard → Zero Trust → Networks → Tunnels → Create a tunnel → type Cloudflared.
   Name it, for example homelab.
   On the next screen it shows install commands. Don’t run them. Just copy the long token from the command (the string after --token).
   Go to the Public Hostname tab and add:
   Hostname: home.yourdomain
   Service type: HTTP
   URL: traefik.kube-system.svc.cluster.local:80
   That is Traefik’s service name inside k3s. Cloudflare will create the DNS record for you.
2. Deploy cloudflared (on the master)
   bash
   sudo k3s kubectl create namespace cloudflared
   sudo k3s kubectl -n cloudflared create secret generic tunnel-token \
    --from-literal=token=PASTE_TOKEN_HERE
