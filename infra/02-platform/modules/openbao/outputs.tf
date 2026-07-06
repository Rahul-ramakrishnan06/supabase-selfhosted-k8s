output "namespace" {
  value = kubernetes_namespace_v1.openbao.metadata[0].name
}

output "service_address" {
  description = "Cluster-internal OpenBao API for the ESO ClusterSecretStore"
  value       = "http://openbao.${kubernetes_namespace_v1.openbao.metadata[0].name}.svc.cluster.local:8200"
}
