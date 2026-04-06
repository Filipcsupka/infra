#!/bin/bash
set -euo pipefail

# ── System prep ──────────────────────────────────────────────────────────────
apt-get update -qq
apt-get install -y -qq curl open-iscsi

# ── Install k3s as control plane ─────────────────────────────────────────────
# k3s is CNCF-certified Kubernetes — runs the same API as upstream k8s.
# Traefik is disabled in favour of deploying an ingress controller via ArgoCD.
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable=traefik \
  --disable=servicelb \
  --node-ip=${control_plane_private_ip} \
  --advertise-address=${control_plane_private_ip} \
  --flannel-iface=eth1 \
  --tls-san=${control_plane_private_ip}" \
  K3S_TOKEN="${k3s_token}" sh -

# ── Wait for node to be Ready ─────────────────────────────────────────────────
until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
  echo "Waiting for control plane to become Ready..."
  sleep 10
done

echo "Control plane is Ready."
