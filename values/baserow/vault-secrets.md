# Baserow Vault Secrets

This document lists the Vault secrets required by the current Baserow manifests.

## Required Vault secret paths

- `homelab/baserow/postgresql` (KV v2)
- `homelab/baserow/smtp` (KV v2)
- `homelab/baserow/minio` (KV v2)

Required properties at `homelab/baserow/postgresql`:
- `username`
- `password`

Required properties at `homelab/baserow/smtp`:
- `username` (iCloud email address)
- `password` (iCloud app-specific password)

Required properties at `homelab/baserow/minio`:
- `username` (existing MinIO root/access-key identity)
- `password` (existing MinIO root password/secret access key)

## Kubernetes mapping

The ExternalSecret at `apps/external-secrets-config/baserow-db-externalsecret.yaml` maps Vault values to Kubernetes Secret `baserow-db`:

- Vault `username` -> Secret key `DATABASE_USER`
- Vault `password` -> Secret key `DATABASE_PASSWORD`

The ExternalSecret at `apps/external-secrets-config/baserow-smtp-externalsecret.yaml` maps Vault values to Kubernetes Secret `baserow-smtp`:

- Vault `username` -> `EMAIL_SMTP_USER` and `FROM_EMAIL`
- Vault `password` -> `EMAIL_SMTP_PASSWORD`

The ExternalSecret at `apps/external-secrets-config/baserow-minio-externalsecret.yaml`
maps the same Vault properties into Kubernetes Secret `baserow-minio-vault`:

- Vault `username` -> `root-user` and `AWS_ACCESS_KEY_ID`
- Vault `password` -> `root-password` and `AWS_SECRET_ACCESS_KEY`

MinIO consumes the `root-*` keys through `minio.auth.existingSecret`. Baserow consumes
the AWS keys through the last entry in `global.baserow.envFrom`, overriding the parent
chart's generated storage credentials. Chart 1.0.52 still renders AWS keys in
`backend-secret` even when MinIO uses an existing Secret; configuring only
`minio.auth.existingSecret` does not fix backend authentication.

The dedicated name `baserow-minio-vault` avoids competing with the existing
Helm-managed `baserow-minio` Secret. Unlike the earlier proposed name, it is owned
only by External Secrets.

### Initial object-storage rollout

1. Populate Vault with the current working MinIO credentials. If different credentials
   were entered, treat rollout as a credential rotation and review it before syncing.
2. Sync `external-secrets-config` first and wait for ExternalSecret
   `baserow-minio-vault` to report Ready and its target Secret to exist.
3. Sync the Baserow application. Verify MinIO and every backend/worker deployment
   uses the Vault-backed Secret. Do not remove PVCs, recreate buckets or run a
   database provisioner for this object-storage change.
4. Verify authentication and reconcile the failed attachment upload before retrying it.

External Secrets refreshes do not restart containers using environment variables.
Future credential changes require a coordinated MinIO and Baserow backend/worker
rollout after the Secret is synchronized; a Secret refresh alone is insufficient.
Application sync waves do not guarantee readiness across these separate Argo CD
applications, so explicitly verify Secret readiness before syncing Baserow.

The Baserow chart consumes the database, SMTP and storage Secrets via
`global.baserow.envFrom` in `values/baserow/values.yaml`.

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
