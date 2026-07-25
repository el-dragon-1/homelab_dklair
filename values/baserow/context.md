# Baserow Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Baserow. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/baserow-application.yaml](../../apps/argocd/baserow-application.yaml)
- Companion doc: [vault-secrets.md](vault-secrets.md)
- Status: Managed through Argo CD with the sibling values file and a colocated Vault-secrets note.

## Current Deployment Shape
- Reuses the shared PostgreSQL cluster instead of a chart-managed database.
- TLS ingress is handled outside the chart; keep that separation in mind during future troubleshooting.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, migration issues, ingress quirks, and dependency ordering problems.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- Keep short, validated repair steps worth reusing.

## Dependencies And Secrets
- Review [vault-secrets.md](vault-secrets.md) for the current Vault path and Secret mapping details.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.