# CloudNativePG Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting CloudNativePG. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/cloudnativepg.yaml](../../apps/argocd/cloudnativepg.yaml)
- Status: Managed through Argo CD with a nonstandard application-manifest filename.

## Current Deployment Shape
- This directory configures the CloudNativePG operator, not an application workload.
- Summarize operator version, namespace, CRD expectations, and interactions with the PostgreSQL cluster chart after the next validated review.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, CRD drift, webhook issues, and operator-upgrade concerns.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- Keep short, validated repair steps worth reusing.

## Dependencies And Secrets
- Note cluster-wide prerequisites, storage assumptions, and any admission-webhook dependencies.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.