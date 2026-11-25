#!/usr/bin/env bash
# Wipe a node back to a fresh install, keeping the cluster secrets (CA, tokens),
# so existing kubeconfig/talosconfig keep working.
#
# Replaces the VM (fresh NVRAM, so Secure Boot keys re-enroll from the ISO),
# its disk (empty -> boots the ISO into maintenance mode), the Talos machine
# config (re-applied to the blank node) and the cluster bootstrap (new etcd).
# A new etcd is an empty cluster, so the Argo CD releases are replaced too:
# without that, the plan still sees the old Argo CD and the reset leaves the
# cluster without it.
#
# Usage: ./reset.sh [node]        (default: talos-cp1)
# Review the plan: expect only these 6 replacements, never machine_secrets.
set -euo pipefail
cd "$(dirname "$0")"

node=${1:-talos-cp1}

if [[ -z ${TF_VAR_state_passphrase:-} ]]; then
  echo "TF_VAR_state_passphrase is not set (see README: Use)" >&2
  exit 1
fi

# talos_cluster.this is the etcd bootstrap: with several control planes it only
# needs replacing when the bootstrap node (or the whole cluster) is reset.
tofu apply \
  -replace="module.libvirt.libvirt_domain.node[\"$node\"]" \
  -replace="module.libvirt.libvirt_volume.disk[\"$node\"]" \
  -replace="module.cluster.talos_machine.node[\"$node\"]" \
  -replace='module.cluster.talos_cluster.this' \
  -replace='module.argocd.helm_release.argocd' \
  -replace='module.argocd.helm_release.root'
