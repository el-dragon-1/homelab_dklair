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
- Date: 2026-08-10
- Issue: Argo CD sync failed and app reported `Resource not found in cluster: apps/v1/StatefulSet:vaultwarden`.
- Root cause: The chart rendered an invalid StatefulSet because `storage.data.name`, `storage.attachments.name`, and both `accessMode` fields were empty in values, so the StatefulSet create call was rejected by Kubernetes.
- Fix: Set explicit PVC names and access modes in [values.yaml](values.yaml):
	- `storage.data.name: vaultwarden-data`
	- `storage.data.accessMode: ReadWriteOnce`
	- `storage.attachments.name: vaultwarden-attachments`
	- `storage.attachments.accessMode: ReadWriteOnce`
- Validation: `helm template` now renders named volume mounts and valid `accessModes` entries, and Argo application manifest passes kubectl client dry-run.

## Working Fixes
- If Argo reports missing StatefulSet for Vaultwarden, check `status.conditions[].message` on the Argo Application first; this commonly indicates the StatefulSet was rejected by the API server rather than truly missing.
- Validate chart rendering locally before sync:
	- `helm template vaultwarden vaultwarden --repo https://guerzon.github.io/vaultwarden --version 0.46.0 -f values/vaultwarden/values.yaml`

## Dependencies And Secrets
- Add Vault/ExternalSecret references for admin token and optional SMTP credentials when configured.

## Important Files
- [../../apps/argocd/vaultwarden-application.yaml](../../apps/argocd/vaultwarden-application.yaml)
- [values.yaml](values.yaml)

## Open Questions
- Decide whether to keep SQLite or migrate to shared PostgreSQL for long-term backup and recovery preferences.
