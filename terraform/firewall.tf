resource "hcloud_firewall" "k8s" {
  name   = local.firewall_name
  labels = local.common_labels

  # SSH — open to world; security relies on key-based auth (no password login)
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "SSH"
  }

  # Kubernetes API server — open for now (to keep kubeconfig working from anywhere)
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "K8s API"
  }

  # HTTP / HTTPS ingress — open to the world for web apps
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTP"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTPS"
  }

  # Kubelet metrics — Prometheus scraping; restricted to cluster nodes only
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "10250"
    source_ips  = ["178.104.235.97/32", "178.104.193.227/32"]
    description = "Kubelet metrics (cluster-internal)"
  }
}
