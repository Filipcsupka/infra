output "control_plane_public_ip" {
  description = "Public IP — use in kubeconfig"
  value       = hcloud_server.control_plane.ipv4_address
}

output "k8s_api_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://${hcloud_server.control_plane.ipv4_address}:6443"
}

output "kubeconfig_path" {
  description = "Local kubeconfig path"
  value       = "../kubeconfig.yaml"
}
