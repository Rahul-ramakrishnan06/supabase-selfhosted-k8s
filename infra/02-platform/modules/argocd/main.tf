terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
    helm       = { source = "hashicorp/helm" }
  }
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  create_namespace = false

  # ClusterIP + insecure: reach the UI with `kubectl port-forward`.
  values = [
    yamlencode({
      server = {
        service = { type = "ClusterIP" }
      }
      configs = {
        params = { "server.insecure" = true }
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.argocd]
}
