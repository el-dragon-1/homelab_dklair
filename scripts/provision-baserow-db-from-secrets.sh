#!/usr/bin/env bash
set -euo pipefail

# Provisions the Baserow role/database in the shared PostgreSQL cluster
# using credentials synced from Vault into Kubernetes Secrets.
#
# Defaults target this repo's conventions:
# - Admin creds: secret postgresql-admin in namespace postgresql
# - App creds:   secret baserow-db in namespace baserow
# - DB service:  postgresql-rw.postgresql.svc.cluster.local:5432

PG_NAMESPACE="${PG_NAMESPACE:-postgresql}"
PG_ADMIN_SECRET="${PG_ADMIN_SECRET:-}"
PG_HOST="${PG_HOST:-postgresql-rw.postgresql.svc.cluster.local}"
PG_PORT="${PG_PORT:-5432}"
PG_ADMIN_DB="${PG_ADMIN_DB:-postgres}"

APP_NAMESPACE="${APP_NAMESPACE:-baserow}"
APP_SECRET="${APP_SECRET:-baserow-db}"
APP_DB="${APP_DB:-baserow}"
APP_USER_KEY="${APP_USER_KEY:-DATABASE_USER}"
APP_PASSWORD_KEY="${APP_PASSWORD_KEY:-DATABASE_PASSWORD}"

pass() {
  echo "[PASS] $1"
}

info() {
  echo "[INFO] $1"
}

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

secret_exists() {
  local ns="$1"
  local name="$2"
  kubectl get secret -n "$ns" "$name" >/dev/null 2>&1
}

read_secret_key() {
  local ns="$1"
  local name="$2"
  local key="$3"

  kubectl get secret -n "$ns" "$name" -o "jsonpath={.data.${key}}" 2>/dev/null | base64 --decode
}

need_cmd kubectl
need_cmd base64

if [[ -z "${KUBECONFIG:-}" && -f "$HOME/kube/k3s.yaml" ]]; then
  export KUBECONFIG="$HOME/kube/k3s.yaml"
fi

if [[ -z "$PG_ADMIN_SECRET" ]]; then
  if secret_exists "$PG_NAMESPACE" "postgresql-superuser"; then
    PG_ADMIN_SECRET="postgresql-superuser"
  else
    PG_ADMIN_SECRET="postgresql-admin"
  fi
fi

info "Reading PostgreSQL admin credentials from secret ${PG_NAMESPACE}/${PG_ADMIN_SECRET}"
PG_ADMIN_USER="$(read_secret_key "$PG_NAMESPACE" "$PG_ADMIN_SECRET" username || true)"
PG_ADMIN_PASSWORD="$(read_secret_key "$PG_NAMESPACE" "$PG_ADMIN_SECRET" password || true)"

[[ -n "$PG_ADMIN_USER" ]] || fail "Could not read username from secret ${PG_NAMESPACE}/${PG_ADMIN_SECRET}"
[[ -n "$PG_ADMIN_PASSWORD" ]] || fail "Could not read password from secret ${PG_NAMESPACE}/${PG_ADMIN_SECRET}"
pass "Loaded PostgreSQL admin credentials"

info "Reading Baserow DB credentials from secret ${APP_NAMESPACE}/${APP_SECRET}"
APP_USER="$(read_secret_key "$APP_NAMESPACE" "$APP_SECRET" "$APP_USER_KEY" || true)"
APP_PASSWORD="$(read_secret_key "$APP_NAMESPACE" "$APP_SECRET" "$APP_PASSWORD_KEY" || true)"

[[ -n "$APP_USER" ]] || fail "Could not read ${APP_USER_KEY} from secret ${APP_NAMESPACE}/${APP_SECRET}"
[[ -n "$APP_PASSWORD" ]] || fail "Could not read ${APP_PASSWORD_KEY} from secret ${APP_NAMESPACE}/${APP_SECRET}"
pass "Loaded Baserow app credentials"

# Use a temporary psql client pod in the postgresql namespace.
TOOL_POD="pg-client-$(date +%s)"
cleanup() {
  kubectl delete pod -n "$PG_NAMESPACE" "$TOOL_POD" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

info "Starting temporary psql client pod ${TOOL_POD}"
kubectl run "$TOOL_POD" \
  -n "$PG_NAMESPACE" \
  --image=postgres:16 \
  --restart=Never \
  --command -- sleep 1800 >/dev/null
kubectl wait -n "$PG_NAMESPACE" --for=condition=Ready "pod/${TOOL_POD}" --timeout=90s >/dev/null
pass "Temporary psql client is ready"

info "Ensuring role and database exist with expected ownership"
kubectl exec -i -n "$PG_NAMESPACE" "$TOOL_POD" -- env \
  PGPASSWORD="$PG_ADMIN_PASSWORD" \
  psql \
  -h "$PG_HOST" \
  -p "$PG_PORT" \
  -U "$PG_ADMIN_USER" \
  -d "$PG_ADMIN_DB" \
  -v ON_ERROR_STOP=1 \
  -v app_user="$APP_USER" \
  -v app_password="$APP_PASSWORD" \
  -v app_db="$APP_DB" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_user', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user')
\gexec

SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'app_user', :'app_password')
\gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'app_db', :'app_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'app_db')
\gexec

SELECT format('ALTER DATABASE %I OWNER TO %I', :'app_db', :'app_user')
\gexec

SELECT format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', :'app_db', :'app_user')
\gexec
SQL
pass "Role/database provisioning completed"

info "Granting schema/table/sequence privileges in ${APP_DB}"
kubectl exec -i -n "$PG_NAMESPACE" "$TOOL_POD" -- env \
  PGPASSWORD="$PG_ADMIN_PASSWORD" \
  psql \
  -h "$PG_HOST" \
  -p "$PG_PORT" \
  -U "$PG_ADMIN_USER" \
  -d "$APP_DB" \
  -v ON_ERROR_STOP=1 \
  -v app_user="$APP_USER" <<'SQL'
SELECT format('ALTER SCHEMA public OWNER TO %I', :'app_user')
\gexec

SELECT format('GRANT ALL ON SCHEMA public TO %I', :'app_user')
\gexec

SELECT format('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO %I', :'app_user')
\gexec

SELECT format('GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO %I', :'app_user')
\gexec
SQL
pass "Schema-level grants applied"

info "Verifying login with Baserow application credentials"
kubectl exec -i -n "$PG_NAMESPACE" "$TOOL_POD" -- env \
  PGPASSWORD="$APP_PASSWORD" \
  psql \
  -h "$PG_HOST" \
  -p "$PG_PORT" \
  -U "$APP_USER" \
  -d "$APP_DB" \
  -v ON_ERROR_STOP=1 \
  -c "SELECT current_user, current_database();" >/dev/null
pass "Baserow credentials can log in to ${APP_DB}"

echo ""
echo "Provisioning completed successfully."
echo "Next: trigger a Baserow resync/restart so migration job retries with valid credentials."
