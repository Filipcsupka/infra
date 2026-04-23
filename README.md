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

### 5 — Traefik ingress + Cloudflare DNS/proxy

The cluster exposes apps through Traefik on the Hetzner node ports `80` and `443`.
Cloudflare provides public DNS and browser-facing HTTPS.
Traefik is installed by Ansible through Helm; chart settings are in `ansible/helm-values/traefik.yaml`.

- [ ] Confirm the Hetzner firewall allows inbound TCP `80` and `443`.
- [ ] Run the Ansible k3s playbook; it installs or upgrades Traefik with host ports:
  ```bash
  ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/k3s.yml
  ```
- [ ] In Cloudflare, create proxied `A` records pointing to the Hetzner public IP:
  - `filipcsupka.online` → `<HETZNER_PUBLIC_IP>`
  - `vevsdesign.sk` → `<HETZNER_PUBLIC_IP>`
- [ ] In Cloudflare SSL/TLS, set encryption mode to `Flexible` for the first deploy.
- [ ] Verify Traefik:
  ```bash
  kubectl -n traefik get pods
  kubectl get ingress -A
  ```

Later, if origin TLS is required, add cert-manager and switch Cloudflare SSL/TLS from `Flexible` to `Full (strict)`.

### 6 — vevsdesign app

- [ ] Image is published to `ghcr.io/filipcsupka/vevsdesign`.
- [ ] GitHub Actions updates `gitops/apps/vevsdesign/overlays/prod/kustomization.yaml` with the latest `sha-...` tag.
- [ ] Add app-specific environment variables to `gitops/apps/vevsdesign/base/configmap.yaml` when needed.

### 7 — Optional: remote Terraform state

By default, state is stored locally in `terraform/terraform.tfstate`.  
For team use or to avoid losing state, switch to Hetzner Object Storage.

- [ ] Create an Object Storage bucket in the Hetzner console
- [ ] Uncomment the `backend "s3"` block in `terraform/backend.tf`
- [ ] Fill in bucket endpoint, name, and credentials
- [ ] Run `terraform init -migrate-state`

### 8 — Housekeeping

- [ ] Set git identity globally so commits are attributed correctly:
  ```bash
  git config --global user.name "Filip Csupka"
  git config --global user.email "your@email.com"
  ```
- [ ] Verify `.gitignore` covers `kubeconfig.yaml`, `terraform.tfvars`, and `.terraform/`
- [ ] Review firewall rules in `terraform/firewall.tf` (currently SSH and K8s API are open for mobility)

### 9 — Future hardening: Tailscale for kubeconfig from anywhere

Current state keeps port `6443` public so `kubeconfig` works from any location.
If you want secure global access later, move Kubernetes API access to Tailscale and then close public `6443`.

- [ ] Install and authenticate Tailscale on the cluster node:
  ```bash
  curl -fsSL https://tailscale.com/install.sh | sh
  sudo tailscale up --ssh
  tailscale ip -4
  ```
- [ ] Add the Tailscale IP as an extra Kubernetes API TLS SAN in `ansible/playbooks/k3s.yml`:
  - Keep existing `--tls-san={{ ansible_host }}`
  - Add `--tls-san=<TAILSCALE_IPV4>`
- [ ] Re-run Ansible to apply k3s config changes:
  ```bash
  ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/k3s.yml
  ```
- [ ] Update local kubeconfig server endpoint from public IP to the node Tailscale IP:
  - from: `https://<public-ip>:6443`
  - to: `https://<tailscale-ip>:6443`
- [ ] Validate API access over Tailscale:
  ```bash
  KUBECONFIG=kubeconfig.yaml kubectl get nodes
  ```
- [ ] After validation, harden firewall by restricting or closing public `6443` in `terraform/firewall.tf`.

Notes:
- Keep ports `80` and `443` public so websites stay reachable from the internet.
- If you use Tailscale MagicDNS, you can use node name instead of raw Tailscale IP in kubeconfig.

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
