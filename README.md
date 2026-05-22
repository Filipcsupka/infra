# infra

Personal infrastructure repository — IaC, GitOps, and ArgoCD configuration for a home/lab Kubernetes cluster running on Hetzner Cloud.

## Repository structure

```
infra/
├── terraform/          # Hetzner Cloud — provision k3s cluster (1 control plane + 1 worker)
├── argocd/
│   ├── install/        # ArgoCD server deployment (kustomization + config patches)
│   ├── projects/       # AppProject definitions
│   └── apps/           # ArgoCD Application CRDs grouped by domain (web/observability/core)
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

- [ ] Apply the root ArgoCD application:
  ```bash
  kubectl apply -f argocd/root-application.yaml
  ```
- [ ] Verify the root application creates the AppProject and child applications:
  ```bash
  kubectl -n argocd get application infra-root
  kubectl -n argocd get appproject,applications
  ```
- [ ] After bootstrap, treat `argocd/projects/` and `argocd/apps/` as Argo-managed:
  - push git changes there and let ArgoCD reconcile them
  - the single `ArgoCD` workflow runs on commits touching `argocd/**`, on a daily schedule, and on manual dispatch
  - the workflow always refreshes `infra-root` and only runs Helm upgrade when ArgoCD itself changed

### CI/CD operating model

- `Deploy Cluster` is the only cluster bootstrap and rebuild workflow.
- `ArgoCD` is the only Argo/application sync workflow.
- Terraform, k3s/Ansible, and Argo bootstrap are intentionally chained inside `Deploy Cluster` so a fresh environment is one button click.

### 5 — Traefik ingress + Cloudflare DNS/proxy

The cluster exposes apps through Traefik on the Hetzner node ports `80` and `443`.
Cloudflare provides public DNS and browser-facing HTTPS.
Traefik is installed by Ansible through Helm; chart settings are in `ansible/helm-values/traefik.yaml`.
The k3s playbook also sets `providers.kubernetesIngress.ingressEndpoint.ip` to the control-plane public IP so Kubernetes Ingress objects publish a load balancer address and ArgoCD can mark them healthy.

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

## GPU worker node

The cluster can run an additional NVIDIA GPU worker over Tailscale. Hetzner remains the control-plane/worker node for public apps, while the home GPU node is tainted for explicit AI workloads.

Current node addresses:

| Node | Role | Public IP | Tailscale IP |
|---|---|---:|---:|
| `family-webapp` | k3s server + public app worker | `178.104.235.97` | `100.82.16.35` |
| `k3sgpu` | NVIDIA GPU worker | n/a | `100.86.152.16` |

Prerequisites:

- Hetzner control-plane and GPU worker are logged in to the same Tailscale tailnet.
- GPU worker has the NVIDIA driver and `nvidia-container-runtime` installed.
- SSH key access works for `root@family-webapp` and `ja@k3sgpu`.
- For the GPU worker, either use `--ask-become-pass` or configure passwordless sudo for automation.

Run:

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/gpu-worker.yml --ask-become-pass
```

The playbook:

- configures k3s flannel/node networking to use `tailscale0`;
- reads the k3s join token from the control-plane without committing it;
- joins `k3sgpu` as a k3s agent with `--default-runtime=nvidia`;
- labels and taints the GPU node with `accelerator=nvidia` and `nvidia.com/gpu=true:NoSchedule`;
- installs NVIDIA `k8s-device-plugin` and restricts it to GPU nodes.

Verify:

```bash
KUBECONFIG=kubeconfig.yaml kubectl get nodes -o wide
KUBECONFIG=kubeconfig.yaml kubectl get node k3sgpu \
  -o jsonpath='{.status.allocatable.nvidia\.com/gpu}{" GPU\n"}'
KUBECONFIG=kubeconfig.yaml kubectl -n kube-system get pods \
  -l name=nvidia-device-plugin-ds -o wide
```

GPU workloads must request `nvidia.com/gpu` and tolerate the GPU taint:

```yaml
tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
nodeSelector:
  accelerator: nvidia
resources:
  limits:
    nvidia.com/gpu: 1
```

---

## Monitoring stack

The observability stack is currently pinned to the GPU worker node (`k3sgpu`, `accelerator: nvidia`) unless a chart component explicitly requires something else.
The intended telemetry flow is:

- `dcgm-exporter` exposes NVIDIA GPU metrics
- Prometheus scrapes those metrics via `ServiceMonitor`
- Grafana reads them from the default `Prometheus` datasource

This is the preferred model for this repo. GPU metrics are not supposed to use a separate Grafana datasource.

### Apps

| ArgoCD app | Chart | Namespace | Purpose |
|---|---|---|---|
| `prometheus-stack` | `kube-prometheus-stack` | `monitoring` | Prometheus + Grafana + node-exporter + kube-state-metrics |
| `dcgm-exporter` | `nvidia/dcgm-exporter` | `monitoring` | NVIDIA GPU metrics (RTX 2070) |
| `minio` | `minio/minio` | `monitoring` | S3-compatible storage for Loki |
| `loki` | `grafana/loki` | `monitoring` | Log aggregation, single-binary mode |
| `alloy` | `grafana/alloy` | `monitoring` | Log collection |
| `sealed-secrets` | `sealed-secrets` | `kube-system` | SealedSecret controller |
| `monitoring-secrets` | kustomize | `monitoring` | Decrypted secrets from `gitops/sealed-secrets/` |
| `monitoring` | kustomize | `monitoring` | Uptime Kuma proxy (existing, unchanged) |

### Grafana

URL: `https://grafana.filipcsupka.online`  
Default credentials: `admin` / `prom-operator` ← **change after first login**

DNS: Add Cloudflare A record `grafana` → `178.104.235.97` (same as `ai`).

Pre-provisioned dashboards (auto-pulled from grafana.com on startup):

| ID | Dashboard |
|---|---|
| 23382 | NVIDIA DCGM Dashboard for Kubernetes |
| 15757 | Kubernetes — Global view |
| 15759 | Kubernetes — Nodes |
| 15760 | Kubernetes — Pods |
| 1860 | Node Exporter Full |
| 13639 | Loki log explorer |

### Key settings

- Prometheus retention: **1 day**, 5 Gi PVC
- Loki retention: **1 day**, MinIO (S3) backend, 2 Gi WAL PVC
- MinIO storage: **10 Gi** PVC, bucket `loki` auto-created
- AlertManager: **disabled**
- Alloy: currently GPU-pinned in this repo state

### Current live state and handoff notes

As of `2026-05-22`:

- the repo uses an App-of-Apps model
- `infra-root` manages `argocd/projects/**` and `argocd/apps/**`
- GitHub Actions workflow model is intentionally reduced to:
  - `Deploy Cluster`
  - `ArgoCD`
- `ArgoCD` runs on commits touching `argocd/**`, daily, and on manual dispatch
- `Deploy Cluster` is the only full bootstrap / rebuild workflow

Observability-specific notes:

- `dcgm-exporter` is configured with `serviceMonitor.enabled: true`
- Prometheus scrape path is:
  - `ServiceMonitor dcgm-exporter`
  - `Service dcgm-exporter`
  - endpoint backing the current pod on `k3sgpu`
- the Grafana GPU dashboard is configured to use the default `Prometheus` datasource
- the extra temporary `dcgm` Grafana datasource was removed from git and from the live datasource ConfigMap

Current blocker to remember:

- ArgoCD can stay `Progressing` on apps with ingresses because Traefik was not publishing `status.loadBalancer`
- this was fixed in repo by setting Traefik Helm arg:
  - `providers.kubernetesIngress.ingressEndpoint.ip={{ ansible_host }}`
- that change lives in `ansible/playbooks/k3s.yml`
- it requires running `Deploy Cluster` so Traefik is upgraded on the cluster
- until that rollout happens, apps such as `prometheus-stack` may keep waiting on ingress health even when pods are healthy

What to do next when resuming:

1. Run `Deploy Cluster` once so Traefik starts publishing ingress status.
2. Re-check `kubectl get ingress -A` and confirm ingresses have a load balancer address.
3. Re-check `kubectl -n argocd get applications`.
4. Validate the Grafana GPU dashboard again after `prometheus-stack` reaches healthy/synced.

### Sealed secrets (TODO — do after first deploy)

Credentials are currently **hardcoded** in Helm values (private repo, POC).
Replace them with SealedSecrets once the controller is running:

```bash
# 1. Edit the passwords in the script
vim scripts/seal-monitoring-secrets.sh

# 2. Run it (requires kubeseal + kubectl in PATH, controller must be Running)
KUBECONFIG=kubeconfig.yaml bash scripts/seal-monitoring-secrets.sh

# 3. Commit the generated files
git add gitops/sealed-secrets/ && git commit -m "secrets: seal monitoring credentials" && git push
```

Then update the three Helm apps to use `existingSecret` instead of inline values:

| App | Secret name | Helm keys to change |
|---|---|---|
| `prometheus-stack` | `grafana-admin-secret` | `grafana.admin.existingSecret` |
| `minio` | `minio-root-secret` | `existingSecret` |
| `loki` | `loki-minio-secret` | inject via `singleBinary.extraEnvFrom` |

---

## Quick reference

| Command | Purpose |
|---|---|
| `terraform init && terraform apply` | Provision Hetzner VMs + k3s cluster |
| `terraform destroy` | Tear down all cloud resources |
| `kubectl apply -k argocd/install/` | Install ArgoCD on the cluster |
| `kubectl apply -f argocd/root-application.yaml` | Register the root ArgoCD application |
| `kubectl -n argocd get pods` | Check ArgoCD health |
| `kubectl -n argocd get applications` | Check child application state |
| `KUBECONFIG=kubeconfig.yaml kubectl get nodes` | Verify cluster nodes |
