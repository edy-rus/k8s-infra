locals {
  cp_nodes     = { for k, n in var.nodes : k => n if n.role == "controlplane" }
  worker_nodes = { for k, n in var.nodes : k => n if n.role == "worker" }
  cp_ips       = [for n in values(local.cp_nodes) : n.ip]
  worker_ips   = [for n in values(local.worker_nodes) : n.ip]
  # Bootstrap etcd on the first control plane (sorted by name, so stable).
  bootstrap_ip = local.cp_nodes[sort(keys(local.cp_nodes))[0]].ip

  # Empty patch files (comments only) are skipped.
  patch = { for f in ["all", "controlplane", "worker"] :
    f => fileexists("${var.patches_dir}/${f}.yaml") ? file("${var.patches_dir}/${f}.yaml") : ""
  }
  has_content = { for f, c in local.patch :
    f => length(regexall("(?m)^[^#\\s]", c)) > 0
  }
}

# Cluster PKI and tokens. Lives only in (encrypted) state.
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "node" {
  for_each = var.nodes

  cluster_name       = var.cluster_name
  cluster_endpoint   = var.endpoint
  machine_type       = each.value.role
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  docs               = false
  examples           = false

  config_patches = concat(
    local.has_content["all"] ? [local.patch["all"]] : [],
    local.has_content[each.value.role] ? [local.patch[each.value.role]] : [],
    [templatefile("${path.module}/templates/node.yaml.tftpl", {
      hostname        = each.key
      install_disk    = each.value.install_disk
      installer_image = var.installer_image
      role            = each.value.role
      allow_workloads = each.value.allow_workloads
    })],
  )
}

# Applies config and keeps the OS on `installer_image`: bump talos_version and
# re-apply to upgrade. Also detects config drift on the node.
resource "talos_machine" "node" {
  for_each = var.nodes

  node                  = each.value.ip
  client_configuration  = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.node[each.key].machine_configuration
  image                 = var.installer_image

  # Draining needs a kubeconfig, which only exists after this resource (cycle),
  # and on a single node there is nowhere to drain to. Revisit with 3 nodes.
  drain_on_upgrade = false
}

# Bootstraps etcd once and owns Kubernetes upgrades (kubernetes_version).
resource "talos_cluster" "this" {
  depends_on = [talos_machine.node]

  node                 = local.bootstrap_ip
  control_plane_nodes  = local.cp_ips
  client_configuration = talos_machine_secrets.this.client_configuration
  kubernetes_version   = var.kubernetes_version
}

# Waits until Kubernetes itself is healthy, so `apply` only finishes when the
# cluster is usable.
data "talos_cluster_health" "this" {
  depends_on = [talos_cluster.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.cp_ips
  control_plane_nodes  = local.cp_ips
  worker_nodes         = local.worker_ips
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [data.talos_cluster_health.this]

  node                 = local.bootstrap_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.cp_ips
  nodes                = [for n in values(var.nodes) : n.ip]
}
