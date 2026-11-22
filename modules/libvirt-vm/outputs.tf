output "names" {
  value = keys(libvirt_domain.node)
}
