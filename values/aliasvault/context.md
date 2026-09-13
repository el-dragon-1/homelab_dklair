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
- Persists `/secrets` via Longhorn PVC so Aliasvault can generate and persist internal secrets (`jwt_key`, `data_protection_cert_pass`), while mounting `postgres_password` from the Kubernetes secret via `subPath`.
- Exposes the application at `aliasvault.dklair.io` via Traefik ingress with cert-manager Let's Encrypt TLS.
- Uses Longhorn storage for persistent data (`/database`, `/logs`, `/certificates`, and `/secrets`).

## Troubleshooting History
- Initial onboarding completed using `bjw-s/app-template` chart pattern.
- Date: 2026-09-13
- Issue: Web registration failed with "an error occurred. Please try again."
- Root cause: Container environment specified `POSTGRES_USER: aliasvault`, but the provisioned role and Vault secret username was `aliasvault-admin`, causing database auth failure in internal API/TaskRunner services.
- Fix: Updated `values.yaml` to set `POSTGRES_USER: aliasvault-admin`.
- Validation: Database authentication succeeded and Aliasvault API/TaskRunner initialized migrations.
- Date: 2026-09-13
- Issue: Username validation/registration failed with "an error occurred. Please try again." and log `KeyNotFoundException: JWT key file not found at /secrets/jwt_key`.
- Root cause: `/secrets` was mounted directly as a read-only Kubernetes Secret volume, preventing the container init script from generating and persisting internal application keys (`jwt_key`, `data_protection_cert_pass`).
- Fix: Changed `/secrets` to a Longhorn PVC volume and mounted `postgres_password` from `aliasvault-db` secret with `subPath`.
- Validation: Container init script successfully creates `/secrets/jwt_key` and API auth/validation endpoints succeed.
