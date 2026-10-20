# Baserow Vault Secrets

This document lists the Vault secrets required by the current Baserow manifests.

## Required Vault secret paths

- `homelab/baserow/postgresql` (KV v2)
- `homelab/baserow/smtp` (KV v2)

Required properties at `homelab/baserow/postgresql`:
- `username`
- `password`

Required properties at `homelab/baserow/smtp`:
- `username` (iCloud email address)
- `password` (iCloud app-specific password)

## Kubernetes mapping

The ExternalSecret at `apps/external-secrets-config/baserow-db-externalsecret.yaml` maps Vault values to Kubernetes Secret `baserow-db`:

- Vault `username` -> Secret key `DATABASE_USER`
- Vault `password` -> Secret key `DATABASE_PASSWORD`

The ExternalSecret at `apps/external-secrets-config/baserow-smtp-externalsecret.yaml` maps Vault values to Kubernetes Secret `baserow-smtp`:

- Vault `username` -> `EMAIL_SMTP_USER` and `FROM_EMAIL`
- Vault `password` -> `EMAIL_SMTP_PASSWORD`

The Baserow chart consumes both Kubernetes Secrets via `global.baserow.envFrom` in `values/baserow/values.yaml`.

## Notes

- iCloud SMTP uses `smtp.mail.me.com` on port `587` with STARTTLS; these non-secret settings are set in `backendConfigMap` in `values/baserow/values.yaml`.
- PostgreSQL host/port/database name are non-secret and set in the same `backendConfigMap`.
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
