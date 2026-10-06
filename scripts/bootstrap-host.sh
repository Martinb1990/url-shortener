#!/usr/bin/env bash
# One-time host setup for gcp-devops01: swap + Docker.
# Idempotent - safe to re-run. Phase 3 replaces this with an Ansible playbook.
#   sudo ./scripts/bootstrap-host.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo $0" >&2
  exit 1
fi

TARGET_USER="${SUDO_USER:-$(logname)}"
SWAPFILE=/swapfile
SWAP_SIZE=4G

echo "==> Swap (${SWAP_SIZE})"
if ! swapon --show=NAME --noheadings | grep -qx "$SWAPFILE"; then
  [[ -f $SWAPFILE ]] || fallocate -l "$SWAP_SIZE" "$SWAPFILE"
  chmod 600 "$SWAPFILE"
  mkswap "$SWAPFILE" >/dev/null
  swapon "$SWAPFILE"
fi
grep -q "^$SWAPFILE " /etc/fstab || echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
# Prefer RAM; only swap under real pressure.
echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
sysctl -q -p /etc/sysctl.d/99-swappiness.conf

echo "==> Docker"
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y -q docker.io docker-compose-v2 docker-buildx make
systemctl enable --now docker

# Cap container log size so logs can't fill the disk.
if [[ ! -f /etc/docker/daemon.json ]]; then
  cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
  systemctl restart docker
fi

usermod -aG docker "$TARGET_USER"

echo
echo "Done. Log out and back in (or run 'newgrp docker') so '$TARGET_USER' can use docker without sudo."
free -h
docker --version
docker compose version
