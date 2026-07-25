# Cert-Manager Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting cert-manager. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/cert-manager-application.yaml](../../apps/argocd/cert-manager-application.yaml)
- Related manifest: [../../apps/cert-manager/cluster-issuer.yaml](../../apps/cert-manager/cluster-issuer.yaml)
- Status: Managed through Argo CD with additional issuer resources in the repo.

## Current Deployment Shape
- Summarize the controller namespace, issuer flow, DNS challenge dependencies, and certificate ownership boundaries after the next validated review.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, ACME challenge issues, and certificate renewal symptoms.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- Keep short, validated repair steps worth reusing.

## Dependencies And Secrets
- Note DNS provider credentials, ClusterIssuer prerequisites, and any ingress-controller interactions.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.