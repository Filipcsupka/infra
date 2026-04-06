variable "hcloud_token" {
  description = "Hetzner Cloud API token (set via TF_VAR_hcloud_token or terraform.tfvars)"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1" # Nuremberg — change to hel1 (Helsinki) or fsn1 (Falkenstein)
}

variable "server_type" {
  description = "Hetzner server type for both nodes"
  type        = string
  default     = "cx22" # 2 vCPU, 4 GB RAM — enough for a lab cluster
}

variable "os_image" {
  description = "Base OS image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_key_name" {
  description = "Name of the SSH key already uploaded to Hetzner Cloud"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Local path to the matching private key (used by null_resource provisioners)"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "private_network_cidr" {
  description = "CIDR for the private Hetzner network"
  type        = string
  default     = "10.0.0.0/8"
}

variable "subnet_cidr" {
  description = "Subnet CIDR within the private network"
  type        = string
  default     = "10.0.1.0/24"
}

variable "control_plane_private_ip" {
  description = "Static private IP assigned to the control plane node"
  type        = string
  default     = "10.0.1.10"
}

variable "worker_private_ip" {
  description = "Static private IP assigned to the worker node"
  type        = string
  default     = "10.0.1.11"
}
