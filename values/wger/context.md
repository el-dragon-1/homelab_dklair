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
- 2026-08-08: `argocd` app `wger` reached `Synced/Healthy` after DB bootstrap and Argo diff normalization.
- Validation used:
- `kubectl get pods -n wger` showed `wger-app`, `wger-celery`, `wger-celery-worker`, `wger-powersync`, `wger-nginx`, `wger-redis` all ready.
- `kubectl get application -n argocd wger -o jsonpath='{.status.sync.status}{" "}{.status.health.status}'` returned `Synced Healthy`.

## Recurring Problems
- PowerSync is always rendered by this chart; if rollout symptoms point at PostgreSQL replication behavior, inspect the shared PostgreSQL parameters first.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

- Date: 2026-08-08
- Issue: `wger-app` stayed unready with HTTP 500 readiness failures.
- Root cause: missing singleton `GymConfig` row (`GymConfig.DoesNotExist`).
- Fix: created the record with `GymConfig.objects.get_or_create(pk=1, defaults={"default_gym": None})` via `manage.py shell`.
- Validation: `wger-app` readiness turned `1/1` and the `/` probe stopped returning 500.

- Date: 2026-08-08
- Issue: `wger-powersync` crash looped with PostgreSQL auth failure for `powersync_storage`.
- Root cause: storage role/schema bootstrap was incomplete; `powersync_storage` role did not exist.
- Fix: created/updated `powersync_storage`, granted DB connect, created `powersync` schema, and set search path in the Wger database.
- Validation: `kubectl logs -n wger deploy/wger-powersync` showed active replication stream startup and pod became `1/1`.

- Date: 2026-08-08
- Issue: Argo app stayed `OutOfSync` while workloads were healthy.
- Root cause: upstream Wger chart templates use `randAlphaNum` for deployment `rollme` annotations, causing intentional render-time drift.
- Fix: added `spec.ignoreDifferences` on the Wger `Application` for `/spec/template/metadata/annotations/rollme` on `apps/Deployment` resources.
- Validation: after applying the ignore rule, resource-level OutOfSync entries for Wger deployments cleared.

## Working Fixes
- If Wger pods start but PowerSync fails, verify the shared PostgreSQL cluster still exposes `wal_level=logical`.
- Keep the DB secret keys aligned with the chart defaults: `USERDB_USER`, `USERDB_PASSWORD`, and `USERDB_NAME`.
- For first install and resets, ensure a `GymConfig` row exists (`pk=1`) before relying on readiness probes against `/`.
- If `setup-powersync-storage` fails with role privileges, bootstrap the role/schema as a DB admin and then recheck PowerSync logs.
- Treat `rollme` annotation drift as chart-generated noise; keep the ignore-differences rule in [../../apps/argocd/wger-application.yaml](../../apps/argocd/wger-application.yaml).

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