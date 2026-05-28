#!/usr/bin/env bash
# Generates SealedSecret for k8s-ai-agent (Langfuse API keys + Slack webhook).
# Run AFTER Langfuse UI is up and you've created a project + API keys there.
#
# Usage:
#   LANGFUSE_PUBLIC_KEY=pk-lf-... \
#   LANGFUSE_SECRET_KEY=sk-lf-... \
#   SLACK_WEBHOOK_URL=https://hooks.slack.com/... \
#   ./scripts/seal-ai-agent-secrets.sh
#
# SLACK_WEBHOOK_URL is optional — agent works without Slack.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-./kubeconfig.yaml}"
NAMESPACE="ai-agent"
OUT_DIR="gitops/sealed-secrets/ai-agent"
CERT="/tmp/sealed-secrets-cert.pem"

: "${LANGFUSE_PUBLIC_KEY:?Set LANGFUSE_PUBLIC_KEY}"
: "${LANGFUSE_SECRET_KEY:?Set LANGFUSE_SECRET_KEY}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

command -v kubeseal >/dev/null 2>&1 || { echo "kubeseal not found. Install: brew install kubeseal"; exit 1; }

mkdir -p "$OUT_DIR"

echo "Fetching sealed-secrets public cert..."
kubeseal --fetch-cert \
  --kubeconfig "$KUBECONFIG_PATH" \
  --controller-namespace kube-system \
  --controller-name sealed-secrets \
  > "$CERT"

echo "Sealing k8s-ai-agent-secrets..."

EXTRA_ARGS=()
if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
  EXTRA_ARGS+=(--from-literal=slack-webhook-url="$SLACK_WEBHOOK_URL")
fi

kubectl create secret generic k8s-ai-agent-secrets \
  --from-literal=langfuse-public-key="$LANGFUSE_PUBLIC_KEY" \
  --from-literal=langfuse-secret-key="$LANGFUSE_SECRET_KEY" \
  "${EXTRA_ARGS[@]}" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | \
  kubeseal --cert "$CERT" --format yaml \
  > "$OUT_DIR/k8s-ai-agent-secrets.yaml"

cat > "$OUT_DIR/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - k8s-ai-agent-secrets.yaml
EOF

echo ""
echo "Done → $OUT_DIR/"
echo "Next: git add $OUT_DIR && git commit && git push"
echo "ArgoCD will sync automatically."
