resource "hcloud_network" "k8s" {
  name     = local.network_name
  ip_range = var.private_network_cidr
  labels   = local.common_labels
}

resource "hcloud_network_subnet" "k8s" {
  network_id   = hcloud_network.k8s.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = var.subnet_cidr
}
