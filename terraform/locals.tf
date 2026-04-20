locals {
  cluster_name = "k8s"

  common_labels = {
    managed-by  = "terraform"
    cluster     = local.cluster_name
    environment = "production"
  }

  control_plane_name = "${local.cluster_name}-control-plane"
  firewall_name      = "${local.cluster_name}-firewall"
}
