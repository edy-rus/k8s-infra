variable "nodes" {
  type = map(object({
    mac        = string
    vcpu       = number
    memory_mib = number
    disk_gib   = number
  }))
}
variable "iso_url" { type = string }
variable "iso_name" { type = string }
variable "pool_path" { type = string }
variable "bridge" { type = string }
variable "secure_boot" { type = bool }
