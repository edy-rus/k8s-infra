resource "libvirt_pool" "talos" {
  name   = "talos"
  type   = "dir"
  target = { path = var.pool_path }
  create = { build = true, start = true, autostart = true }
}

# Downloaded from the Image Factory and uploaded into the pool. A new
# version/schematic gets a new name, so the old ISO is replaced cleanly.
resource "libvirt_volume" "iso" {
  name   = var.iso_name
  pool   = libvirt_pool.talos.name
  create = { content = { url = var.iso_url } }
  # libvirt detects the uploaded file as "iso"; anything else makes the
  # provider report an inconsistent result after apply.
  target = { format = { type = "iso" } }
}

resource "libvirt_volume" "disk" {
  for_each = var.nodes

  name          = "${each.key}.qcow2"
  pool          = libvirt_pool.talos.name
  capacity      = each.value.disk_gib
  capacity_unit = "GiB"
  target        = { format = { type = "qcow2" } }
}

resource "libvirt_domain" "node" {
  for_each = var.nodes

  name        = each.key
  type        = "kvm"
  vcpu        = each.value.vcpu
  memory      = each.value.memory_mib
  memory_unit = "MiB"
  autostart   = true
  running     = true

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    firmware     = "efi"
    # Empty disk on first boot falls through to the ISO (maintenance mode);
    # once Talos is installed the disk boots and the ISO is ignored.
    boot_devices = [{ dev = "hd" }, { dev = "cdrom" }]
    # Never Microsoft keys (Fedora's default): they reject Talos images.
    # secure_boot: Secure Boot firmware with *no* keys enrolled = setup mode,
    # so the Talos SecureBoot ISO enrolls the Image Factory keys on first boot.
    # Otherwise: plain UEFI.
    # Keep alphabetical: libvirt sorts these, and any other order makes the
    # provider report an inconsistent result.
    firmware_info = {
      features = [
        { name = "enrolled-keys", enabled = "no" },
        { name = "secure-boot", enabled = var.secure_boot ? "yes" : "no" },
      ]
    }
  }

  # Start from a fresh NVRAM copy of the template, so a VARS file left over
  # from an earlier definition (other keys, other SB state) can't leak in.
  create = { reset_nvram = true }

  # SMM is required for Secure Boot OVMF (protects the variable store).
  features = { acpi = true, smm = { state = "on" } }
  cpu      = { mode = "host-passthrough" }

  devices = {
    disks = [
      {
        source = { volume = { pool = libvirt_pool.talos.name, volume = libvirt_volume.disk[each.key].name } }
        target = { dev = "vda", bus = "virtio" }
        driver = { name = "qemu", type = "qcow2", discard = "unmap" }
      },
      {
        device    = "cdrom"
        read_only = true
        source    = { volume = { pool = libvirt_pool.talos.name, volume = libvirt_volume.iso.name } }
        target    = { dev = "sda", bus = "sata" }
      },
    ]

    interfaces = [{
      source = { bridge = { bridge = var.bridge } }
      mac    = { address = each.value.mac }
      model  = { type = "virtio" }
    }]

    # qemu-guest-agent extension talks over this; lets libvirt shut
    # the VM down cleanly and report its IP.
    channels = [{
      source = { unix = { mode = "bind" } }
      target = { virt_io = { name = "org.qemu.guest_agent.0" } }
    }]

    consoles = [{ target = { type = "serial", port = 0 } }]
    graphics = [{ vnc = { auto_port = true, listen = "127.0.0.1" } }]
    rngs     = [{ model = "virtio", backend = { random = "/dev/urandom" } }]
  }
}
