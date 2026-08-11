# Vaultwarden Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Vaultwarden. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/vaultwarden-application.yaml](../../apps/argocd/vaultwarden-application.yaml)

## Current Deployment Shape
- Namespace: vaultwarden.
- Chart: `vaultwarden` from `https://guerzon.github.io/vaultwarden`.
- Ingress host: vaultwarden.dklair.io via Traefik ingress class my-traefik.
- TLS: cert-manager cluster issuer `letsencrypt-prod`, secret `vaultwarden-tls`.
- Persistence: Longhorn-backed PVCs for data and attachments.
- Registration: disabled by default (`signupsAllowed: "false"`).

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Track repeat failure patterns and misleading symptoms.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- Add high-signal checks and commands once validated.

## Dependencies And Secrets
- Add Vault/ExternalSecret references for admin token and optional SMTP credentials when configured.

## Important Files
- [../../apps/argocd/vaultwarden-application.yaml](../../apps/argocd/vaultwarden-application.yaml)
- [values.yaml](values.yaml)

## Open Questions
- Decide whether to keep SQLite or migrate to shared PostgreSQL for long-term backup and recovery preferences.
