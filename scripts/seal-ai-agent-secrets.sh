#!/usr/bin/env bash
# Generates SealedSecret for k8s-ai-agent (Discord webhook).
#
# Usage:
#   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/... \
#   ./scripts/seal-ai-agent-secrets.sh

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-./kubeconfig.yaml}"
NAMESPACE="ai-agent"
OUT_DIR="gitops/sealed-secrets/ai-agent"
CERT="/tmp/sealed-secrets-cert.pem"

: "${DISCORD_WEBHOOK_URL:?Set DISCORD_WEBHOOK_URL}"

command -v kubeseal >/dev/null 2>&1 || { echo "kubeseal not found. Install: brew install kubeseal"; exit 1; }

mkdir -p "$OUT_DIR"

echo "Fetching sealed-secrets public cert..."
kubeseal --fetch-cert \
  --kubeconfig "$KUBECONFIG_PATH" \
  --controller-namespace kube-system \
  --controller-name sealed-secrets \
  > "$CERT"

echo "Sealing k8s-ai-agent-secrets..."

kubectl create secret generic k8s-ai-agent-secrets \
  --from-literal=discord-webhook-url="$DISCORD_WEBHOOK_URL" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | \
  kubeseal --cert "$CERT" --format yaml \
  > "$OUT_DIR/k8s-ai-agent-secrets.yaml"

echo ""
echo "Done → $OUT_DIR/"
echo "Next: git add $OUT_DIR && git commit && git push"
