# Redis Cluster Context

Use this file to preserve the durable outcome of Copilot chats about planning, building, or troubleshooting the Redis cluster. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: none — never wired into GitOps.
- Argo CD application: none — never existed under [../../apps/argocd/](../../apps/argocd)
- Status: Removed 2026-08-22. The `redis` namespace no longer exists.

## Current Deployment Shape
- N/A. A standalone Bitnami `redis-cluster` chart (helm release `redis-cluster` in namespace `redis`) was manually installed 2026-04-19 outside GitOps and had zero consumers in the cluster (no Service/ConfigMap/Secret/workload referenced `redis-cluster.redis.svc`). Removed via `helm uninstall redis-cluster -n redis`, followed by deleting its leftover PVCs and the `redis` namespace.
- Apps needing redis each run their own dedicated instance instead: `baserow-redis-master` (baserow), `nextcloud-redis-master` (nextcloud), `wger-redis` (wger). Argo CD's own cache uses a separate `argocd-redis-ha-server` bundled by the Argo CD chart.

## Known Good State
- Add the expected healthy state once an implementation exists.

## Recurring Problems
- Capture repeated failures, design reversals, or bootstrap traps as they emerge.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- Keep short, validated repair steps worth reusing.

## Dependencies And Secrets
- Note storage, app dependencies, ingress or service exposure, and any Secret/config requirements when they are introduced.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first once they exist.

## Open Questions
- Track unresolved design choices, TODOs, or follow-up checks.