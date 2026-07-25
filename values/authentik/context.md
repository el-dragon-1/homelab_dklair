# Authentik Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Authentik. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/authentik-application.yaml](../../apps/argocd/authentik-application.yaml)
- App auth runbook: [../../tutorials/argocd/authentik-application-authentication.md](../../tutorials/argocd/authentik-application-authentication.md)
- Provisioning helper: [../../scripts/provision-authentik-db-from-secrets.sh](../../scripts/provision-authentik-db-from-secrets.sh)
- Status: Managed through Argo CD with the sibling values file and a database-provisioning helper.

## Current Deployment Shape
- Deploys to namespace `authentik` from the upstream `authentik` chart at target revision `2026.5.4`.
- Runs one server replica and one worker replica.
- Exposes `authentik.dklair.io` through Traefik with TLS secret `authentik-tls`, ClusterIssuer `letsencrypt-prod`, and middleware `authentik-authentik-https-headers@kubernetescrd`.
- Uses the shared PostgreSQL cluster at `postgresql-rw.postgresql.svc.cluster.local:5432` with DB credentials sourced from Secret `authentik-credentials`.
- Explicitly disables the chart-managed PostgreSQL subchart (`postgresql.enabled=false`) so only the shared PostgreSQL instance is used.
- Reads `AUTHENTIK_SECRET_KEY`, bootstrap email, and bootstrap password from the same Secret `authentik-credentials`.
- Mounts ConfigMap `authentik-user-settings` as `/data/user_settings.py`.
- Sets `AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS` to the cluster pod and service CIDRs `10.42.0.0/16,10.43.0.0/16`.

## Known Good State
- The Authentik role and database exist in the shared PostgreSQL cluster before the first sync.
- Argo CD reports the `authentik` application as `Synced` and `Healthy`.
- The `authentik-credentials` Secret contains the database, bootstrap, and secret-key values expected by the chart.

## Recurring Problems
- Capture repeated failures, misleading symptoms, and bootstrap traps.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- Before the first sync or after credential drift, run [../../scripts/provision-authentik-db-from-secrets.sh](../../scripts/provision-authentik-db-from-secrets.sh) so the role, database, and schema grants match the Vault-synced Secret.
- The provisioning helper prefers Secret `postgresql-superuser` and falls back to `postgresql-admin`; preserve that lookup order unless cluster admin-secret conventions change.

## Dependencies And Secrets
- Secret `authentik-credentials` provides the Authentik secret key, PostgreSQL username/password, and bootstrap email/password.
- Depends on ConfigMap `authentik-user-settings`.
- Depends on shared PostgreSQL and the ingress middleware `authentik-authentik-https-headers@kubernetescrd`.

## Important Files
- [../../apps/argocd/authentik-application.yaml](../../apps/argocd/authentik-application.yaml)
- [values.yaml](values.yaml)
- [../../scripts/provision-authentik-db-from-secrets.sh](../../scripts/provision-authentik-db-from-secrets.sh)

## Open Questions
- If bootstrap values rotate after the initial setup, document which fields still matter to steady-state operations versus one-time initialization.