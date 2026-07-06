variable "chart_version" {
  description = "openbao helm chart version"
  type        = string
}

variable "dev_mode" {
  description = "Dev mode: in-memory, auto-unseal, root token. LOCAL ONLY."
  type        = bool
  default     = true
}
