output "iso_url" {
  description = "Talos ISO for this schematic/version (boot metal nodes from it)."
  value       = local.iso_url
}

output "talosconfig" {
  value     = module.cluster.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.cluster.kubeconfig
  sensitive = true
}
