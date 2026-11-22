# Roadmap (k8s-infra)

## Now
- [x] First `tofu apply`: one control plane VM (talos-cp1) on chibang (2026-11-22).
- [ ] Reinstall talos-cp1 with SecureBoot (`secure_boot = true`).

## Next
- [ ] Stable API endpoint (Talos VIP on the LAN, or a DNS name) before adding control planes.
- [ ] 3 control planes (HA etcd); choose per node which also run workloads (`allow_workloads`). chibang is 4c/4t: watch CPU.
- [ ] With 3+ nodes: turn `drain_on_upgrade` back on (needs `kubeconfig_wo` from a separate step to avoid the cycle with `talos_cluster_kubeconfig`).
- [ ] Bootstrap Argo CD as the last tofu step; Argo owns everything in the `k8s-gitops` repo from there (app of apps). Tofu stops at "cluster + Argo".
- [ ] Nightly drift check in CI: `tofu plan -detailed-exitcode` over Tailscale, alert on exit 2.
- [ ] `envs/prod`: S500 (`platform = "metal"`) + VPS, own state and passphrase.
- [ ] vTPM (swtpm on chibang) + TPM-sealed disk encryption for STATE/EPHEMERAL (builds on SecureBoot).

## Later
- [ ] Remote state backend (S3-compatible, e.g. B2) once more than one machine runs tofu.
- [ ] VPS control plane via KubeSpan (don't stretch etcd quorum over the WAN).
