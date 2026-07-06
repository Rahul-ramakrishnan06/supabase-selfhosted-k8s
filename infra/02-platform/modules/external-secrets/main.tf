terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
    helm       = { source = "hashicorp/helm" }
  }
}

resource "kubernetes_namespace_v1" "eso" {
  metadata {
    name = "external-secrets"
  }
}

# External Secrets Operator: pulls secrets from OpenBao and materializes them
# as native Kubernetes Secrets that the Supabase chart consumes via secretRef.
resource "helm_release" "eso" {
  name       = "external-secrets"
  namespace  = kubernetes_namespace_v1.eso.metadata[0].name
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version

  create_namespace = false

  values = [
    yamlencode({
      installCRDs = true
    })
  ]

  depends_on = [kubernetes_namespace_v1.eso]
}
