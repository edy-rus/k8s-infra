# Installs Argo CD once and hands it the root application. From then on
# Argo CD manages everything, including its own upgrades, from the gitops repo.

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  wait             = true

  # Argo CD takes over this release (the argocd app in the gitops repo uses
  # the same release name), so tofu must not fight it on later applies.
  lifecycle {
    ignore_changes = all
  }
}

# The root application: points Argo CD at the cluster's folder in the gitops
# repo (app of apps). Changing the repo, path or revision here is the only
# reason to re-apply this.
resource "helm_release" "root" {
  depends_on = [helm_release.argocd]

  name       = "argocd-root"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.apps_chart_version

  values = [yamlencode({
    applications = {
      root = {
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = var.gitops_repo
          targetRevision = var.gitops_revision
          path           = var.gitops_path
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = { prune = true, selfHeal = true }
        }
      }
    }
  })]
}
