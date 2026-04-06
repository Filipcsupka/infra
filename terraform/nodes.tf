data "hcloud_ssh_key" "k8s" {
  name = var.ssh_key_name
}

# ── Control plane ────────────────────────────────────────────────────────────
resource "hcloud_server" "control_plane" {
  name         = "k8s-control-plane"
  image        = var.os_image
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [data.hcloud_ssh_key.k8s.id]
  firewall_ids = [hcloud_firewall.k8s.id]

  user_data = templatefile("${path.module}/user_data/control_plane.sh", {
    k3s_token                = random_password.k3s_token.result
    control_plane_private_ip = var.control_plane_private_ip
  })

  network {
    network_id = hcloud_network.k8s.id
    ip         = var.control_plane_private_ip
  }

  depends_on = [hcloud_network_subnet.k8s]
}

# ── Worker ───────────────────────────────────────────────────────────────────
resource "hcloud_server" "worker" {
  name         = "k8s-worker-1"
  image        = var.os_image
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [data.hcloud_ssh_key.k8s.id]
  firewall_ids = [hcloud_firewall.k8s.id]

  user_data = templatefile("${path.module}/user_data/worker.sh", {
    k3s_token                = random_password.k3s_token.result
    control_plane_private_ip = var.control_plane_private_ip
  })

  network {
    network_id = hcloud_network.k8s.id
    ip         = var.worker_private_ip
  }

  depends_on = [hcloud_network_subnet.k8s, hcloud_server.control_plane]
}

# ── Fetch kubeconfig after control plane is ready ────────────────────────────
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [hcloud_server.control_plane]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = hcloud_server.control_plane.ipv4_address
      user        = "root"
      private_key = file(var.ssh_private_key_path)
    }
    inline = [
      "until kubectl get nodes 2>/dev/null | grep -q 'Ready'; do echo 'Waiting for cluster...'; sleep 10; done",
      "echo 'Cluster ready'"
    ]
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no \
        root@${hcloud_server.control_plane.ipv4_address} \
        'cat /etc/rancher/k3s/k3s.yaml' \
        | sed 's/127.0.0.1/${hcloud_server.control_plane.ipv4_address}/g' \
        > ../kubeconfig.yaml
      echo "kubeconfig saved to infra/kubeconfig.yaml"
    EOT
  }
}
