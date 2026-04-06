# ── State backend ─────────────────────────────────────────────────────────────
#
# Option A — local (default, fine for solo/lab use)
# No configuration needed. State is stored in terraform.tfstate locally.
# Add terraform.tfstate to .gitignore — never commit state.
#
# Option B — Hetzner Object Storage (S3-compatible, recommended for teams)
# Uncomment and fill in bucket details, then run: terraform init -migrate-state
#
# terraform {
#   backend "s3" {
#     endpoint                    = "https://nbg1.your-objectstorage.com"
#     bucket                      = "tf-state"
#     key                         = "k8s-cluster/terraform.tfstate"
#     region                      = "main"
#     skip_credentials_validation = true
#     skip_metadata_api_check     = true
#     skip_region_validation      = true
#     force_path_style            = true
#     access_key                  = "your-access-key"   # use TF_VAR or env var
#     secret_key                  = "your-secret-key"
#   }
# }
