terraform {
  required_version = ">= 1.10.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.9"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.12.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
  }

  # State holds the cluster CA keys and admin credentials, so it is encrypted at
  # rest (OpenTofu only). Passphrase via TF_VAR_state_passphrase, see README.md.
  encryption {
    key_provider "pbkdf2" "state" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }
    state {
      method   = method.aes_gcm.state
      enforced = true
    }
    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

provider "talos" {}

# Talks to the cluster built above, with the admin credentials from state.
provider "helm" {
  kubernetes = {
    host                   = module.cluster.kubernetes_client.host
    cluster_ca_certificate = base64decode(module.cluster.kubernetes_client.ca_certificate)
    client_certificate     = base64decode(module.cluster.kubernetes_client.client_certificate)
    client_key             = base64decode(module.cluster.kubernetes_client.client_key)
  }
}
