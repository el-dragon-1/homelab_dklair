# Keeper Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Keeper. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/keeper-application.yaml](../../apps/argocd/keeper-application.yaml)
- Status: Managed through Argo CD with the sibling values file.

## Current Deployment Shape
- Namespace: `keeper`.
- Ingress host: `keeper.dklair.io` via Traefik ingress class `my-traefik`.
- Auth path: ingress is protected with middleware `authentik-authentik-forward-auth@kubernetescrd`.
- The chart already sets `BETTER_AUTH_URL` and `TRUSTED_ORIGINS` to `https://keeper.dklair.io`.

## Known Good State
- The Keeper ingress host in `values/keeper/values.yaml` matches the public hostname.
- The chart ingress template uses `.Values.ingress.host` directly.

## Recurring Problems
- Authentik can return `no app for hostname` when the Proxy Provider external host or outpost assignment does not include `keeper.dklair.io` exactly.

## Troubleshooting History
- Date: 2026-09-19
- Issue: Keeper loaded an Authentik error page saying `no app for hostname` for `keeper.dklair.io`.
- Root cause: The Keeper chart already points at `keeper.dklair.io`; the failing layer is the Authentik Proxy Provider / outpost mapping, which must include the exact hostname.
- Fix: In Authentik Admin, create or update the Proxy Provider for Keeper with external host `https://keeper.dklair.io`, bind it to the Keeper application, and add that application to the embedded outpost.
- Validation: Re-test the public URL after the provider/outpost mapping is updated; the proxy error should disappear and the login flow should redirect through Authentik instead of reporting a hostname mismatch.

## Working Fixes
- Compare the app ingress host and the Authentik Proxy Provider external host first.
- If the provider host differs, correct the Authentik provider external host and outpost assignment to match `keeper.dklair.io` exactly.
- Re-test with a private browser session and, if needed, inspect the outpost route in Authentik before blaming the chart.

## Dependencies And Secrets
- Depends on Traefik middleware `authentik-authentik-forward-auth@kubernetescrd` in namespace `authentik`.
- Depends on Authentik outpost publishing the Keeper hostname with path `/outpost.goauthentik.io`.

## Important Files
- [../../apps/argocd/keeper-application.yaml](../../apps/argocd/keeper-application.yaml)
- [values.yaml](values.yaml)

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.