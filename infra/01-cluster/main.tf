# Phase 1: create the local cluster only.
# Kept in its own apply so the kubernetes/helm providers in 02-platform
# configure against a kubeconfig that already exists (avoids the
# cluster-not-found-at-plan-time bootstrap deadlock).
#
# DC swap: replace this module call with a "k3s-cluster" module. Nothing
# downstream changes as long as the kube context name stays "kind-<name>"
# or you update platform.tfvars kube_context accordingly.

module "cluster" {
  source = "./modules/kind-cluster"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
}
