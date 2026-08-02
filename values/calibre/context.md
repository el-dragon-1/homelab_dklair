# Calibre Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Calibre. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/calibre-application.yaml](../../apps/argocd/calibre-application.yaml)
- Status: Managed through Argo CD with the sibling values file.

## Current Deployment Shape
- Namespace: calibre
- Host: calibre.dklair.io via Traefik ingress class my-traefik
- Storage: longhorn PVCs mounted at /config and /books
- Runtime image: ghcr.io/linuxserver/calibre-web:version-0.6.26

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Login appears to accept credentials but user is returned to login page or cannot enter site.

## Troubleshooting History
- Date: 2026-08-02
- Issue: Login accepted credentials but user did not enter the site.
- Root cause: Historical app traceback showed sqlite OperationalError querying missing column shelf.kobo_sync while rendering sidebar during login flow. This can present as a post-login loop or failed page render.
- Fix: Restarted deployment after confirming schema now includes shelf.kobo_sync and sessions are being written to user_session. Verified rollout success and clean startup logs.
- Validation: kubectl checks confirmed healthy pod, ingress, and PVC mounts; session records persisted in /config/app.db with future expiry timestamps.

## Working Fixes
- If login loop is reported, first inspect /config/calibre-web.log for schema exceptions around login (especially shelf.kobo_sync errors).
- Verify DB schema and sessions:
	- sqlite3 /config/app.db "pragma table_info(shelf);"
	- sqlite3 /config/app.db "select id,user_id,expiry from user_session order by id desc limit 10;"
- If schema appears corrected but behavior persists, perform a controlled rollout restart of deployment calibre-calibre-web and re-test with a fresh browser session.

## Dependencies And Secrets
- DNS and edge: Cloudflare in front of calibre.dklair.io
- Ingress/TLS: Traefik ingress class my-traefik with cert-manager issuer letsencrypt-prod
- Persistent data: longhorn-backed /config and /books PVCs

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.