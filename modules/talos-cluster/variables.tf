variable "cluster_name" { type = string }
variable "endpoint" { type = string }
variable "talos_version" { type = string }
variable "kubernetes_version" { type = string }
variable "installer_image" { type = string }
variable "patches_dir" { type = string }

variable "nodes" {
  type = map(object({
    role            = string
    ip              = string
    install_disk    = string
    allow_workloads = bool
  }))
}
