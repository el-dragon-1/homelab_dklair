# WireGuard Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting WireGuard. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/wireguard-application.yaml](../../apps/argocd/wireguard-application.yaml)
- Status: Managed through Argo CD with the sibling values file.

## Current Deployment Shape
- Summarize namespace, service exposure, peer-management model, storage, and network-policy assumptions after the next validated review.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, routing mistakes, peer-config drift, and service exposure symptoms.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- Keep short, validated repair steps worth reusing.

## Dependencies And Secrets
- Note service exposure, peer credentials, storage, and any DNS or ingress interactions that matter during changes.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.