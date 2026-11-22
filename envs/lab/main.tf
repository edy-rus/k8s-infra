# Layer 1: one Talos image (Image Factory schematic) shared by VMs and metal.
resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = { officialExtensions = var.extensions }
    }
  })
}

data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "metal"
  architecture  = "amd64"
}

locals {
  libvirt_nodes = { for k, n in var.nodes : k => n if n.platform == "libvirt" }
  controlplanes = { for k, n in var.nodes : k => n if n.role == "controlplane" }
  urls          = data.talos_image_factory_urls.this.urls
  # SecureBoot images are signed UKIs; the installer must match the ISO.
  iso_url         = var.secure_boot ? local.urls.iso_secureboot : local.urls.iso
  installer_image = var.secure_boot ? local.urls.installer_secureboot : local.urls.installer

  endpoint = coalesce(
    var.cluster_endpoint,
    "https://${values(local.controlplanes)[0].ip}:6443",
  )
}

# Layer 2: machines. Only libvirt nodes are created here; metal nodes are
# booted by hand from the same ISO (tofu output iso_url).
module "libvirt" {
  source = "../../modules/libvirt-vm"

  nodes       = local.libvirt_nodes
  iso_url     = local.iso_url
  iso_name    = "talos-${var.talos_version}-${substr(talos_image_factory_schematic.this.id, 0, 8)}${var.secure_boot ? "-sb" : ""}.iso"
  pool_path   = var.libvirt_pool_path
  bridge      = var.libvirt_bridge
  secure_boot = var.secure_boot
}

# Layer 3: Talos + Kubernetes on every node, wherever it runs.
module "cluster" {
  source     = "../../modules/talos-cluster"
  depends_on = [module.libvirt]

  cluster_name       = var.cluster_name
  endpoint           = local.endpoint
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  installer_image    = local.installer_image
  nodes              = var.nodes
  patches_dir        = "${path.root}/patches"
}
