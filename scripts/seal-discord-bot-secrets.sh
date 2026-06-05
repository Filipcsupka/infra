#!/usr/bin/env bash
# Generates SealedSecret for discord-bot (bot token).
#
# Usage:
#   DISCORD_BOT_TOKEN=your-token-here \
#   ./scripts/seal-discord-bot-secrets.sh

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-./kubeconfig.yaml}"
NAMESPACE="ai-agent"
OUT_FILE="gitops/sealed-secrets/ai-agent/discord-bot-secrets.yaml"
CERT="/tmp/sealed-secrets-cert.pem"

: "${DISCORD_BOT_TOKEN:?Set DISCORD_BOT_TOKEN}"

command -v kubeseal >/dev/null 2>&1 || { echo "kubeseal not found. Install: brew install kubeseal"; exit 1; }

echo "Fetching sealed-secrets public cert..."
kubeseal --fetch-cert \
  --kubeconfig "$KUBECONFIG_PATH" \
  --controller-namespace kube-system \
  --controller-name sealed-secrets \
  > "$CERT"

echo "Sealing discord-bot-secrets..."

kubectl create secret generic discord-bot-secrets \
  --from-literal=bot-token="$DISCORD_BOT_TOKEN" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | \
  kubeseal --cert "$CERT" --format yaml \
  > "$OUT_FILE"

echo ""
echo "Done → $OUT_FILE"
echo "Next: git add $OUT_FILE && git commit && git push"
