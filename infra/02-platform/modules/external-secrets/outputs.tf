output "namespace" {
  value = kubernetes_namespace_v1.eso.metadata[0].name
}
