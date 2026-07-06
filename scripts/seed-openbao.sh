#!/usr/bin/env bash
# Push the generated secrets into OpenBao at kv path secret/supabase.
# Run after `terraform apply` in 02-platform (OpenBao must be up).
#
# Assumes dev mode (root token). For DC, use a real auth method + policy.
set -euo pipefail

ENV_FILE="${1:-supabase-secrets.env}"
NAMESPACE="${OPENBAO_NAMESPACE:-openbao}"
TOKEN="${OPENBAO_TOKEN:-root}"

[ -f "$ENV_FILE" ] || { echo "missing $ENV_FILE -- run gen-supabase-secrets.sh first"; exit 1; }
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

echo "port-forwarding OpenBao..."
kubectl -n "$NAMESPACE" port-forward svc/openbao 8200:8200 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 4

export BAO_ADDR="http://127.0.0.1:8200"
export BAO_TOKEN="$TOKEN"

# enable kv v2 at secret/ (ignore if already enabled)
bao secrets enable -path=secret kv-v2 2>/dev/null || true

bao kv put secret/supabase \
  jwtSecret="$JWT_SECRET" \
  anonKey="$ANON_KEY" \
  serviceKey="$SERVICE_KEY" \
  dbPassword="$DB_PASSWORD" \
  dbDatabase="$DB_DATABASE" \
  dashboardUsername="$DASHBOARD_USERNAME" \
  dashboardPassword="$DASHBOARD_PASSWORD" \
  openAiApiKey="${OPENAI_API_KEY:-sk-placeholder-not-used}"

echo "seeded secret/supabase"

# ESO ClusterSecretStore authenticates to OpenBao with this token secret.
kubectl create namespace supabase --dry-run=client -o yaml | kubectl apply -f -
kubectl -n supabase create secret generic openbao-token \
  --from-literal=token="$TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "created supabase/openbao-token for ESO"
