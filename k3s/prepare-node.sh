#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Must run as root" >&2
  exit 1
fi

echo "=== Checking zram kernel module ==="
if ! modinfo zram >/dev/null 2>&1; then
  echo "zram module not found — installing linux-image-amd64 and rebooting"
  apt-get update -qq
  apt-get install -y -q linux-image-amd64
  echo "Rebooting in 10 seconds..."
  sleep 10
  reboot
  exit 0
fi

echo "=== Installing systemd-zram-generator ==="
apt-get update -qq
apt-get install -y -q systemd-zram-generator

echo "=== Writing zram config ==="
cat > /etc/systemd/zram-generator.conf <<'ZRAM_EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
ZRAM_EOF

echo "=== Creating swap file ==="
if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
fi

if ! grep -q '^/swapfile' /etc/fstab; then
  echo '/swapfile none swap pri=10 0 0' >> /etc/fstab
fi

echo "=== Writing sysctl config ==="
cat > /etc/sysctl.d/90-zram.conf <<'SYSCTL_EOF'
vm.swappiness = 180
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
SYSCTL_EOF

echo "=== Applying changes ==="
systemctl daemon-reload
systemctl start systemd-zram-setup@zram0 2>/dev/null || true
swapon -a 2>/dev/null || true
sysctl --system >/dev/null 2>&1

echo "=== Done ==="
swapon --show
zramctl 2>/dev/null || true
sysctl vm.swappiness