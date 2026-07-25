#!/usr/bin/env bash
set -euo pipefail

# Generic workflow helper for onboarding any app that uses the shared PostgreSQL
# cluster with credentials sourced from Vault via External Secrets.

pass() {
  echo "[PASS] $1"
}

info() {
  echo "[INFO] $1"
}

warn() {
  echo "[WARN] $1"
}

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

confirm() {
  local prompt="$1"
  local default_yes="${2:-yes}"
  local answer=""

  if [[ "$default_yes" == "yes" ]]; then
    read -r -p "$prompt [Y/n]: " answer
    [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]
  else
    read -r -p "$prompt [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
  fi
}

prompt_default() {
  local var_name="$1"
  local prompt="$2"
  local default_value="$3"
  local current_value="${!var_name:-}"
  local entered=""

  if [[ -n "$current_value" ]]; then
    return
  fi

  read -r -p "$prompt [$default_value]: " entered
  if [[ -z "$entered" ]]; then
    printf -v "$var_name" '%s' "$default_value"
  else
    printf -v "$var_name" '%s' "$entered"
  fi
}

prompt_secret() {
  local var_name="$1"
  local prompt="$2"
  local current_value="${!var_name:-}"
  local entered=""

  if [[ -n "$current_value" ]]; then
    return
  fi

  read -r -s -p "$prompt: " entered
  echo ""
  [[ -n "$entered" ]] || fail "$prompt is required"
  printf -v "$var_name" '%s' "$entered"
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

wait_for_secret() {
  local ns="$1"
  local name="$2"
  local timeout_seconds="$3"
  local elapsed=0

  info "Waiting for secret ${ns}/${name} (timeout: ${timeout_seconds}s)"
  while (( elapsed < timeout_seconds )); do
    if secret_exists "$ns" "$name"; then
      pass "Secret ${ns}/${name} is available"
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done

  return 1
}

sync_argocd_app() {
  local app_name="$1"
  local timeout_seconds="$2"

  info "Syncing Argo CD app ${app_name}"
  argocd app sync "$app_name" --grpc-web --insecure
  argocd app wait "$app_name" --grpc-web --insecure --sync --health --timeout "$timeout_seconds"
  pass "Argo CD app ${app_name} synced and healthy"
}

run_db_provisioning() {
  local tool_pod="pg-client-$(date +%s)"

  cleanup() {
    kubectl delete pod -n "$PG_NAMESPACE" "$tool_pod" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
  }
  trap cleanup EXIT

  info "Starting temporary psql client pod ${tool_pod}"
  kubectl run "$tool_pod" \
    -n "$PG_NAMESPACE" \
    --image=postgres:16 \
    --restart=Never \
    --command -- sleep 1800 >/dev/null
  kubectl wait -n "$PG_NAMESPACE" --for=condition=Ready "pod/${tool_pod}" --timeout=90s >/dev/null
  pass "Temporary psql client is ready"

  info "Ensuring role/database exist with expected ownership"
  kubectl exec -i -n "$PG_NAMESPACE" "$tool_pod" -- env \
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
  kubectl exec -i -n "$PG_NAMESPACE" "$tool_pod" -- env \
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

  info "Verifying login with app credentials"
  kubectl exec -i -n "$PG_NAMESPACE" "$tool_pod" -- env \
    PGPASSWORD="$APP_PASSWORD" \
    psql \
    -h "$PG_HOST" \
    -p "$PG_PORT" \
    -U "$APP_USER" \
    -d "$APP_DB" \
    -v ON_ERROR_STOP=1 \
    -c "SELECT current_user, current_database();" >/dev/null
  pass "App credentials can log in to ${APP_DB}"
}

# Defaults
PG_NAMESPACE="${PG_NAMESPACE:-postgresql}"
PG_ADMIN_SECRET="${PG_ADMIN_SECRET:-}"
PG_HOST="${PG_HOST:-postgresql-rw.postgresql.svc.cluster.local}"
PG_PORT="${PG_PORT:-5432}"
PG_ADMIN_DB="${PG_ADMIN_DB:-postgres}"

APP_NAME="${APP_NAME:-}"
APP_NAMESPACE="${APP_NAMESPACE:-}"
APP_SECRET="${APP_SECRET:-}"
APP_DB="${APP_DB:-}"
APP_USER_KEY="${APP_USER_KEY:-username}"
APP_PASSWORD_KEY="${APP_PASSWORD_KEY:-password}"

VAULT_PATH="${VAULT_PATH:-}"
VAULT_USER_FIELD="${VAULT_USER_FIELD:-username}"
VAULT_PASSWORD_FIELD="${VAULT_PASSWORD_FIELD:-password}"
VAULT_DB_FIELD="${VAULT_DB_FIELD:-database}"
VAULT_DB_USER="${VAULT_DB_USER:-}"
VAULT_DB_PASSWORD="${VAULT_DB_PASSWORD:-}"

EXTERNAL_SECRETS_APP="${EXTERNAL_SECRETS_APP:-external-secrets-config}"
ROOT_APP="${ROOT_APP:-root}"
APP_SYNC_TIMEOUT="${APP_SYNC_TIMEOUT:-300}"

need_cmd kubectl
need_cmd base64

if [[ -z "${KUBECONFIG:-}" && -f "$HOME/kube/k3s.yaml" ]]; then
  export KUBECONFIG="$HOME/kube/k3s.yaml"
fi

echo ""
echo "=== App PostgreSQL + Vault Onboarding Workflow ==="
echo ""

echo "Step 1/7: Capture app and chart-derived secret key requirements"
prompt_default APP_NAME "Application name" "my-app"
prompt_default APP_NAMESPACE "Application namespace" "$APP_NAME"
prompt_default APP_DB "PostgreSQL database name" "$APP_NAME"
prompt_default APP_SECRET "Kubernetes secret name created by External Secrets" "${APP_NAME}-db"
prompt_default APP_USER_KEY "Username key in Kubernetes secret" "$APP_USER_KEY"
prompt_default APP_PASSWORD_KEY "Password key in Kubernetes secret" "$APP_PASSWORD_KEY"

if [[ -z "$VAULT_PATH" ]]; then
  VAULT_PATH="homelab/${APP_NAME}/postgresql"
fi

info "Workflow target summary:"
echo "  - app: ${APP_NAME}"
echo "  - namespace: ${APP_NAMESPACE}"
echo "  - db: ${APP_DB}"
echo "  - k8s secret: ${APP_NAMESPACE}/${APP_SECRET}"
echo "  - secret keys: ${APP_USER_KEY}, ${APP_PASSWORD_KEY}"
echo "  - vault path: ${VAULT_PATH}"

echo ""
echo "Step 2/7: Write DB credentials to Vault"
if confirm "Write or update Vault credentials now?" "yes"; then
  need_cmd vault
  prompt_secret VAULT_DB_USER "Vault DB username"
  prompt_secret VAULT_DB_PASSWORD "Vault DB password"
  info "Writing credentials to Vault path ${VAULT_PATH}"
  vault kv put "$VAULT_PATH" \
    "$VAULT_USER_FIELD=$VAULT_DB_USER" \
    "$VAULT_PASSWORD_FIELD=$VAULT_DB_PASSWORD" \
    "$VAULT_DB_FIELD=$APP_DB" >/dev/null
  pass "Vault secret updated"
else
  warn "Skipped Vault write; continuing with existing Vault data"
fi

echo ""
echo "Step 3/7: Sync External Secrets"
if confirm "Sync Argo CD app ${EXTERNAL_SECRETS_APP}?" "yes"; then
  need_cmd argocd
  sync_argocd_app "$EXTERNAL_SECRETS_APP" "$APP_SYNC_TIMEOUT"
else
  warn "Skipped External Secrets sync"
fi

echo ""
echo "Step 4/7: Verify Kubernetes secret contains required keys"
if ! wait_for_secret "$APP_NAMESPACE" "$APP_SECRET" 180; then
  fail "Secret ${APP_NAMESPACE}/${APP_SECRET} not found. Check ExternalSecret mapping and Vault path."
fi

APP_USER="$(read_secret_key "$APP_NAMESPACE" "$APP_SECRET" "$APP_USER_KEY" || true)"
APP_PASSWORD="$(read_secret_key "$APP_NAMESPACE" "$APP_SECRET" "$APP_PASSWORD_KEY" || true)"
[[ -n "$APP_USER" ]] || fail "Could not read key ${APP_USER_KEY} from ${APP_NAMESPACE}/${APP_SECRET}"
[[ -n "$APP_PASSWORD" ]] || fail "Could not read key ${APP_PASSWORD_KEY} from ${APP_NAMESPACE}/${APP_SECRET}"
pass "App secret keys resolved"

echo ""
echo "Step 5/7: Provision PostgreSQL role/database/grants"
if [[ -z "$PG_ADMIN_SECRET" ]]; then
  if secret_exists "$PG_NAMESPACE" "postgresql-superuser"; then
    PG_ADMIN_SECRET="postgresql-superuser"
  else
    PG_ADMIN_SECRET="postgresql-admin"
  fi
fi

info "Reading PostgreSQL admin credentials from ${PG_NAMESPACE}/${PG_ADMIN_SECRET}"
PG_ADMIN_USER="$(read_secret_key "$PG_NAMESPACE" "$PG_ADMIN_SECRET" username || true)"
PG_ADMIN_PASSWORD="$(read_secret_key "$PG_NAMESPACE" "$PG_ADMIN_SECRET" password || true)"
[[ -n "$PG_ADMIN_USER" ]] || fail "Could not read username from ${PG_NAMESPACE}/${PG_ADMIN_SECRET}"
[[ -n "$PG_ADMIN_PASSWORD" ]] || fail "Could not read password from ${PG_NAMESPACE}/${PG_ADMIN_SECRET}"
pass "PostgreSQL admin credentials loaded"

run_db_provisioning

echo ""
echo "Step 6/7: Commit manifest + values + context changes"
if confirm "Create a git commit now?" "no"; then
  need_cmd git
  prompt_default APP_MANIFEST_FILE "App manifest file path" "apps/argocd/${APP_NAME}-application.yaml"
  prompt_default APP_VALUES_FILE "Values file path" "values/${APP_NAME}/values.yaml"
  prompt_default APP_CONTEXT_FILE "Context file path" "values/${APP_NAME}/context.md"

  git add "$APP_MANIFEST_FILE" "$APP_VALUES_FILE" "$APP_CONTEXT_FILE"

  if git diff --cached --quiet; then
    warn "No staged changes found in selected files"
  else
    prompt_default COMMIT_MESSAGE "Commit message" "feat(${APP_NAME}): add app manifest and postgres-backed values"
    git commit -m "$COMMIT_MESSAGE"
    pass "Commit created"

    if confirm "Push commit to origin now?" "yes"; then
      git push origin HEAD
      pass "Changes pushed"
    else
      warn "Skipped push; root sync will not include local-only commits"
    fi
  fi
else
  warn "Skipped git commit"
fi

echo ""
echo "Step 7/7: Sync root application"
if confirm "Sync Argo CD app ${ROOT_APP}?" "yes"; then
  need_cmd argocd
  sync_argocd_app "$ROOT_APP" "$APP_SYNC_TIMEOUT"
else
  warn "Skipped root app sync"
fi

echo ""
pass "Workflow completed"
echo "Next: verify ${APP_NAME} app sync/health and run any app-specific smoke tests."
