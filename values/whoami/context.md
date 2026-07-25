# Whoami Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Whoami. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/whoami-application.yaml](../../apps/argocd/whoami-application.yaml)
- Status: Managed through Argo CD with the sibling values file.

## Current Deployment Shape
- This is a simple edge-service deployment and a good low-risk test case for ingress or chart wiring changes.
- Summarize namespace, ingress host, and expected response behavior after the next validated review.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, ingress mismatches, and unexpected response or routing behavior.

## Troubleshooting History
- Date: 2026-07-25
- Issue: Argo CD failed to render whoami chart when adding Traefik middleware annotation under `ingress.annotations`.
- Root cause: Upstream chart version `0.1.2` has a strict `values.schema.json` that sets `ingress.annotations.additionalProperties=false`, which rejects annotation keys.
- Fix: Set `skipSchemaValidation: true` in [../../apps/argocd/whoami-application.yaml](../../apps/argocd/whoami-application.yaml) Helm source and keep the middleware annotation in [values.yaml](values.yaml).
- Validation: `get_errors` reports no YAML issues in both files; next validation is a successful Argo CD sync and browser redirect to Authentik.

## Working Fixes
- For whoami chart `0.1.2`, keep `spec.sources[0].helm.skipSchemaValidation: true` when using ingress annotations.
- Protect whoami with Authentik by setting `traefik.ingress.kubernetes.io/router.middlewares: authentik-authentik-forward-auth@kubernetescrd` in [values.yaml](values.yaml).

## Dependencies And Secrets
- Note ingress, DNS, and any minimal config inputs that matter during changes.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.