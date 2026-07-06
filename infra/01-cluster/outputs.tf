output "cluster_name" {
  description = "Cluster name"
  value       = module.cluster.cluster_name
}

output "kube_context" {
  description = "kubeconfig context to feed into 02-platform"
  value       = module.cluster.kube_context
}

output "endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.cluster.endpoint
}
