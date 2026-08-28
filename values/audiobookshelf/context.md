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
- Dedicated upload host: `abs-upload.dklair.io` via ingress `audiobookshelf-upload`, protected by Traefik middleware `audiobookshelf-upload-allowlist`
- Storage: Longhorn-backed PVCs for `/config` (10Gi), `/metadata` (20Gi), and `/audiobooks` (100Gi)

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, misleading symptoms, and early warning signs.

- Large browser uploads can fail with `413 Payload Too Large` at Cloudflare before requests reach Traefik/Audiobookshelf.
- Intermittent failures can still occur when clients have both Pi-hole and a public resolver configured; some requests resolve `audiobookshelf.dklair.io` via public DNS and route back through Cloudflare.
- Symptom "upload freezes around 1-1.5 MB" is the Cloudflare edge cutting the request body, not an Audiobookshelf or Longhorn problem. Cloudflare aborts after roughly 1.1 MB of body and returns `413`.
- `abs-upload.dklair.io` has no DNS record in Pi-hole or in public DNS, so the dedicated upload ingress is unreachable even though the Ingress, TLS secret, and allowlist middleware all exist in-cluster.

## Troubleshooting History

- Date: 2026-08-25
- Issue: MP4 upload from a PC stalls at about 1.5 MB.
- Root cause: The client resolved `audiobookshelf.dklair.io` through a public resolver instead of Pi-hole, so the upload traversed the Cloudflare proxy again.
- Evidence:
	- Client resolver was `1.1.1.1`; `audiobookshelf.dklair.io` resolved to `104.21.57.87` / `172.67.161.210` and `curl -I` returned `server: cloudflare`.
	- Pi-hole at `192.168.4.102` correctly answers `audiobookshelf.dklair.io` -> `192.168.4.100`.
	- 105 MiB POST through Cloudflare: `http=413 size_up=1113950 time=0.43`, body mentions `cloudflare`.
	- Same 105 MiB POST with `--resolve audiobookshelf.dklair.io:443:192.168.4.100`: `size_up=110100480 time=15.9`, full body accepted by Traefik and answered by the app.
- Fix: Point the uploading client at Pi-hole (`192.168.4.102`) as its only DNS server, then flush the DNS cache and re-test.
- Secondary gaps found:
	- `abs-upload.dklair.io` is absent from Pi-hole `dns.hosts`; add `192.168.4.100 abs-upload.dklair.io` for the dedicated upload path to work.
	- `values/pihole/values.yaml` requests `loadBalancerIP: 192.168.4.200`, but the `pihole-dns` service is actually assigned `192.168.4.102`, and `192.168.4.200` does not answer DNS. OpenWRT DHCP hands out `.102`, so the values file is drifted and misleading.
	- OpenWRT `iot` and `smz_guest` pools advertise `6,192.168.4.102,1.1.1.1`; clients on those VLANs can fall back to Cloudflare-resolving DNS at any time.
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
- Prove the cluster path is healthy by repeating the POST with `--resolve audiobookshelf.dklair.io:443:192.168.4.100`; a large `size_upload` value means only the edge was blocking.
- Verify client split DNS before deeper debugging: the host must resolve `audiobookshelf.dklair.io` to `192.168.4.100`, not to a Cloudflare address.
- List Pi-hole local records with `kubectl -n pihole exec deploy/pihole -- grep -n -A12 'hosts = \[' /etc/pihole/pihole.toml`.
- Operator note: Prefer LAN/VPN upload paths for large files rather than exposing a public DNS-only upload hostname.
- For clients that must use split DNS reliably, use Pi-hole as the only client-side DNS server and keep public resolvers as Pi-hole upstreams.

## Dependencies And Secrets
- Note the external services, storage, DNS, ingress, and Kubernetes Secrets this app depends on.

- Upload host TLS secret: `audiobookshelf-upload-tls` (cert-manager DNS-01)
- Upload host allowlist middleware: `audiobookshelf-upload-allowlist`

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

- [../../tutorials/audiobookshelf/lab-vpn-upload-pattern.md](../../tutorials/audiobookshelf/lab-vpn-upload-pattern.md)

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.