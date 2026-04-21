terraform {
  required_version = ">= 1.5"

  cloud {
    organization = "devopssro"

    workspaces {
      name = "hetzner-webapps"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.47"
    }
  }
}
