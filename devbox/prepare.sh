#!/usr/bin/env bash
# Prepare the devbox VM (playbook 02c step 2): Docker CE from Docker's apt
# repository (pinned), git, tmux, rsync, and the folders the devbox dev
# containers mount. Run as root:
#   ssh -i ~/.ssh/homelab debian@192.168.86.214 'sudo bash -s' < devbox/prepare.sh
set -euo pipefail

# Pinned from https://download.docker.com/linux/debian/dists/trixie/stable/ (2026-11-18).
DOCKER_VERSION="5:29.10.0-1~debian.13~trixie"
CONTAINERD_VERSION="2.4.2-4~debian.13~trixie"
BUILDX_VERSION="0.39.0-1~debian.13~trixie"
DEV_USER="debian"

if [ "$(id -u)" -ne 0 ]; then
  echo "Must run as root" >&2
  exit 1
fi

# shellcheck source=/dev/null
. /etc/os-release
if [ "${VERSION_CODENAME:-}" != "trixie" ]; then
  echo "Expected Debian 13 (trixie), found ${VERSION_CODENAME:-unknown}" >&2
  exit 1
fi

echo "=== Base packages ==="
apt-get update -qq
apt-get install -y -q ca-certificates curl git tmux rsync

echo "=== Docker apt repository ==="
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<DOCKER_EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
DOCKER_EOF
apt-get update -qq

echo "=== Docker CE (pinned) ==="
apt-get install -y -q --allow-downgrades \
  "docker-ce=${DOCKER_VERSION}" \
  "docker-ce-cli=${DOCKER_VERSION}" \
  "containerd.io=${CONTAINERD_VERSION}" \
  "docker-buildx-plugin=${BUILDX_VERSION}"
apt-mark hold docker-ce docker-ce-cli containerd.io docker-buildx-plugin
systemctl enable --now docker
usermod -aG docker "${DEV_USER}"

echo "=== Folders the dev containers mount ==="
home="/home/${DEV_USER}"
for d in .devbox .devbox/ssh .kube .sops-age; do
  install -d -m 700 -o "${DEV_USER}" -g "${DEV_USER}" "${home}/${d}"
done
install -d -m 755 -o "${DEV_USER}" -g "${DEV_USER}" \
  "${home}/code" "${home}/code/github.com" "${home}/code/github.com/ssaav5-ai-labs"

echo "=== Done (reconnect so the docker group applies) ==="
docker --version
tmux -V
