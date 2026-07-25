# Nextcloud Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Nextcloud. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/nextcloud-application.yaml](../../apps/argocd/nextcloud-application.yaml)
- Related runbook: [../../tutorials/nextcloud/theming-safeguard-runbook.md](../../tutorials/nextcloud/theming-safeguard-runbook.md)
- Status: Managed through Argo CD with additional safeguarding documented in a runbook.

## Current Deployment Shape
- Deploys to namespace `nextcloud` from the upstream `nextcloud` chart at target revision `9.1.4`.
- Exposes `nextcloud.dklair.io` through Traefik with TLS secret `nextcloud-tls` and middleware `nextcloud-nextcloud-security-headers@kubernetescrd`.
- Uses admin credentials from Secret `nextcloud-admin` and trusts only `nextcloud.dklair.io` as an explicit application domain.
- Runs against the shared PostgreSQL cluster at `postgresql-rw.postgresql.svc.cluster.local:5432` with credentials from Secret `nextcloud-db`.
- Uses Redis for app caching with auth disabled, persistence disabled, and no replicas.
- Stores persistent app data on a `20Gi` Longhorn volume.
- Enables `phpClientHttpsFix` so Nextcloud generates HTTPS URLs correctly behind Traefik termination.
- Runs background jobs as a sidecar cronjob.
- Enforces theming safeguards through chart-native `post-installation` and `post-upgrade` hooks that disable user theming and set both theme color values to `#0082c9`.

## Known Good State
- Argo CD reports the `nextcloud` application as `Synced` and `Healthy`.
- The deployed `nextcloud` workload includes `docker-entrypoint-hooks.d` mounts for the theming safeguard hooks.
- `php occ config:app:get theming disable-user-theming` returns `yes`.
- `php occ config:app:get theming color` and `background_color` both return `#0082c9`.

## Recurring Problems
- Invalid or empty theming color values can cause post-login HTTP 500 errors on dashboard and TOTP challenge routes.
- Reverse-proxy header handling is sensitive enough that trusted-proxy settings should be treated as part of the known-good baseline.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- If login succeeds but dashboard or TOTP redirects return HTTP 500, reapply the safe theming values with `php occ config:app:set theming ...` as documented in [../../tutorials/nextcloud/theming-safeguard-runbook.md](../../tutorials/nextcloud/theming-safeguard-runbook.md).
- If manual theming remediation works, verify the hook entries in [values.yaml](values.yaml) and resync Argo CD instead of leaving the fix only in runtime state.

## Dependencies And Secrets
- Secret `nextcloud-admin` stores admin bootstrap credentials.
- Secret `nextcloud-db` stores PostgreSQL username and password.
- Depends on Longhorn for persistent storage.
- Depends on the middleware resource `nextcloud-nextcloud-security-headers@kubernetescrd` referenced by ingress annotations.

## Important Files
- [../../apps/argocd/nextcloud-application.yaml](../../apps/argocd/nextcloud-application.yaml)
- [values.yaml](values.yaml)
- [../../tutorials/nextcloud/theming-safeguard-runbook.md](../../tutorials/nextcloud/theming-safeguard-runbook.md)

## Open Questions
- If a future chart version changes `nextcloud.hooks` behavior, revalidate the theming safeguard before upgrading broadly.