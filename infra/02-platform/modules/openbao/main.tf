terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
    helm       = { source = "hashicorp/helm" }
  }
}

resource "kubernetes_namespace_v1" "openbao" {
  metadata {
    name = "openbao"
  }
}

# OpenBao (Vault fork) secret store.
#
# dev_mode = true  -> in-memory, auto-unseals, fixed root token "root".
#                     Data is LOST on pod restart. LOCAL DEMO ONLY.
# dev_mode = false -> DC path: enable a real storage backend (raft/file PVC)
#                     and an unseal method (manual or KMS/transit auto-unseal).
resource "helm_release" "openbao" {
  name       = "openbao"
  namespace  = kubernetes_namespace_v1.openbao.metadata[0].name
  repository = "https://openbao.github.io/openbao-helm"
  chart      = "openbao"
  version    = var.chart_version

  create_namespace = false

  values = [
    yamlencode({
      server = {
        dev = {
          enabled      = var.dev_mode
          devRootToken = "root"
        }
        # DC: flip standalone.enabled + a data PVC when dev_mode = false.
        standalone = { enabled = !var.dev_mode }
        ha         = { enabled = false }
      }
      injector = { enabled = false } # using External Secrets Operator instead
    })
  ]

  depends_on = [kubernetes_namespace_v1.openbao]
}
