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
- Sets PostgreSQL parameters `max_connections=100` and `shared_buffers=128MB`.
- Resource requests are `100m` CPU and `256Mi` memory; limits are `500m` CPU and `512Mi` memory.

## Known Good State
- Argo CD reports the `postgresql` application as `Synced` and `Healthy`.
- The bootstrap Secret `postgresql-admin` contains `username` and `password` keys expected by the cluster chart.
- Application provisioning helpers can connect to `postgresql-rw.postgresql.svc.cluster.local:5432` and create or repair per-app roles and databases successfully.

## Recurring Problems
- Capture repeated failures, pod failover symptoms, storage pressure, and database-provisioning issues.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- If bootstrap behavior regresses after chart edits, verify that initialization is still declared under `cluster.initdb`; moving it under `bootstrap.initdb` is a known schema mistake.
- Use the app-specific provisioning helpers to reconcile database roles and grants after Secret or ownership drift instead of patching privileges ad hoc.

## Dependencies And Secrets
- Depends on Longhorn for persistent storage.
- Secret `postgresql-admin` seeds the cluster bootstrap user; some provisioning flows prefer `postgresql-superuser` when present.
- Application provisioning scripts such as [../../scripts/provision-authentik-db-from-secrets.sh](../../scripts/provision-authentik-db-from-secrets.sh) assume the shared cluster service name `postgresql-rw.postgresql.svc.cluster.local`.

## Important Files
- [../../apps/argocd/postgresql.yaml](../../apps/argocd/postgresql.yaml)
- [values.yaml](values.yaml)
- [../../scripts/provision-authentik-db-from-secrets.sh](../../scripts/provision-authentik-db-from-secrets.sh)

## Open Questions
- If this cluster expands beyond one instance, record the operational checks that replace the current single-instance assumptions.