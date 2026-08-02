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
- Root cause: Active loop was caused by strong session protection (`config_session=1`) behind reverse proxies. Calibre accepted credentials and wrote authenticated `user_session` rows, but request identity checks could invalidate the session on subsequent proxied requests.
- Fix: Set `config_session=0` (Basic session protection), retained `config_external_port=443` and trusted host `calibre.dklair.io`, then restarted deployment. Added a GitOps-side initContainer in [values.yaml](values.yaml) to enforce these DB settings on every pod start.
- Validation: Session rows continued to be created for user_id 1, rollout completed successfully, and setting persisted after restart.

## Working Fixes
- If login loop is reported, first inspect /config/calibre-web.log for schema exceptions around login (especially shelf.kobo_sync errors).
- Verify DB schema and sessions:
	- sqlite3 /config/app.db "pragma table_info(shelf);"
	- sqlite3 /config/app.db "select id,user_id,expiry from user_session order by id desc limit 10;"
- If schema appears corrected but behavior persists, perform a controlled rollout restart of deployment calibre-calibre-web and re-test with a fresh browser session.
- For Cloudflare/Traefik deployments, prefer Basic session protection (`config_session=0`). Strong mode can clear sessions if request identity changes through proxies.
- GitOps durability: [values.yaml](values.yaml) includes initContainer `calibre-login-fix` that patches `/config/app.db` settings (`config_session=0`, `config_external_port=443`, `config_trustedhosts=calibre.dklair.io`) before the main container starts.

## Dependencies And Secrets
- DNS and edge: Cloudflare in front of calibre.dklair.io
- Ingress/TLS: Traefik ingress class my-traefik with cert-manager issuer letsencrypt-prod
- Persistent data: longhorn-backed /config and /books PVCs

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.