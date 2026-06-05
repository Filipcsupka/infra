locals {
  cluster_name = "k8s"

  common_labels = {
    managed-by  = "terraform"
    cluster     = local.cluster_name
    environment = "production"
  }

  control_plane_name = "${local.cluster_name}-control-plane"
  worker_name        = "${local.cluster_name}-worker-01"
  firewall_name      = "${local.cluster_name}-firewall"
}
