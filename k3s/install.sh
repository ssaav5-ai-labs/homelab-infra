#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE="${1:?Usage: $0 <node-name>}"

source "$SCRIPT_DIR/versions.env"

NODES_CONF="$SCRIPT_DIR/nodes.conf"
if [ ! -f "$NODES_CONF" ]; then
  echo "ERROR: $NODES_CONF not found" >&2
  exit 1
fi

ROLE=$(awk -v n="$NODE" '$1 == n {print $2}' "$NODES_CONF")
if [ -z "$ROLE" ]; then
  echo "ERROR: $NODE not found in $NODES_CONF" >&2
  exit 1
fi

NODE_IP=$(tofu -chdir="$SCRIPT_DIR/../tofu" output -json vm_ips | python3 -c "import sys,json; print(json.load(sys.stdin)['$NODE'])")
if [ -z "$NODE_IP" ]; then
  echo "ERROR: No IP for $NODE in tofu output" >&2
  exit 1
fi

FIRST_SERVER=$(awk '$2 == "server" {print $1; exit}' "$NODES_CONF")
FIRST_SERVER_IP=$(tofu -chdir="$SCRIPT_DIR/../tofu" output -json vm_ips | python3 -c "import sys,json; print(json.load(sys.stdin)['$FIRST_SERVER'])")

if [ -z "${K3S_TOKEN:-}" ]; then
  if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a
    source "$SCRIPT_DIR/../.env"
    set +a
  fi
fi

if [ -z "${K3S_TOKEN:-}" ]; then
  echo "ERROR: K3S_TOKEN not set" >&2
  exit 1
fi

export K3S_TOKEN
export NODE_IP

echo "=== Installing k3s on $NODE (role=$ROLE, ip=$NODE_IP) ==="

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

CONFIG_FILE="$TMPDIR/config.yaml"
KUBELET_DROPIN="$TMPDIR/99-kubelet-swap.conf"

cp "$SCRIPT_DIR/config/kubelet-swap.conf" "$KUBELET_DROPIN"

if [ "$ROLE" = "server" ]; then
  envsubst < "$SCRIPT_DIR/config/server.yaml.tmpl" > "$CONFIG_FILE"
  if [ "$NODE" = "$FIRST_SERVER" ]; then
    printf 'cluster-init: true\n' >> "$CONFIG_FILE"
  else
    printf 'server: https://%s:6443\n' "$FIRST_SERVER_IP" >> "$CONFIG_FILE"
  fi
  INSTALL_EXEC="server"
elif [ "$ROLE" = "agent" ]; then
  export FIRST_SERVER_IP
  envsubst < "$SCRIPT_DIR/config/agent.yaml.tmpl" > "$CONFIG_FILE"
  INSTALL_EXEC="agent"
else
  echo "ERROR: Unknown role '$ROLE'" >&2
  exit 1
fi

echo "=== Copying configs to $NODE ==="
scp -o StrictHostKeyChecking=no -i ~/.ssh/homelab "$CONFIG_FILE" "debian@${NODE_IP}:/tmp/config.yaml"
scp -o StrictHostKeyChecking=no -i ~/.ssh/homelab "$KUBELET_DROPIN" "debian@${NODE_IP}:/tmp/99-kubelet-swap.conf"

echo "=== Running k3s installer on $NODE ==="
ssh -o StrictHostKeyChecking=no -i ~/.ssh/homelab debian@"${NODE_IP}" \
  "sudo K3S_VERSION='$K3S_VERSION' INSTALL_EXEC='$INSTALL_EXEC' bash -s" <<'REMOTE_SCRIPT'
set -euo pipefail

echo "Copying config files..."
sudo mkdir -p /etc/rancher/k3s
sudo cp /tmp/config.yaml /etc/rancher/k3s/config.yaml
sudo chmod 600 /etc/rancher/k3s/config.yaml

sudo mkdir -p /var/lib/rancher/k3s/agent/etc/kubelet.conf.d
sudo cp /tmp/99-kubelet-swap.conf /var/lib/rancher/k3s/agent/etc/kubelet.conf.d/99-kubelet-swap.conf
sudo chmod 644 /var/lib/rancher/k3s/agent/etc/kubelet.conf.d/99-kubelet-swap.conf

echo "Running installer for ${K3S_VERSION}..."
curl -sfL "https://raw.githubusercontent.com/k3s-io/k3s/${K3S_VERSION}/install.sh" | \
  sudo INSTALL_K3S_VERSION="$K3S_VERSION" \
  INSTALL_K3S_EXEC="$INSTALL_EXEC" \
  sh -

echo "k3s service status:"
sudo k3s check-config 2>&1 | head -30
REMOTE_SCRIPT

echo "=== Done: $NODE installed as $ROLE ==="