# k3s Single-Node Setup on Hetzner

Single Hetzner server running k3s — control plane + worker on one machine.

## Prerequisites

- Hetzner Cloud account + API token
- SSH key uploaded to Hetzner Cloud (note the name)
- Terraform >= 1.0 installed locally
- `jq` installed locally

## Step 1 — Create terraform.tfvars

Copy the example and fill in values:

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
hcloud_token         = "YOUR_HETZNER_API_TOKEN"
ssh_key_name         = "YOUR_SSH_KEY_NAME_IN_HETZNER"
ssh_private_key_path = "/absolute/path/to/hetzner_ed25519"
location             = "nbg1"
server_type          = "cx22"
```

- `hcloud_token` — Hetzner Cloud Console → Security → API Tokens → Generate
- `ssh_key_name` — Hetzner Cloud Console → Security → SSH Keys → name column
- `ssh_private_key_path` — absolute path to your local private key file

**Never commit terraform.tfvars — it contains secrets.**

## Step 2 — Get existing server ID

```bash
curl -s -H "Authorization: Bearer YOUR_HETZNER_API_TOKEN" \
  https://api.hetzner.cloud/v1/servers | jq '.servers[] | {id, name}'
```

Note the numeric `id` of your server.

## Step 3 — Init + import existing server

```bash
terraform init
terraform import hcloud_server.control_plane <SERVER_ID>
```

This tells terraform to manage the existing server instead of creating a new one.

## Step 4 — Plan + apply

```bash
terraform plan   # review changes: rename, firewall, labels
terraform apply
```

## Step 5 — Install k3s on server

`user_data` only runs at server creation. For existing servers, install manually:

```bash
ssh -i /path/to/hetzner_ed25519 root@<SERVER_IP> bash -s <<'EOF'
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable=traefik \
  --disable=servicelb \
  --tls-san=<SERVER_IP>" \
  sh -
EOF
```

Verify k3s is running:

```bash
ssh -i /path/to/hetzner_ed25519 root@<SERVER_IP> kubectl get nodes
```

## Step 6 — Fetch kubeconfig locally

```bash
ssh -i /path/to/hetzner_ed25519 root@<SERVER_IP> 'cat /etc/rancher/k3s/k3s.yaml' \
  | sed 's/127.0.0.1/<SERVER_IP>/g' \
  > ../kubeconfig.yaml

export KUBECONFIG=$(pwd)/../kubeconfig.yaml
kubectl get nodes
```

Expected output: single node with status `Ready` and role `control-plane,master`.

## Expanding to multi-node later

1. Uncomment private network in `network.tf`
2. Add `hcloud_server.worker` back to `nodes.tf`
3. Add `worker_private_ip` and `control_plane_private_ip` back to `variables.tf`
4. Re-enable `--flannel-iface=eth1` and `--tls-san` on private IP in `user_data/control_plane.sh`
5. Restore `user_data/worker.sh` with join token logic

## Files

| File | Purpose |
|------|---------|
| `main.tf` | Provider + SSH key data source |
| `nodes.tf` | Server resource + kubeconfig fetch |
| `firewall.tf` | Inbound rules: SSH, 6443, 80, 443, NodePort |
| `variables.tf` | Input variables |
| `locals.tf` | Derived names and labels |
| `outputs.tf` | Public IP, API endpoint, kubeconfig path |
| `versions.tf` | Provider version constraints |
| `backend.tf` | State backend options (local or S3) |
| `user_data/control_plane.sh` | Cloud-init: installs k3s on fresh server |
