# Mailu Vault Secrets

This document lists the Vault secrets required by the current Mailu manifests.

## Required Vault secret path

- Path: `homelab/mailu/postgresql`
- Engine: KV v2

Required properties at this path:
- `username`
- `password`
- `database`

## Kubernetes mapping

The ExternalSecret at `apps/external-secrets-config/mailu-db-externalsecret.yaml` maps Vault values to Kubernetes Secret `mailu-db` in the `mailu` namespace:

- Vault `username` -> Secret key `username`
- Vault `password` -> Secret key `password`
- Vault `database` -> Secret key `database`

The Mailu chart consumes this secret through `externalDatabase.*` and `global.database.roundcube.*` in `values/mailu/values.yaml`.

## Provisioning helper

Use `scripts/onboard-app-postgres-from-vault.sh` to write Vault data, sync External Secrets, provision PostgreSQL role/database/grants on the shared PostgreSQL instance, and sync the app.

Example:

```bash
APP_NAME=mailu \
APP_NAMESPACE=mailu \
APP_DB=mailu \
APP_SECRET=mailu-db \
APP_USER_KEY=username \
APP_PASSWORD_KEY=password \
APP_DB_KEY=database \
VAULT_PATH=homelab/mailu/postgresql \
VAULT_USER_FIELD=username \
VAULT_PASSWORD_FIELD=password \
VAULT_DB_FIELD=database \
EXTERNAL_SECRETS_APP=external-secrets-config \
ROOT_APP=root \
PG_NAMESPACE=postgresql \
PG_HOST=postgresql-rw.postgresql.svc.cluster.local \
APP_SYNC_TIMEOUT=300 \
./scripts/onboard-app-postgres-from-vault.sh
```
