variable "cluster_name" {
  description = "Local Kubernetes cluster name"
  type        = string
  default     = "supabase"
}

variable "kubernetes_version" {
  description = "kind node image k8s version"
  type        = string
  default     = "v1.30.0"
}
