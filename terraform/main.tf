provider "hcloud" {
  token = var.hcloud_token
}

data "hcloud_ssh_key" "k8s" {
  name = var.ssh_key_name
}
