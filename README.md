# k8s-infra

Infrastructure for Talos Linux Kubernetes clusters, fully declarative with
OpenTofu. Workloads live in the separate `k8s-gitops` repo (Argo CD); this repo
stops at "cluster up (+ Argo CD installed)".

```
modules/
  libvirt-vm/        VMs on a libvirt host (bridged, UEFI/SecureBoot)
  talos-cluster/     Talos config, install, bootstrap, upgrades, health, kubeconfig
envs/
  lab/               cluster "lab": VMs on chibang. Own state + passphrase.
  prod/              (later) S500 + VPS. Own state + passphrase.
```

Each env is an independent OpenTofu root: its own `terraform.tfvars`, Talos
patches, encrypted state and Talos secrets, so changes in `lab` can't touch
`prod`. Promote a change by applying it in `lab` first, then the same in `prod`.

Nodes are one map per env. `platform = "libvirt"` creates a VM;
`platform = "metal"` (e.g. the S500) means "already booted from the ISO into
maintenance mode at this IP", so it gets the same Talos config, just no VM.

## Prerequisites

- OpenTofu ≥ 1.10 (state encryption is OpenTofu-only).
- SSH to the libvirt host through ssh-agent; the provider uses the system `ssh`
  (`qemu+sshcmd://`). Not `qemu+ssh://`: SELinux on Fedora blocks sshd from
  forwarding libvirt's socket.
- libvirt host: polkit lets `core` manage system libvirt (chibang image ships the rule).
- Router: a DHCP reservation per VM `mac` → `ip` from the env's `terraform.tfvars`.
- State passphrase in pass, one per env (lab: `homelab/talos/state-passphrase`).

## Use

```sh
cd envs/lab
export TF_VAR_state_passphrase="$(pass homelab/talos/state-passphrase)"
tofu init
tofu plan -out tfplan
tofu apply tfplan    # finishes only when Kubernetes is healthy
```

Credentials go into your home configs, never into this repo (~/Documents syncs
to MEGA, and these are cluster-admin keys):

```sh
tofu output -raw talosconfig > /tmp/talosconfig
talosctl config merge /tmp/talosconfig && rm /tmp/talosconfig   # context "lab"
talosctl -n 192.168.68.161 kubeconfig                            # merges admin@lab
talosctl -n 192.168.68.161 dashboard
kubectl get nodes
```

## Day 2

- **Upgrade Talos:** bump `talos_version`, `tofu apply`. `talos_machine` upgrades each node in place.
- **Upgrade Kubernetes:** bump `kubernetes_version`, `tofu apply`. `talos_cluster` runs `upgrade-k8s`.
- **Add extensions:** edit `extensions` (new schematic → new installer image → nodes upgrade onto it).
- **Add a node:** add an entry to `nodes` (+ DHCP reservation), `tofu apply`.
- **Workloads on a control plane:** `allow_workloads` per node (default true; false keeps the NoSchedule taint).
- **Drift:** `tofu plan` shows config drift on nodes (`talos_machine` compares what's applied).

## State

Each environment has its own `envs/<env>/terraform.tfstate`: local, encrypted (AES-GCM, key from the pass passphrase),
and gitignored. It holds the cluster CA: losing it means losing admin access to
the cluster, so it must be backed up (this repo is in ~/Documents, which
restic backs up). Losing the passphrase makes the state unreadable: it lives in
pass, which has its own USB + git backups.

## Gotchas

- Config uses Talos 1.14 multi-document format (`UnattendedInstallConfig`,
  `HostnameConfig`, `KubeNodeConfig`…), not the old `machine.install` fields.
  Patches in `envs/<env>/patches/` must target those documents.
- `cluster_endpoint` defaults to the first control plane's IP. Set a VIP or DNS
  name **before** adding more control planes (see ROADMAP.md).
- VM disks live in the `talos` pool at `/var/lib/libvirt/talos` (chibang's SSD).
  Never point it at hdd_pool.
- `secure_boot = true` (default): SecureBoot ISO + installer, OVMF with Secure
  Boot on and no keys (setup mode). On a VM's first boot the ISO enrolls the
  Image Factory keys; if the boot menu waits on "Enroll Secure Boot keys",
  pick it once in the Cockpit console. Never let libvirt pick its default
  Microsoft-keys firmware: it rejects Talos images. Toggling it = reinstall.
- The ISO stays attached; boot order is disk first, so it only matters on a
  fresh (empty) disk.
