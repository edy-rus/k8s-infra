output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

# Host and base64 credentials for the kubernetes and helm providers.
output "kubernetes_client" {
  value     = talos_cluster_kubeconfig.this.kubernetes_client_configuration
  sensitive = true
}
