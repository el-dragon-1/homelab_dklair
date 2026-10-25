# PostgreSQL Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting the shared PostgreSQL cluster. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/postgresql.yaml](../../apps/argocd/postgresql.yaml)
- Status: Managed through Argo CD with a nonstandard application-manifest filename.

## Current Deployment Shape
- This directory configures the shared CloudNativePG database cluster used by other apps.
- Deploys to namespace `postgresql` from the CloudNativePG `cluster` chart at target revision `0.6.0`.
- Uses `nameOverride: postgresql` and `fullNameOverride: postgresql-cluster`.
- Runs a single database instance with a `10Gi` Longhorn-backed volume.
- Bootstraps via `cluster.initdb` with database `admin`, owner `admin`, and bootstrap credentials from Secret `postgresql-admin`.
- The values file explicitly notes that `initdb` must remain under `cluster.initdb`, not `bootstrap.initdb`.
- Sets PostgreSQL parameters `max_connections=100`, `shared_buffers=128MB`, and `wal_level=logical`.
- Resource requests are `100m` CPU and `256Mi` memory; limits are `500m` CPU and `512Mi` memory.

## Known Good State
- Argo CD reports the `postgresql` application as `Synced` and `Healthy`.
- The bootstrap Secret `postgresql-admin` contains `username` and `password` keys expected by the cluster chart.
- Application provisioning helpers can connect to `postgresql-rw.postgresql.svc.cluster.local:5432` and create or repair per-app roles and databases successfully.

## Shared-DB Upgrade Rule
- Every app that uses the shared CloudNativePG cluster must complete a compatibility check before any app, chart, or database upgrade.
- No upgrade is allowed to proceed without confirming: app image/chart version compatibility with the PostgreSQL version, required DB driver/schema changes, logical-replication assumptions, role/database existence, and secret drift risk.
- For any shared-DB app, record the compatibility review in the app's `values/<app>/context.md` and keep the shared PostgreSQL context in sync with the outcome.
- If compatibility is not confirmed, the upgrade must be paused, pinned, or deferred until the app and database are validated together.
- This policy applies to Authentik, Open WebUI, Aliasvault, Baserow, Wger, Mailu, Nextcloud, Keeper, and any future app added to the shared PostgreSQL cluster.

## Recurring Problems
- Capture repeated failures, pod failover symptoms, storage pressure, and database-provisioning issues.

## Troubleshooting History
- 2026-10-23: With explicit owner approval after read-only dependency inspection,
  removed retired databases `aliasvault`, `nextcloud`, `mailu`, and `wger`
  (approximately 569 MB combined). Removed Wger's inactive logical slot
  `powersync_1_ec96`, which had retained approximately 416 MB of WAL; physical
  WAL reclamation was not measured. No target sessions were present at execution.
  Dropped dedicated roles `aliasvault-admin`, `nextcloud`, `mailu`, `wger`, and
  `powersync_storage` without cascading dependency removal. Preserved `dpolizzi`,
  which owns active Authentik, and all other databases/roles. Catalog verification
  confirmed target databases, roles, and slot absent; active Authentik connections
  remained. Vault/ExternalSecret configuration and the shared PostgreSQL PVC
  were unchanged. Re-provision databases/roles before re-enabling these apps;
  retained credentials alone do not recreate them.
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- If bootstrap behavior regresses after chart edits, verify that initialization is still declared under `cluster.initdb`; moving it under `bootstrap.initdb` is a known schema mistake.
- Use the app-specific provisioning helpers to reconcile database roles and grants after Secret or ownership drift instead of patching privileges ad hoc.
- For new PostgreSQL-backed applications, run [../../scripts/onboard-app-postgres-from-vault.sh](../../scripts/onboard-app-postgres-from-vault.sh) to guide Vault update, ExternalSecret sync, DB provisioning, commit/push, and root sync.
- Keep `wal_level=logical` enabled while Wger uses the shared cluster for its PowerSync-backed deployment.

## Dependencies And Secrets
- Depends on Longhorn for persistent storage.
- Secret `postgresql-admin` seeds the cluster bootstrap user; some provisioning flows prefer `postgresql-superuser` when present.
- Application provisioning scripts such as [../../scripts/provision-authentik-db-from-secrets.sh](../../scripts/provision-authentik-db-from-secrets.sh) assume the shared cluster service name `postgresql-rw.postgresql.svc.cluster.local`.

## Important Files
- [../../apps/argocd/postgresql.yaml](../../apps/argocd/postgresql.yaml)
- [values.yaml](values.yaml)
- [../../scripts/provision-authentik-db-from-secrets.sh](../../scripts/provision-authentik-db-from-secrets.sh)
- [../../scripts/onboard-app-postgres-from-vault.sh](../../scripts/onboard-app-postgres-from-vault.sh)

## Open Questions
- If this cluster expands beyond one instance, record the operational checks that replace the current single-instance assumptions.