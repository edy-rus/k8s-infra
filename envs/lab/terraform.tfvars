talos_version      = "v1.14.6"
kubernetes_version = "v1.37.1"

nodes = {
  talos-cp1 = {
    role       = "controlplane"
    platform   = "libvirt"
    ip         = "192.168.68.161"
    mac        = "52:54:00:68:00:61"
    vcpu       = 2
    memory_mib = 6144
  }

  # Later, e.g. 3 control planes, workloads on two of them:
  # talos-cp2 = { role = "controlplane", platform = "libvirt", ip = "192.168.68.162", mac = "52:54:00:68:00:62" }
  # talos-cp3 = { role = "controlplane", platform = "libvirt", ip = "192.168.68.163", mac = "52:54:00:68:00:63", allow_workloads = false }
  # worker1   = { role = "worker", platform = "metal", ip = "192.168.68.170", install_disk = "/dev/sda" }
}
