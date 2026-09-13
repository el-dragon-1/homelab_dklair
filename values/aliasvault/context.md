# Aliasvault Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Aliasvault. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/aliasvault-application.yaml](../../apps/argocd/aliasvault-application.yaml)
- Namespace: [../../apps/external-secrets-config/aliasvault-namespace.yaml](../../apps/external-secrets-config/aliasvault-namespace.yaml)
- ExternalSecret: [../../apps/external-secrets-config/aliasvault-db-externalsecret.yaml](../../apps/external-secrets-config/aliasvault-db-externalsecret.yaml)
- Companion doc: [vault-secrets.md](vault-secrets.md)

## Current Deployment Shape
- Deploys Aliasvault using the generic `bjw-s/app-template` Helm chart (v3).
- Uses the all-in-one image `ghcr.io/aliasvault/aliasvault:0.30.5`.
- Reuses the shared PostgreSQL cluster via ExternalSecret (`aliasvault-db`).
- Mounts `/secrets` into the container for password file access (`POSTGRES_PASSWORD_FILE: /secrets/postgres_password`).
- Exposes the application at `aliasvault.dklair.io` via Traefik ingress with cert-manager Let's Encrypt TLS.
- Uses Longhorn storage for persistent data (`/database`, `/logs`, and `/certificates`).

## Troubleshooting History
- Initial onboarding completed using `bjw-s/app-template` chart pattern.
