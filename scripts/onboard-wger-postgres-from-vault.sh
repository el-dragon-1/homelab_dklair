#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper around the generic shared-PostgreSQL + Vault onboarding
# workflow for the Wger deployment in this repository.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export APP_NAME="${APP_NAME:-wger}"
export APP_NAMESPACE="${APP_NAMESPACE:-wger}"
export APP_DB="${APP_DB:-wger}"
export APP_SECRET="${APP_SECRET:-wger-db}"
export APP_USER_KEY="${APP_USER_KEY:-USERDB_USER}"
export APP_PASSWORD_KEY="${APP_PASSWORD_KEY:-USERDB_PASSWORD}"
export APP_DB_KEY="${APP_DB_KEY:-USERDB_NAME}"

export VAULT_PATH="${VAULT_PATH:-homelab/wger/postgresql}"
export VAULT_USER_FIELD="${VAULT_USER_FIELD:-username}"
export VAULT_PASSWORD_FIELD="${VAULT_PASSWORD_FIELD:-password}"
export VAULT_DB_FIELD="${VAULT_DB_FIELD:-database}"

export EXTERNAL_SECRETS_APP="${EXTERNAL_SECRETS_APP:-external-secrets-config}"
export ROOT_APP="${ROOT_APP:-root}"
export PG_NAMESPACE="${PG_NAMESPACE:-postgresql}"
export PG_HOST="${PG_HOST:-postgresql-rw.postgresql.svc.cluster.local}"
export APP_SYNC_TIMEOUT="${APP_SYNC_TIMEOUT:-300}"

exec "${SCRIPT_DIR}/onboard-app-postgres-from-vault.sh"