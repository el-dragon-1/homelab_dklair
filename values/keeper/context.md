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
- Authentik can return `no app for hostname` when the Forward auth provider external host or outpost assignment does not include `keeper.dklair.io` exactly.

## Troubleshooting History
- Date: 2026-09-19
- Issue: Keeper loaded an Authentik error page saying `no app for hostname` for `keeper.dklair.io`.
- Root cause: The Keeper chart already points at `keeper.dklair.io`; the failing layer is the Authentik Forward auth provider / outpost mapping, which must include the exact hostname.
- Fix: In Authentik Admin, create or update the Forward auth (single application) provider for Keeper with external host `https://keeper.dklair.io`, bind it to the Keeper application, and add that application to the embedded outpost.
- Validation: Re-test the public URL after the provider/outpost mapping is updated; the proxy error should disappear and the login flow should redirect through Authentik instead of reporting a hostname mismatch.

## Working Fixes
- Compare the app ingress host and the Authentik Forward auth provider external host first.
- If the provider host differs, correct the Authentik provider external host and outpost assignment to match `keeper.dklair.io` exactly.
- Re-test with a private browser session and, if needed, inspect the outpost route in Authentik before blaming the chart.
- Having the Authentik application name, slug, provider, and policy engine mode set to `any` is not enough by itself; the external host and outpost application binding still have to match the Keeper hostname exactly.

## iCloud Calendar Connection
- Keeper.sh supports direct iCloud sign-in.
- Use an Apple app-specific password, not the main Apple Account password.
- In Keeper, connect the iCloud account that owns the source calendar, then select the destination calendar to receive the copied busy blocks.
- If the iCloud password changes later, the Keeper connection must be re-authenticated with a new app-specific password.

## iCloud Import Failure
- `Failed to import calendars` usually means Keeper could not read any usable calendars from that Apple Account.
- One iCloud sign-in can contain multiple calendars; the calendar count alone is not the problem.
- Verify the Apple Account has two-factor authentication enabled and the app-specific password was generated at account.apple.com.
- Confirm the calendar you want is an actual iCloud calendar, not `On My iPhone` / `On My Mac` or a read-only subscribed calendar.
- If the Apple password was changed after the app-specific password was created, generate a new app-specific password and try again.
- Validated 2026-09-20: this error can also be triggered by an invalid Keeper `ENCRYPTION_KEY` even when Apple credentials are correct.
- Keeper requires `ENCRYPTION_KEY` to be a base64 string that decodes to exactly 32 bytes. The observed failing value decoded to 48 bytes and caused `POST /api/sources/caldav` to return 500 with `Encryption key must be 32 bytes (base64 encoded)`.
- In this repo the value is sourced from Vault path `homelab/keeper/application` property `encryption_key` through `apps/external-secrets-config/keeper-secrets-externalsecret.yaml`, so fix the Vault value first, then restart Keeper.

## Self-Hosted Notes
- This Keeper instance runs on Kubernetes through the local Helm chart, so import failures can also come from pod-level network or trust issues.
- The chart currently does not define proxy, timezone, or outbound-network overrides; if Apple login keeps failing, check pod egress to Apple and cluster DNS/TLS trust before changing the app config.
- The chart only injects the application env vars and secrets, so the iCloud import path is still mostly governed by Keeper's runtime and external Apple access.

## External Secrets Refresh Workflow
- Force a fresh pull from Vault with: `kubectl -n keeper annotate externalsecret keeper-secrets force-sync="$(date +%s)" --overwrite`.
- Confirm sync with: `kubectl -n keeper get externalsecret keeper-secrets -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,REASON:.status.conditions[0].reason,LASTSYNC:.status.refreshTime`.
- Secret updates do not automatically refresh env vars in an already-running Keeper pod, so restart deployment after sync: `kubectl -n keeper rollout restart deploy/keeper && kubectl -n keeper rollout status deploy/keeper`.
- Validate runtime key shape from the new pod by confirming `ENCRYPTION_KEY` decodes to 32 bytes.

## Google Connect Failure
- `{"error":"Unsupported provider"}` during Google connect on self-hosted Keeper can mean Google OAuth is disabled at runtime.
- Validate with pod-local capabilities endpoint: `curl -sS http://127.0.0.1:3001/api/auth/capabilities` and check `socialProviders.google`.
- Keeper enables Google only when both `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are present.
- In this repo those values should come from Vault path `homelab/keeper/application` properties `google_client_id` and `google_client_secret` via `apps/external-secrets-config/keeper-secrets-externalsecret.yaml`.
- Google OAuth callback for this deployment is `https://keeper.dklair.io/api/sources/callback/google`.

## Dependencies And Secrets
- Depends on Traefik middleware `authentik-authentik-forward-auth@kubernetescrd` in namespace `authentik`.
- Depends on Authentik outpost publishing the Keeper hostname with path `/outpost.goauthentik.io`.

## Important Files
- [../../apps/argocd/keeper-application.yaml](../../apps/argocd/keeper-application.yaml)
- [values.yaml](values.yaml)

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.