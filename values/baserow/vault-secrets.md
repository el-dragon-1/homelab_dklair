# Baserow Vault Secrets

This document lists the Vault secrets required by the current Baserow manifests.

## Required Vault secret path

- Path: `homelab/baserow/postgresql`
- Engine: KV v2 (same backend used by other app secrets)

Required properties at this path:
- `username`
- `password`

## Kubernetes mapping

The ExternalSecret at `apps/external-secrets-config/baserow-db-externalsecret.yaml` maps Vault values to Kubernetes Secret `baserow-db`:

- Vault `username` -> Secret key `DATABASE_USER`
- Vault `password` -> Secret key `DATABASE_PASSWORD`

The Baserow chart consumes this secret via `global.baserow.envFrom` in `values/baserow/values.yaml`.

## Notes

- No additional Vault secret paths are required for the current Baserow configuration.
- PostgreSQL host/port/database name are non-secret and set in `backendConfigMap` in `values/baserow/values.yaml`.
- TLS ingress is managed by `apps/baserow/ingress.yaml` as a workaround for a Baserow chart ingress TLS rendering issue.

## Provisioning helper

Use `scripts/provision-baserow-db-from-secrets.sh` to provision or repair the Baserow PostgreSQL role/database from Vault-synced Kubernetes secrets.

Run:

```bash
./scripts/provision-baserow-db-from-secrets.sh
```

The script auto-prefers `postgresql-superuser` (if present) and falls back to `postgresql-admin`.

To force a specific secret:

```bash
PG_ADMIN_SECRET=postgresql-superuser ./scripts/provision-baserow-db-from-secrets.sh
```
