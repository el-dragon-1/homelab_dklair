# Homepage Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Homepage. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/homepage-application.yaml](../../apps/argocd/homepage-application.yaml)
- Status: Managed through Argo CD with the sibling values file.

## Current Deployment Shape
- Namespace: `homepage`.
- Ingress host: `homepage.dklair.io` via Traefik ingress class `my-traefik`.
- Auth path: ingress is protected with middleware `authentik-authentik-forward-auth@kubernetescrd`.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Auth redirect loops when Authentik outpost ingress claims `/` for `homepage.dklair.io` instead of only `/outpost.goauthentik.io`.

## Troubleshooting History
- Date: 2026-07-25
- Issue: Browser showed "This page isn't working" when opening Homepage with Authentik enabled.
- Root cause: Authentik outpost ingress for `homepage.dklair.io` was configured with path `/`, which intercepted all traffic and conflicted with Traefik forward-auth middleware flow.
- Fix: Reconfigure the Homepage provider/outpost mapping in Authentik so `homepage.dklair.io` uses forward-auth flow with outpost path `/outpost.goauthentik.io` (not `/`).
- Validation: `curl -k -I https://homepage.dklair.io` redirected to `https://homepage.dklair.io/outpost.goauthentik.io/start?...rd=.../auth/traefik` during failure; this differs from known-good apps (for example `whoami.dklair.io`) that redirect to `https://authentik.dklair.io/application/o/authorize/...`.

## Working Fixes
- Check outpost ingress paths with `kubectl get ingress -n authentik ak-outpost-homelab-dklairio-outpost -o jsonpath='{range .spec.rules[*]}{.host}{" => "}{range .http.paths[*]}{.path}{" "}{end}{"\\n"}{end}'`.
- For forward-auth protected apps, keep outpost path to `/outpost.goauthentik.io`; avoid `/` on the same host unless intentionally using full reverse-proxy mode.
- After Authentik provider/outpost changes, re-test with `curl -k -I https://homepage.dklair.io` and confirm redirect target matches Authentik authorize flow instead of self-looping `/outpost.goauthentik.io/start?...rd=.../auth/traefik`.

## Dependencies And Secrets
- Depends on Traefik middleware `authentik-authentik-forward-auth@kubernetescrd` in namespace `authentik`.
- Depends on Authentik outpost route for `homepage.dklair.io/outpost.goauthentik.io`.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.