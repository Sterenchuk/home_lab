#!/usr/bin/env python3
"""
k3s setup helper. Run it ON THE MASTER (L590).

    python3 k3s_setup.py up       # install server here, join agents, label nodes
    python3 k3s_setup.py status   # kubectl get nodes -o wide
    python3 k3s_setup.py reset    # uninstall k3s from agents and master

Uses only the standard library. Needs: SSH key login from master to each node,
and sudo on every machine (it will ask for the password via the terminal).
"""
import subprocess
import sys

# ---------------------------------------------------------------- config ----
# Phase now: plain LAN IPs. Give these machines a DHCP reservation in your
# router, otherwise k3s breaks when an IP changes.
# Later, for Tailscale: put the 100.x addresses below and set FLANNEL_IFACE.
MASTER_IP = "100.99.69.105"          # <-- change
MASTER_NAME = "l590"
MASTER_LABELS = {"role": "control"}

FLANNEL_IFACE = None                # later: "tailscale0"
K3S_VERSION = None                  # e.g. "v1.31.4+k3s1" to pin; None = latest stable

NODES = {
    # name: ssh user, ip, labels
    "zotac": {"user": "oleksandr", "ip": "192.168.0.11", "labels": {"role": "db"}},
    "mac":   {"user": "oleksandr", "ip": "192.168.0.12", "labels": {"role": "storage"}},
    # "hp":  {"user": "oleksandr", "ip": "192.168.0.13", "labels": {"role": "lab"}},
}
# ----------------------------------------------------------------------------

INSTALL = "curl -sfL https://get.k3s.io"
KUBECTL = "sudo k3s kubectl"


def run(cmd, check=True, capture=False):
    print(f"\n$ {cmd}")
    return subprocess.run(
        cmd, shell=True, check=check, text=True,
        capture_output=capture,
    )


def ssh(node, remote_cmd, check=True, capture=False):
    target = f"{node['user']}@{node['ip']}"
    # -t gives sudo a terminal so it can ask for the password
    return run(f"ssh -t {target} '{remote_cmd}'", check=check, capture=capture)


def version_env():
    return f"INSTALL_K3S_VERSION={K3S_VERSION} " if K3S_VERSION else ""


def iface_flag():
    return f" --flannel-iface {FLANNEL_IFACE}" if FLANNEL_IFACE else ""


def install_server():
    if run("command -v k3s", check=False, capture=True).returncode == 0:
        print("k3s already installed on master, skipping.")
        return
    args = (
        f"server --node-name {MASTER_NAME} --node-ip {MASTER_IP} "
        f"--advertise-address {MASTER_IP} --tls-san {MASTER_IP}{iface_flag()}"
    )
    run(f"{INSTALL} | sudo env {version_env()}sh -s - {args}")


def get_token():
    out = run("sudo cat /var/lib/rancher/k3s/server/node-token", capture=True)
    return out.stdout.strip()


def join_agent(name, node, token):
    check = ssh(node, "command -v k3s-agent-uninstall.sh", check=False, capture=True)
    if check.returncode == 0:
        print(f"{name}: agent already installed, skipping.")
        return
    args = f"agent --node-name {name} --node-ip {node['ip']}{iface_flag()}"
    env = f"K3S_URL=https://{MASTER_IP}:6443 K3S_TOKEN={token} {version_env()}"
    ssh(node, f"{INSTALL} | sudo env {env}sh -s - {args}")


def label(name, labels):
    for key, value in labels.items():
        run(f"{KUBECTL} label node {name} {key}={value} --overwrite")


def up():
    install_server()
    token = get_token()
    for name, node in NODES.items():
        join_agent(name, node, token)
    label(MASTER_NAME, MASTER_LABELS)
    for name, node in NODES.items():
        label(name, node["labels"])
    status()


def status():
    run(f"{KUBECTL} get nodes -o wide")


def reset():
    answer = input("This uninstalls k3s from ALL nodes and the master. Type 'yes': ")
    if answer.strip() != "yes":
        print("Aborted.")
        return
    for name, node in NODES.items():
        ssh(node, "sudo /usr/local/bin/k3s-agent-uninstall.sh", check=False)
    run("sudo /usr/local/bin/k3s-uninstall.sh", check=False)


COMMANDS = {"up": up, "status": status, "reset": reset}

if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in COMMANDS:
        sys.exit(f"usage: {sys.argv[0]} [{'|'.join(COMMANDS)}]")
    COMMANDS[sys.argv[1]]()