#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

NODES_CONF="$SCRIPT_DIR/nodes.conf"
FIRST_SERVER=$(awk '$2 == "server" {print $1; exit}' "$NODES_CONF")
if [ -z "$FIRST_SERVER" ]; then
  echo "ERROR: no server in $NODES_CONF" >&2
  exit 1
fi

FIRST_SERVER_IP=$(tofu -chdir="$SCRIPT_DIR/../tofu" output -json vm_ips | python3 -c "import sys,json; print(json.load(sys.stdin)['$FIRST_SERVER'])")

echo "Fetching kubeconfig from $FIRST_SERVER ($FIRST_SERVER_IP)..."
KUBECONFIG_RAW=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/homelab debian@"${FIRST_SERVER_IP}" "sudo cat /etc/rancher/k3s/k3s.yaml")

KUBE_DIR="$HOME/.kube"
mkdir -p "$KUBE_DIR"
FINAL_FILE="$KUBE_DIR/config"

NEW_FILE="$KUBE_DIR/config.new"
printf '%s\n' "$KUBECONFIG_RAW" \
  | sed "s|https://127.0.0.1:6443|https://${FIRST_SERVER_IP}:6443|g" \
  | sed 's/name: default/name: homelab/g' \
  | sed 's/cluster: default/cluster: homelab/g' \
  | sed 's/user: default/user: homelab/g' \
  | sed 's/current-context: default/current-context: homelab/g' \
  > "$NEW_FILE"

chmod 600 "$NEW_FILE"

if [ -f "$FINAL_FILE" ]; then
  KUBECONFIG="$FINAL_FILE:$NEW_FILE" kubectl config view --flatten > "$FINAL_FILE.tmp"
  mv "$FINAL_FILE.tmp" "$FINAL_FILE"
  rm -f "$NEW_FILE"
else
  mv "$NEW_FILE" "$FINAL_FILE"
fi

chmod 600 "$FINAL_FILE"

echo "Kubeconfig written to $FINAL_FILE (not printed)"
kubectl config current-context

unset KUBECONFIG_RAW