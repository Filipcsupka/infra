#!/usr/bin/env bash
# Generates SealedSecret for Langfuse (postgres + nextauth).
# Run once before first deploy, then commit the output.
#
# Usage:
#   ./scripts/seal-langfuse-secrets.sh
#
# To use custom passwords (instead of auto-generated):
#   POSTGRES_PASSWORD=mypass NEXTAUTH_SECRET=mysecret ./scripts/seal-langfuse-secrets.sh

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-./kubeconfig.yaml}"
NAMESPACE="langfuse"
OUT_DIR="gitops/sealed-secrets/langfuse"
CERT="/tmp/sealed-secrets-cert.pem"

POSTGRES_USER="langfuse"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(openssl rand -hex 20)}"
NEXTAUTH_SECRET="${NEXTAUTH_SECRET:-$(openssl rand -base64 32)}"
SALT="${SALT:-$(openssl rand -base64 32)}"
DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres.langfuse.svc.cluster.local:5432/langfuse"

command -v kubeseal >/dev/null 2>&1 || { echo "kubeseal not found. Install: brew install kubeseal"; exit 1; }

mkdir -p "$OUT_DIR"

echo "Fetching sealed-secrets public cert..."
kubeseal --fetch-cert \
  --kubeconfig "$KUBECONFIG_PATH" \
  --controller-namespace kube-system \
  --controller-name sealed-secrets \
  > "$CERT"

echo "Sealing langfuse-secrets..."
kubectl create secret generic langfuse-secrets \
  --from-literal=postgres-user="$POSTGRES_USER" \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=database-url="$DATABASE_URL" \
  --from-literal=nextauth-secret="$NEXTAUTH_SECRET" \
  --from-literal=salt="$SALT" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | \
  kubeseal --cert "$CERT" --format yaml \
  > "$OUT_DIR/langfuse-secrets.yaml"

cat > "$OUT_DIR/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - langfuse-secrets.yaml
EOF

echo ""
echo "Done → $OUT_DIR/"
echo ""
echo "SAVE THESE — cannot recover after this session:"
echo "  POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
echo "  NEXTAUTH_SECRET=$NEXTAUTH_SECRET"
echo "  SALT=$SALT"
echo ""
echo "Next: git add $OUT_DIR && git commit && git push"
echo "Then: kubectl apply -f argocd/apps/core/langfuse-secrets.yaml --kubeconfig $KUBECONFIG_PATH"
