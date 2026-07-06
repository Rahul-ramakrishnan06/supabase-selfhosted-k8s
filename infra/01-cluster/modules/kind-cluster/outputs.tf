output "cluster_name" {
  value = kind_cluster.this.name
}

# kind writes context as "kind-<name>" into the default kubeconfig.
output "kube_context" {
  value = "kind-${kind_cluster.this.name}"
}

output "endpoint" {
  value = kind_cluster.this.endpoint
}

output "kubeconfig_path" {
  value = kind_cluster.this.kubeconfig_path
}
