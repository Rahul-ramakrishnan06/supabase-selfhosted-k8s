#!/usr/bin/env bash
# Generate the Supabase secret set.
#
# anon and service_role keys are NOT random strings -- they are HS256 JWTs
# signed by the JWT secret, carrying role/iss claims. Random values here make
# every Supabase service reject auth. This script signs them correctly.
#
# Output: writes ./supabase-secrets.env (git-ignored). Feed to seed-openbao.sh.
set -euo pipefail

OUT="${1:-supabase-secrets.env}"

b64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

sign_jwt() {
  # $1 = role, $2 = jwt secret
  local role="$1" secret="$2"
  local iat exp header payload signing_input sig
  iat=$(date +%s)
  exp=$((iat + 60 * 60 * 24 * 3650)) # 10 years
  header=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
  payload=$(printf '{"role":"%s","iss":"supabase","iat":%s,"exp":%s}' "$role" "$iat" "$exp" | b64url)
  signing_input="${header}.${payload}"
  sig=$(printf '%s' "$signing_input" \
    | openssl dgst -sha256 -hmac "$secret" -binary | b64url)
  printf '%s.%s' "$signing_input" "$sig"
}

JWT_SECRET=$(openssl rand -hex 32)                 # >= 32 chars, chart requires
DB_PASSWORD=$(openssl rand -hex 24)
ANON_KEY=$(sign_jwt "anon" "$JWT_SECRET")
SERVICE_KEY=$(sign_jwt "service_role" "$JWT_SECRET")
DASHBOARD_PASSWORD=$(openssl rand -hex 16)

cat > "$OUT" <<EOF
JWT_SECRET=$JWT_SECRET
ANON_KEY=$ANON_KEY
SERVICE_KEY=$SERVICE_KEY
DB_PASSWORD=$DB_PASSWORD
DB_DATABASE=postgres
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD
OPENAI_API_KEY=sk-placeholder-not-used
EOF

echo "Wrote $OUT"
echo "anon key: ${ANON_KEY:0:24}..."
echo "Next: ./seed-openbao.sh $OUT"
