variable "state_passphrase" {
  description = "Passphrase for state encryption (min 16 chars). Set TF_VAR_state_passphrase from your secret store."
  type        = string
  sensitive   = true
}

variable "libvirt_uri" {
  description = <<-EOT
    libvirt connection to the VM host. +sshcmd runs the system `ssh` (your
    agent, ~/.ssh/config, known_hosts) and virt-ssh-helper on the host, like
    virsh does. Not +ssh: that forwards the socket through sshd, which
    SELinux denies on Fedora (sshd_session_t -> virt_var_run_t).
  EOT
  type        = string
  default     = "qemu+sshcmd://core@192.168.68.56/system"
}

variable "cluster_name" {
  type    = string
  default = "lab"
}

variable "talos_version" {
  description = "Talos OS version. Changing it upgrades every node in place."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version. Changing it runs Talos's upgrade-k8s."
  type        = string
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint. Empty = first control plane's IP. Set a VIP or DNS name before adding more control planes."
  type        = string
  default     = ""
}

variable "secure_boot" {
  description = <<-EOT
    Use Talos SecureBoot images (signed UKI ISO + installer) and boot VMs with
    Secure Boot on, firmware starting in setup mode so the ISO can enroll the
    Image Factory keys on first boot. Switching it needs a node reinstall.
  EOT
  type        = bool
  default     = true
}

variable "extensions" {
  description = "Official Talos system extensions baked into the image."
  type        = list(string)
  default     = ["siderolabs/qemu-guest-agent"]
}

variable "nodes" {
  description = <<-EOT
    Every cluster node, keyed by hostname. platform = "libvirt" creates a VM on
    the libvirt host; any other value (e.g. "metal") means the machine already
    exists and is booted into Talos maintenance mode at `ip`.
    IPs come from router DHCP reservations on the VM's MAC.
  EOT
  type = map(object({
    role         = string # controlplane | worker
    platform     = string # libvirt | metal
    ip           = string
    install_disk = optional(string, "/dev/vda")
    # Control planes only: also schedule workloads here (removes the
    # control-plane NoSchedule taint). Ignored for workers.
    allow_workloads = optional(bool, true)
    # libvirt only
    mac        = optional(string)
    vcpu       = optional(number, 2)
    memory_mib = optional(number, 4096)
    disk_gib   = optional(number, 40)
  }))

  validation {
    condition     = alltrue([for n in var.nodes : contains(["controlplane", "worker"], n.role)])
    error_message = "role must be controlplane or worker."
  }
  validation {
    condition     = alltrue([for n in var.nodes : n.platform != "libvirt" || n.mac != null])
    error_message = "libvirt nodes need a fixed mac (for the DHCP reservation)."
  }
  validation {
    condition     = length([for n in var.nodes : n if n.role == "controlplane"]) >= 1
    error_message = "At least one controlplane node is required."
  }
}

variable "libvirt_pool_path" {
  description = "Directory on the VM host for VM disks. Keep it on SSD (etcd hates slow fsync)."
  type        = string
  default     = "/var/lib/libvirt/talos"
}

variable "libvirt_bridge" {
  type    = string
  default = "br0"
}
