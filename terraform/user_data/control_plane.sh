#!/bin/bash
set -euo pipefail

apt-get update -qq
apt-get install -y -qq curl

PUBLIC_IP=$(curl -s https://api.ipify.org)

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable=traefik \
  --disable=servicelb \
  --tls-san=$PUBLIC_IP" \
  sh -

until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
  sleep 10
done

echo "k3s ready"
