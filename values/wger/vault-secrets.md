# Wger Vault Secrets

This document lists the Vault secrets required by the current Wger manifests.

## Required Vault secret path

- Path: `homelab/wger/postgresql`
- Engine: KV v2

Required properties at this path:
- `username`
- `password`
- `database`

## Kubernetes mapping

The ExternalSecret at `apps/external-secrets-config/wger-db-externalsecret.yaml` maps Vault values to Kubernetes Secret `wger-db`:

- Vault `username` -> Secret key `USERDB_USER`
- Vault `password` -> Secret key `USERDB_PASSWORD`
- Vault `database` -> Secret key `USERDB_NAME`

The Wger chart consumes this secret through `app.django.existingDatabase.existingSecret` in `values/wger/values.yaml`.

## Notes

- The chart-managed PostgreSQL dependency is disabled for this deployment.
- The chart-managed Redis dependency remains enabled because celery and PowerSync expect it.
- The shared PostgreSQL cluster should keep `wal_level=logical` enabled for Wger's PowerSync components.

## Provisioning helper

Use `scripts/onboard-wger-postgres-from-vault.sh` for the Wger-specific workflow, or `scripts/onboard-app-postgres-from-vault.sh` for the generic version. Both workflows write Vault data, sync the ExternalSecret, provision the PostgreSQL role/database/grants, and then sync the app.

These scripts do not create Wger tables directly. Table creation happens later when the Wger containers run their own migrations/startup jobs against the provisioned database.

Example:

```bash
./scripts/onboard-wger-postgres-from-vault.sh
```

Non-interactive generic example:

```bash
APP_NAME=wger \
APP_NAMESPACE=wger \
APP_DB=wger \
APP_SECRET=wger-db \
APP_USER_KEY=USERDB_USER \
APP_PASSWORD_KEY=USERDB_PASSWORD \
APP_DB_KEY=USERDB_NAME \
VAULT_PATH=homelab/wger/postgresql \
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