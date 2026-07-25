# Prometheus Operator CRDs Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting the Prometheus Operator CRDs deployment. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/prometheus-operator-crds-application.yaml](../../apps/argocd/prometheus-operator-crds-application.yaml)
- Status: Managed through Argo CD as supporting infrastructure for the monitoring stack.

## Current Deployment Shape
- This directory manages CRDs rather than an end-user service.
- Summarize CRD versioning, rollout ordering, and interactions with the main Prometheus stack after the next validated review.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, CRD drift, sync-order problems, and schema mismatch symptoms.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- Keep short, validated repair steps worth reusing.

## Dependencies And Secrets
- Note ordering dependencies on the monitoring stack and any cluster-scoped prerequisites.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.