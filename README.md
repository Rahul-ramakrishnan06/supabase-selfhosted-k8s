# Self-hosted Supabase on local/DC Kubernetes

Local mirror (kind) of a datacenter deploy. Same stack runs in the DC — swap
one module. ArgoCD (GitOps) + OpenBao (secrets) + External Secrets Operator +
Supabase (Helm).

## Stack

| Layer | Tool | Installed by |
|-------|------|--------------|
| Cluster | kind (local) / k3s (DC) | Terraform, phase 1 |
| Secrets store | OpenBao | Terraform helm, phase 2 |
| Secret sync | External Secrets Operator | Terraform helm, phase 2 |
| GitOps | ArgoCD | Terraform helm, phase 2 |
| App platform | Supabase | ArgoCD Application (Helm) |

## Why two Terraform phases

`kubernetes`/`helm` providers need a kubeconfig that does not exist until the
cluster is created. One apply configures them at plan time → cluster-not-found.
So: **phase 1** builds the cluster, **phase 2** installs in-cluster resources
against the kubeconfig phase 1 wrote.

```
infra/
  01-cluster/    kind cluster            (DC: swap modules/kind-cluster -> k3s)
  02-platform/   openbao + eso + argocd
gitops/
  bootstrap/         root app-of-apps (sync this one -> manages the rest)
  apps/              child ArgoCD Applications (supabase, chat, platform-secrets)
  external-secrets/  ClusterSecretStore + ExternalSecret
  values/            supabase custom values (no secrets inside)
  k8s/chat/          chat app k8s manifests + DB migration Job
  chat/              chat app source (node/express + supabase-js, Dockerfile)
scripts/
  gen-supabase-secrets.sh   JWT secret + anon/service JWTs (signed, not random)
  seed-openbao.sh           push secrets into OpenBao + ESO token
```

## Run order

```bash
# 1. cluster
cd infra/01-cluster
terraform init && terraform apply
# note output kube_context (default: kind-supabase)

# 2. platform (openbao, eso, argocd)
cd ../02-platform
terraform init && terraform apply

# 3. generate + seed secrets
cd ../../scripts
./gen-supabase-secrets.sh              # writes supabase-secrets.env (git-ignored)
./seed-openbao.sh supabase-secrets.env # pushes to OpenBao, makes ESO token

# 4. supabase + ESO wiring via ArgoCD (these pull public chart / this repo's
#    committed manifests, so they work without pushing local edits).
kubectl apply -f ../gitops/apps/platform-secrets-app.yml
kubectl apply -f ../gitops/apps/supabase-app.yml
kubectl get applications -n argocd        # want Synced/Healthy
kubectl get externalsecret -n supabase    # want SecretSynced
```

> The chat app is NOT deployed through ArgoCD locally: ArgoCD pulls from the
> GitHub remote, and the local kind cluster has no image registry (images are
> hand-loaded into the nodes). So deploy the chat app directly with `kubectl`
> (below). The `gitops/apps/chat-app.yml` Application is kept for GitOps
> fidelity — use it once these files live on a remote you control.

### Chat app: build image, migrate DB, deploy

```bash
# a. build image and load it into the kind nodes (no registry)
cd gitops/chat
docker build --provenance=false -t chat-app:local .
docker save chat-app:local -o /tmp/chat-app.tar
for n in supabase-worker supabase-control-plane; do
  docker cp /tmp/chat-app.tar $n:/chat-app.tar
  docker exec $n ctr -n k8s.io images import /chat-app.tar
done

# b. create the messages table + RLS + realtime publication (idempotent Job)
kubectl apply -f ../k8s/chat/migration-job.yml
kubectl -n supabase wait --for=condition=complete job/chat-migration --timeout=180s

# c. deploy the app (namespace, ESO secret, deployment, service)
kubectl apply -f ../k8s/chat/namespace.yml
kubectl apply -f ../k8s/chat/external-secret.yml
kubectl -n chat wait --for=condition=Ready externalsecret/chat-supabase --timeout=120s
kubectl apply -f ../k8s/chat/deployment.yml
kubectl -n chat rollout status deploy/chat

# d. open it
kubectl -n chat port-forward svc/chat 8088:80   # -> http://127.0.0.1:8088
```

Sign up with any email/password (local Supabase has email confirmation off),
then chat — messages persist in Postgres and stream live over Supabase Realtime.

## Verify per layer (don't big-bang)

- ArgoCD UI: `kubectl -n argocd port-forward svc/argocd-server 8080:80`
  password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`
- OpenBao: `kubectl -n openbao port-forward svc/openbao 8200:8200` → http://127.0.0.1:8200 (token `root`)
- Supabase Studio: `kubectl -n supabase port-forward svc/supabase-studio 3000:3000`
- Kong (app entry): `http://supabase-kong.supabase.svc.cluster.local:8000` in-cluster

## Secret flow (single source of truth)

`gen script` signs JWTs → `seed` → **OpenBao** `secret/supabase` → **ESO**
`ClusterSecretStore` → k8s Secret `supabase-secrets` → chart `secretRef`.
Chart does NOT self-generate → Postgres and services share one password.

anon/service keys are HS256 JWTs signed by the JWT secret (role/iss claims).
Random values would make every Supabase service reject auth.

## LOCAL vs DC differences (do not carry local defaults to prod)

- **OpenBao dev mode** = in-memory, auto-unseal, root token. Data lost on
  restart. DC: `openbao_dev_mode=false`, real storage (raft/PVC) + unseal
  (manual or KMS/transit auto-unseal), scoped auth (kubernetes/approle) not root.
- **Cluster**: kind here. DC: replace `01-cluster/modules/kind-cluster` with a
  k3s module; keep `kube_context` in `02-platform/terraform.tfvars` in sync.
- **Exposure**: kind uses port-forward/NodePort (no cloud LB). DC/k3s has klipper
  LB built in — front Kong with ingress and set `kong.ingress.enabled=true`.
- **Postgres**: bundled chart PG here. DC-prod: consider external HA Postgres
  (`db.enabled=false` + `secret.db.host/port`).
```
