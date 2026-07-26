# Uptime Kuma Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Uptime Kuma. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/uptime-kuma-application.yaml](../../apps/argocd/uptime-kuma-application.yaml)
- Status: Managed through Argo CD with the sibling values file.

## Current Deployment Shape
- Namespace: uptime-kuma.
- Ingress host: uptime.dklair.io via Traefik ingress class my-traefik.
- Auth path: protected by middleware authentik-authentik-forward-auth@kubernetescrd.
- Persistence: Longhorn PVC via chart volume settings.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Auth appears broken or bypassed when Authentik outpost ingress host does not match the app ingress host.

## Troubleshooting History
- Date: 2026-07-25
- Issue: Uptime Kuma auth page did not work while using the same middleware annotation pattern as other apps.
- Root cause: Uptime Kuma ingress used uptime.dklair.io, but Authentik outpost ingress was publishing uptime-kuma.dklair.io for the outpost path. Forward-auth requests to /outpost.goauthentik.io/auth/traefik on uptime.dklair.io did not reach outpost.
- Fix: Update Authentik provider and outpost host mapping to uptime.dklair.io and keep outpost path /outpost.goauthentik.io.
- Validation: Before fix, curl -k -I https://uptime.dklair.io returned app redirect to /dashboard. After host alignment, curl -k -I https://uptime.dklair.io and curl -k -I https://uptime.dklair.io/outpost.goauthentik.io/auth/traefik both returned redirects to authentik.dklair.io authorize flow.

## Working Fixes
- Compare app host and outpost host first:
	- kubectl get ingress -n uptime-kuma -o yaml
	- kubectl get ingress -n authentik ak-outpost-homelab-dklairio-outpost -o yaml
- If hosts differ, correct the Authentik provider external host and outpost assignment to match the app ingress host exactly.
- Re-test with:
	- curl -k -I https://uptime.dklair.io
	- curl -k -I https://uptime.dklair.io/outpost.goauthentik.io/auth/traefik

## Dependencies And Secrets
- Depends on Traefik middleware authentik-authentik-forward-auth@kubernetescrd in namespace authentik.
- Depends on Authentik outpost publishing uptime.dklair.io with path /outpost.goauthentik.io.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.