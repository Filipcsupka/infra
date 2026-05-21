#!/usr/bin/env bash
# Run this AFTER sealed-secrets controller is running in the cluster.
# Generates SealedSecret manifests for all monitoring credentials.
# Edit the passwords below, then commit the output files.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-./kubeconfig.yaml}"
NAMESPACE="monitoring"
OUT_DIR="gitops/sealed-secrets"
CERT="/tmp/sealed-secrets-cert.pem"

# ── Credentials — change before running ──────────────────────────────────────
GRAFANA_USER="admin"
GRAFANA_PASSWORD="changeme-grafana"

MINIO_ROOT_USER="minioadmin"
MINIO_ROOT_PASSWORD="changeme-minio"

# ─────────────────────────────────────────────────────────────────────────────

command -v kubeseal >/dev/null 2>&1 || {
  echo "kubeseal not found. Install: brew install kubeseal"
  exit 1
}

mkdir -p "$OUT_DIR"

echo "Fetching sealed-secrets public cert..."
kubeseal --fetch-cert \
  --kubeconfig "$KUBECONFIG_PATH" \
  --controller-namespace kube-system \
  --controller-name sealed-secrets \
  > "$CERT"

echo "Sealing grafana-admin-secret..."
kubectl create secret generic grafana-admin-secret \
  --from-literal=admin-user="$GRAFANA_USER" \
  --from-literal=admin-password="$GRAFANA_PASSWORD" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | \
  kubeseal --cert "$CERT" --format yaml \
  > "$OUT_DIR/grafana-admin.yaml"

echo "Sealing minio-root-secret..."
kubectl create secret generic minio-root-secret \
  --from-literal=rootUser="$MINIO_ROOT_USER" \
  --from-literal=rootPassword="$MINIO_ROOT_PASSWORD" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | \
  kubeseal --cert "$CERT" --format yaml \
  > "$OUT_DIR/minio-root.yaml"

echo "Sealing loki-minio-secret..."
kubectl create secret generic loki-minio-secret \
  --from-literal=accessKeyId="$MINIO_ROOT_USER" \
  --from-literal=secretAccessKey="$MINIO_ROOT_PASSWORD" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | \
  kubeseal --cert "$CERT" --format yaml \
  > "$OUT_DIR/loki-minio.yaml"

cat > "$OUT_DIR/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - grafana-admin.yaml
  - minio-root.yaml
  - loki-minio.yaml
EOF

echo ""
echo "Done. Files written to $OUT_DIR/"
echo ""
echo "Next steps:"
echo "  1. Verify the output YAML files look correct"
echo "  2. Apply ArgoCD app:  kubectl --kubeconfig $KUBECONFIG_PATH apply -f argocd/apps/monitoring-secrets.yaml"
echo "  3. Update minio + loki + prometheus-stack helm values to use existingSecret"
echo "  4. git add $OUT_DIR argocd/apps/monitoring-secrets.yaml && git commit && git push"
