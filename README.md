# k8s-infra

Infrastructure for Talos Linux Kubernetes clusters, fully declarative with
OpenTofu. Workloads live in the separate `k8s-gitops` repo (Argo CD); this repo
stops at "cluster up (+ Argo CD installed)".

```
modules/
  libvirt-vm/        VMs on a libvirt host (bridged, UEFI/SecureBoot)
  talos-cluster/     Talos config, install, bootstrap, upgrades, health, kubeconfig
envs/
  lab/               cluster "lab": VMs on a single libvirt host.
  prod/              (planned) bare metal + a cloud VPS.
```

Each env is an independent OpenTofu root: its own `terraform.tfvars`, Talos
patches, encrypted state and Talos secrets, so changes in `lab` can't touch
`prod`. Promote a change by applying it in `lab` first, then the same in `prod`.

Nodes are one map per env. `platform = "libvirt"` creates a VM;
`platform = "metal"` means "already booted from the ISO into
maintenance mode at this IP", so it gets the same Talos config, just no VM.

## Prerequisites

- OpenTofu ≥ 1.10 (state encryption is OpenTofu-only).
- SSH to the libvirt host through ssh-agent; the provider uses the system `ssh`
  (`qemu+sshcmd://`). Not `qemu+ssh://`: SELinux on Fedora blocks sshd from
  forwarding libvirt's socket.
- libvirt host: the SSH user may manage system libvirt without a password
  prompt (a polkit rule for `org.libvirt.unix.manage`, or the `libvirt` group).
- DHCP reservations for each VM's `mac` → `ip` from the env's `terraform.tfvars`.
- A state passphrase per env (≥ 16 chars), from your secret store.

## Use

```sh
cd envs/lab
export TF_VAR_state_passphrase="$(pass <your-entry>)"   # or any secret store
tofu init
tofu plan -out tfplan
tofu apply tfplan    # finishes only when Kubernetes is healthy
```

Merge the admin credentials into your home configs rather than writing them
into the repo:

```sh
tofu output -raw talosconfig > /tmp/talosconfig
talosctl config merge /tmp/talosconfig && rm /tmp/talosconfig   # context "lab"
talosctl -n <cp-ip> kubeconfig                                   # merges admin@lab
talosctl -n <cp-ip> dashboard
kubectl get nodes
```

## Day 2

- **Upgrade Talos:** bump `talos_version`, `tofu apply`. `talos_machine` upgrades each node in place.
- **Upgrade Kubernetes:** bump `kubernetes_version`, `tofu apply`. `talos_cluster` runs `upgrade-k8s`.
- **Add extensions:** edit `extensions` (new schematic → new installer image → nodes upgrade onto it).
- **Add a node:** add an entry to `nodes` (+ DHCP reservation), `tofu apply`.
- **Workloads on a control plane:** `allow_workloads` per node (default true; false keeps the NoSchedule taint).
- **Drift:** `tofu plan` shows config drift on nodes (`talos_machine` compares what's applied).
- **Wipe back to stock:** `envs/lab/reset.sh [node]` replaces the VM, its disk, the machine config and the etcd bootstrap, but keeps `talos_machine_secrets`, so your kubeconfig/talosconfig still work. Check the plan shows exactly 4 replacements before typing `yes`.

## State

Each environment has its own `envs/<env>/terraform.tfstate`: local, encrypted
(AES-GCM, key derived from the passphrase) and gitignored. It holds the cluster
CA, so back it up: losing it means losing admin access to the cluster. Back up
the passphrase too: without it the state is unreadable.

## Gotchas

- Config uses Talos 1.14 multi-document format (`UnattendedInstallConfig`,
  `HostnameConfig`, `KubeNodeConfig`…), not the old `machine.install` fields.
  Patches in `envs/<env>/patches/` must target those documents.
- `cluster_endpoint` defaults to the first control plane's IP. Set a VIP or DNS
  name **before** adding more control planes (see ROADMAP.md).
- VM disks live in the `talos` pool (`/var/lib/libvirt/talos` by default). Put
  it on SSD: etcd is sensitive to slow fsync.
- `secure_boot = true` (default): SecureBoot ISO + installer, OVMF with Secure
  Boot on and no keys (setup mode). On a VM's first boot the ISO enrolls the
  Image Factory keys; if the boot menu waits on "Enroll Secure Boot keys",
  pick it once in the VM console. Never let libvirt pick its default
  Microsoft-keys firmware: it rejects Talos images. Toggling it = reinstall.
- The ISO stays attached; boot order is disk first, so it only matters on a
  fresh (empty) disk.
