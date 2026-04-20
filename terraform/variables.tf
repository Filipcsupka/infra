variable "hcloud_token" {
  description = "Hetzner Cloud API token (set via TF_VAR_hcloud_token or terraform.tfvars)"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1"
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cx22"
}

variable "os_image" {
  description = "Base OS image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_key_name" {
  description = "Name of SSH key uploaded to Hetzner Cloud"
  type        = string
}
