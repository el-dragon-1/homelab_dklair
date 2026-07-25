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
- Summarize the namespace, ingress hosts, storage, and any bootstrap details after the next validated review.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, misleading symptoms, and early warning signs.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- Keep short, validated repair steps worth reusing.

## Dependencies And Secrets
- Note the external services, storage, DNS, ingress, and Kubernetes Secrets this app depends on.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.