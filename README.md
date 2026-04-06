# infra

Personal infrastructure repository — IaC, GitOps, and ArgoCD configuration for a home/lab Kubernetes cluster running on Hetzner Cloud.

## Repository structure

```
infra/
├── terraform/          # Hetzner Cloud — provision k3s cluster (1 control plane + 1 worker)
├── argocd/
│   ├── install/        # ArgoCD server deployment (kustomization + config patches)
│   ├── projects/       # AppProject definitions
│   └── apps/           # ArgoCD Application CRDs (one per app)
└── gitops/
    └── apps/
        ├── my-cv/      # Personal CV webapp
        └── vevsdesign/ # VevsDesign webapp (image/domain TBD)
```

Each app follows the standard Kustomize layout: `base/` contains the canonical manifests, `overlays/dev` and `overlays/prod` override environment-specific values.

---

## Setup checklist

### 1 — Terraform: provision the cluster

- [ ] Copy `terraform/terraform.tfvars.example` → `terraform/terraform.tfvars`
- [ ] Fill in `hcloud_token` (Hetzner Cloud API token — generate in the Hetzner console under Security → API Tokens)
- [ ] Fill in `ssh_key_name` (name of an SSH key already uploaded to Hetzner)
- [ ] Confirm `ssh_private_key_path` points to the matching local private key
- [ ] Review `location` and `server_type` (defaults: `nbg1`, `cx22`)
- [ ] Run `terraform init && terraform apply` inside `terraform/`
- [ ] `kubeconfig.yaml` will be written to the repo root — **do not commit it** (it is in `.gitignore`)
- [ ] Verify cluster: `KUBECONFIG=kubeconfig.yaml kubectl get nodes`

### 2 — ArgoCD: install on the cluster

- [ ] Create the `argocd` namespace: `kubectl create namespace argocd`
- [ ] Apply the install kustomization:
  ```bash
  kubectl apply -k argocd/install/
  ```
- [ ] Wait for all ArgoCD pods to be `Running`:
  ```bash
  kubectl -n argocd get pods -w
  ```
- [ ] Retrieve the initial admin password:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d
  ```
- [ ] Update `argocd/install/patches/argocd-cm.yaml` — replace `argocd.example.com` with the actual control plane IP or domain
- [ ] Access the UI at `http://<control-plane-ip>:30080`
- [ ] Log in and change the admin password immediately

### 3 — ArgoCD: register this repository

> Only needed if the repo is private.

- [ ] Create a repository secret in the `argocd` namespace:
  ```bash
  kubectl -n argocd create secret generic infra-repo \
    --from-literal=type=git \
    --from-literal=url=https://github.com/Filipcsupka/infra \
    --from-literal=username=Filipcsupka \
    --from-literal=password=<github-pat>
  kubectl -n argocd label secret infra-repo argocd.argoproj.io/secret-type=repository
  ```

### 4 — ArgoCD: deploy applications

- [ ] Apply the AppProject:
  ```bash
  kubectl apply -f argocd/projects/default.yaml
  ```
- [ ] Apply Application CRDs:
  ```bash
  kubectl apply -f argocd/apps/my-cv.yaml
  kubectl apply -f argocd/apps/vevsdesign.yaml
  ```
- [ ] Verify both apps sync successfully in the ArgoCD UI

### 5 — Cloudflare Tunnel (my-cv)

The CV app uses `cloudflared` instead of a traditional ingress + cert-manager. Cloudflare handles TLS termination.

- [ ] Install `cloudflared` CLI locally: `brew install cloudflare/cloudflare/cloudflared`
- [ ] Log in: `cloudflared tunnel login`
- [ ] Create the tunnel: `cloudflared tunnel create filip-cv`
- [ ] Note the tunnel UUID printed in the output
- [ ] Update `gitops/apps/my-cv/base/cloudflare-tunnel.yaml` — replace `<TUNNEL_ID>` with the UUID
- [ ] Create a DNS CNAME in Cloudflare pointing your domain → `<TUNNEL_ID>.cfargotunnel.com`
- [ ] Create the credentials secret in the cluster:
  ```bash
  kubectl -n cv create secret generic cloudflare-tunnel \
    --from-file=credentials.json=~/.cloudflared/<TUNNEL_ID>.json
  ```
- [ ] Verify `cloudflared` pod is `Running` in the `cv` namespace

### 6 — Ingress + TLS (vevsdesign and fallback ingress for my-cv)

Both apps have an `ingress.yaml` in their base. These require an ingress controller and TLS certificates.

- [ ] Deploy `ingress-nginx` to the cluster:
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/baremetal/deploy.yaml
  ```
- [ ] Deploy `cert-manager`:
  ```bash
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
  ```
- [ ] Create a `ClusterIssuer` for Let's Encrypt (staging first, then production)
- [ ] Update `gitops/apps/my-cv/base/ingress.yaml` — replace `cv.example.com` with actual domain
- [ ] Update `gitops/apps/vevsdesign/base/ingress.yaml` — replace `vevsdesign.example.com` with actual domain
- [ ] Add `cert-manager.io/cluster-issuer: letsencrypt-prod` annotation to both ingress resources
- [ ] Point DNS A records for both domains to the Hetzner worker node public IP

### 7 — vevsdesign app

- [ ] Decide on the container image and update `gitops/apps/vevsdesign/base/deployment.yaml` — replace `PLACEHOLDER_IMAGE`
- [ ] Set the actual namespace name if different from `vevsdesign`
- [ ] Add any app-specific environment variables to `gitops/apps/vevsdesign/base/configmap.yaml`

### 8 — Optional: remote Terraform state

By default, state is stored locally in `terraform/terraform.tfstate`.  
For team use or to avoid losing state, switch to Hetzner Object Storage.

- [ ] Create an Object Storage bucket in the Hetzner console
- [ ] Uncomment the `backend "s3"` block in `terraform/backend.tf`
- [ ] Fill in bucket endpoint, name, and credentials
- [ ] Run `terraform init -migrate-state`

### 9 — Housekeeping

- [ ] Set git identity globally so commits are attributed correctly:
  ```bash
  git config --global user.name "Filip Csupka"
  git config --global user.email "your@email.com"
  ```
- [ ] Verify `.gitignore` covers `kubeconfig.yaml`, `terraform.tfvars`, and `.terraform/`
- [ ] Review firewall rules in `terraform/firewall.tf` — restrict SSH `source_ips` to your own IP in production

---

## Quick reference

| Command | Purpose |
|---|---|
| `terraform init && terraform apply` | Provision Hetzner VMs + k3s cluster |
| `terraform destroy` | Tear down all cloud resources |
| `kubectl apply -k argocd/install/` | Install ArgoCD on the cluster |
| `kubectl apply -f argocd/apps/` | Register all applications with ArgoCD |
| `kubectl -n argocd get pods` | Check ArgoCD health |
| `KUBECONFIG=kubeconfig.yaml kubectl get nodes` | Verify cluster nodes |
