output "argocd_namespace" {
  value = module.argocd.namespace
}

output "openbao_namespace" {
  value = module.openbao.namespace
}

output "openbao_service" {
  description = "In-cluster OpenBao address for the ESO ClusterSecretStore"
  value       = module.openbao.service_address
}

output "external_secrets_namespace" {
  value = module.external_secrets.namespace
}
