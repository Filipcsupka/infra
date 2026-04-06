output "control_plane_public_ip" {
  description = "Public IP of the control plane — use this in your kubeconfig"
  value       = hcloud_server.control_plane.ipv4_address
}

output "worker_public_ip" {
  description = "Public IP of the worker node"
  value       = hcloud_server.worker.ipv4_address
}

output "k8s_api_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = "https://${hcloud_server.control_plane.ipv4_address}:6443"
}

output "kubeconfig_path" {
  description = "Local path where kubeconfig was saved after apply"
  value       = "../kubeconfig.yaml"
}
