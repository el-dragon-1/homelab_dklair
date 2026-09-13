# Aliasvault Vault Secrets

This document lists the Vault secrets required by the current Aliasvault manifests.

## Required Vault secret path

- Path: `homelab/aliasvault/postgresql`
- Engine: KV v2

Required properties at this path:
- `username`
- `password`
- `database`

## Kubernetes mapping

The ExternalSecret at `apps/external-secrets-config/aliasvault-db-externalsecret.yaml` maps Vault values to Kubernetes Secret `aliasvault-db` in the `aliasvault` namespace:

- Vault `password` -> Secret key `postgres_password` (mounted inside container at `/secrets/postgres_password`)
- Vault `username` -> Secret key `POSTGRES_USER`
- Vault `password` -> Secret key `POSTGRES_PASSWORD`
- Vault `database` -> Secret key `POSTGRES_DB`

## Provisioning helper

Use `scripts/onboard-app-postgres-from-vault.sh` to write the Vault data, sync the ExternalSecret, provision the PostgreSQL role/database/grants on the shared PostgreSQL instance, and sync the app.

Example:

```bash
APP_NAME=aliasvault \
APP_NAMESPACE=aliasvault \
APP_DB=aliasvault \
APP_USER=aliasvault \
APP_SECRET=aliasvault-db \
APP_USER_KEY=POSTGRES_USER \
APP_PASSWORD_KEY=POSTGRES_PASSWORD \
APP_DB_KEY=POSTGRES_DB \
./scripts/onboard-app-postgres-from-vault.sh
```
