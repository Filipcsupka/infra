resource "hcloud_server" "control_plane" {
  name         = local.control_plane_name
  labels       = local.common_labels
  image        = var.os_image
  server_type  = var.server_type
  location     = var.location
  firewall_ids = [hcloud_firewall.k8s.id]
}

resource "hcloud_server" "worker" {
  name         = local.worker_name
  labels       = local.common_labels
  image        = var.os_image
  server_type  = "cx23"
  location     = var.location
  ssh_keys     = [data.hcloud_ssh_key.k8s.id]
  firewall_ids = [hcloud_firewall.k8s.id]
}
