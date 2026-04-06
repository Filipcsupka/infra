locals {
  cluster_name = "k8s"

  common_labels = {
    managed-by  = "terraform"
    cluster     = local.cluster_name
    environment = "production"
  }

  # Derived node names — change cluster_name above to rename everything
  control_plane_name = "${local.cluster_name}-control-plane"
  worker_name        = "${local.cluster_name}-worker-1"
  network_name       = "${local.cluster_name}-network"
  firewall_name      = "${local.cluster_name}-firewall"
}
