variable "argocd_chart_version" {
  description = "argo-cd Helm chart version for the first install. Argo CD manages its own upgrades after that, from k8s-gitops."
  type        = string
}

variable "apps_chart_version" {
  description = "argocd-apps Helm chart version, used to create the root application."
  type        = string
}

variable "gitops_repo" {
  description = "Git repo Argo CD watches (k8s-gitops)."
  type        = string
}

variable "gitops_revision" {
  description = "Branch, tag or commit of the gitops repo to follow."
  type        = string
  default     = "main"
}

variable "gitops_path" {
  description = "Folder in the gitops repo with this cluster's applications, e.g. clusters/lab."
  type        = string
}
