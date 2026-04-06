#!/bin/bash
set -euo pipefail

# ── System prep ──────────────────────────────────────────────────────────────
apt-get update -qq
apt-get install -y -qq curl open-iscsi

# ── Wait for control plane API to be reachable ────────────────────────────────
until curl -sk https://${control_plane_private_ip}:6443/healthz | grep -q "ok"; do
  echo "Waiting for API server at ${control_plane_private_ip}:6443..."
  sleep 10
done

# ── Join cluster as worker ────────────────────────────────────────────────────
curl -sfL https://get.k3s.io | \
  K3S_URL="https://${control_plane_private_ip}:6443" \
  K3S_TOKEN="${k3s_token}" \
  INSTALL_K3S_EXEC="agent --node-ip=$(hostname -I | awk '{print $1}') --flannel-iface=eth1" \
  sh -

echo "Worker joined the cluster."
