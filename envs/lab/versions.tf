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
