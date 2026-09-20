# Mailu Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Mailu. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/mailu-application.yaml](../../apps/argocd/mailu-application.yaml)
- ExternalSecret: [../../apps/external-secrets-config/mailu-db-externalsecret.yaml](../../apps/external-secrets-config/mailu-db-externalsecret.yaml)
- Companion doc: [vault-secrets.md](vault-secrets.md)

## Current Deployment Shape
- Deploys Mailu from the upstream `mailu` Helm chart at target revision `2.8.0`.
- Uses Traefik ingress for web/admin endpoints with cert-manager TLS.
- Uses a dedicated `LoadBalancer` service on the Mailu front component for SMTP/IMAP protocol ports.
- Persists Mailu data using Longhorn (`persistence.single_pvc=true`).
- Starts with a `10Gi` Longhorn PVC to minimize initial storage footprint; expand later as mailbox usage grows.
- Uses the shared PostgreSQL cluster (`postgresql-rw.postgresql.svc.cluster.local`) through ExternalSecret-backed credentials.

## Pi-hole DNS Notes
- For LAN-first validation before MX cutover, create Pi-hole Local DNS records for:
- `mail.<domain>` -> Mailu front LoadBalancer IP.
- `autodiscover.<domain>` -> Mailu front LoadBalancer IP.
- `autoconfig.<domain>` -> Mailu front LoadBalancer IP.
- Keep public DNS/MX unchanged until ingress, SMTP submission, and mailbox login are validated.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, misleading symptoms, and early warning signs.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- Keep short, validated repair steps worth reusing.

## Dependencies And Secrets
- Secret `mailu-core-secrets` with key `secret-key`.
- Secret `mailu-admin` with key `password` for initial admin account bootstrap.
- Secret `mailu-db` synced from Vault path `homelab/mailu/postgresql` with keys `username`, `password`, and `database`.
- Cert-manager cluster issuer and TLS secret configured through ingress values.
- Public deliverability still depends on routable SMTP port 25 and correct PTR/rDNS.

## Important Files
- [../../apps/argocd/mailu-application.yaml](../../apps/argocd/mailu-application.yaml)
- [../../apps/external-secrets-config/mailu-db-externalsecret.yaml](../../apps/external-secrets-config/mailu-db-externalsecret.yaml)
- [values.yaml](values.yaml)
- [vault-secrets.md](vault-secrets.md)

## Open Questions
- Decide final public ingress/LB strategy for SMTP (direct homelab IP vs VPS relay/gateway).
