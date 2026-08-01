# Audiobookshelf Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Audiobookshelf. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/audiobookshelf-application.yaml](../../apps/argocd/audiobookshelf-application.yaml)
- Status: Managed through Argo CD with the sibling values file.

## Current Deployment Shape
- Namespace: `audiobookshelf`
- Ingress host: `audiobookshelf.dklair.io` via Traefik ingress class `my-traefik`
- Storage: Longhorn-backed PVCs for `/config` (10Gi), `/metadata` (20Gi), and `/audiobooks` (100Gi)

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, misleading symptoms, and early warning signs.

- Large browser uploads can fail with `413 Payload Too Large` at Cloudflare before requests reach Traefik/Audiobookshelf.

## Troubleshooting History
- Date: 2026-07-26
- Issue: Uploading audiobook files from browser fails.
- Root cause: `audiobookshelf.dklair.io` is Cloudflare-proxied and Cloudflare enforces request body size limits by plan; large upload requests were rejected at the edge with HTTP 413 before reaching the cluster.
- Fix: For large uploads, use a non-proxied hostname (Cloudflare DNS only), local/LAN hostname that terminates directly on Traefik, or raise Cloudflare upload limits if plan supports it.
- Validation: `curl -I https://audiobookshelf.dklair.io` returned `server: cloudflare`; a 105MiB POST to the same host returned HTTP `413` with response body footer `cloudflare`.

## Working Fixes
- Keep short, validated repair steps worth reusing.

- Confirm edge rejection quickly with:
	- `curl -I https://audiobookshelf.dklair.io`
	- `dd if=/dev/zero bs=1m count=105 2>/dev/null | curl -sS -o /tmp/abs_large_post.out -w "%{http_code}\n" -X POST https://audiobookshelf.dklair.io/ --data-binary @-`
- If code is `413` and response body mentions Cloudflare, route large uploads through a non-proxied host path.
- Operator note: Prefer LAN/VPN upload paths for large files rather than exposing a public DNS-only upload hostname.

## Dependencies And Secrets
- Note the external services, storage, DNS, ingress, and Kubernetes Secrets this app depends on.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

- [../../tutorials/audiobookshelf/lab-vpn-upload-pattern.md](../../tutorials/audiobookshelf/lab-vpn-upload-pattern.md)

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.