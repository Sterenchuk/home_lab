# homelab
Setup scripts. common/ is for every machine, roles/<name>/ is for one kind of machine.
Before first run on a new machine: add your SSH public key to ~/.ssh/authorized_keys.
Usage: ./bootstrap.sh master-laptop
Manual after running: `sudo tailscale up`.
