variable "kubeconfig_path" {
  description = "Path to kubeconfig written by phase 1 (kind uses ~/.kube/config)"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context (output kube_context from 01-cluster)"
  type        = string
  default     = "kind-supabase"
}

variable "argocd_chart_version" {
  description = "argo-cd helm chart version"
  type        = string
  default     = "7.6.12"
}

variable "openbao_chart_version" {
  description = "openbao helm chart version"
  type        = string
  default     = "0.9.0"
}

variable "eso_chart_version" {
  description = "external-secrets helm chart version"
  type        = string
  default     = "0.10.4"
}

variable "openbao_dev_mode" {
  description = "Dev mode = in-memory, auto-unseal, root token. LOCAL ONLY. Set false for DC."
  type        = bool
  default     = true
}
