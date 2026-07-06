# Phase 2: in-cluster platform. Runs after phase 1 created the cluster.
# Layer order mirrors the verify-as-you-go plan: openbao + eso first so the
# secret plumbing exists, then argocd which will sync the Supabase app.

module "openbao" {
  source        = "./modules/openbao"
  chart_version = var.openbao_chart_version
  dev_mode      = var.openbao_dev_mode
}

module "external_secrets" {
  source        = "./modules/external-secrets"
  chart_version = var.eso_chart_version
}

module "argocd" {
  source        = "./modules/argocd"
  chart_version = var.argocd_chart_version
}
