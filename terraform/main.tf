provider "hcloud" {
  token = var.hcloud_token
}

# Random token used by k3s nodes to join the cluster
resource "random_password" "k3s_token" {
  length  = 48
  special = false
}
