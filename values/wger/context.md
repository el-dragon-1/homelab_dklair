# Wger Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Wger. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/wger-application.yaml](../../apps/argocd/wger-application.yaml)
- ExternalSecret: [../../apps/external-secrets-config/wger-db-externalsecret.yaml](../../apps/external-secrets-config/wger-db-externalsecret.yaml)
- Companion doc: [vault-secrets.md](vault-secrets.md)

## Current Deployment Shape
- Deploys Wger from the upstream `wger` Helm chart at version `1.0.0`.
- Reuses the shared PostgreSQL cluster and disables the chart-managed PostgreSQL dependency.
- Keeps the chart-managed Redis dependency enabled because the chart expects it for celery and PowerSync.
- Exposes the app at `wger.dklair.io` through Traefik with cert-manager TLS.
- Uses Longhorn-backed persistence for media, static assets, celery beat state, and Redis.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- PowerSync is always rendered by this chart; if rollout symptoms point at PostgreSQL replication behavior, inspect the shared PostgreSQL parameters first.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- If Wger pods start but PowerSync fails, verify the shared PostgreSQL cluster still exposes `wal_level=logical`.
- Keep the DB secret keys aligned with the chart defaults: `USERDB_USER`, `USERDB_PASSWORD`, and `USERDB_NAME`.

## Dependencies And Secrets
- Review [vault-secrets.md](vault-secrets.md) for the Vault path and Secret mapping details.
- The shared PostgreSQL cluster serves the main app database, while the Wger chart still manages its own Redis dependency.

## Important Files
- [../../apps/argocd/wger-application.yaml](../../apps/argocd/wger-application.yaml)
- [../../apps/external-secrets-config/wger-db-externalsecret.yaml](../../apps/external-secrets-config/wger-db-externalsecret.yaml)
- [values.yaml](values.yaml)
- [../../values/postgresql/values.yaml](../../values/postgresql/values.yaml)
- [../../scripts/onboard-app-postgres-from-vault.sh](../../scripts/onboard-app-postgres-from-vault.sh)

## Open Questions
- Record whether future chart upgrades add an explicit PowerSync disable switch or change the secret contract for external databases.