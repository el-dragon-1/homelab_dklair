# Longhorn Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Longhorn. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/longhorn-application.yaml](../../apps/argocd/longhorn-application.yaml)
- Related runbook: [../../tutorials/longhorn/all-node-health-checks.md](../../tutorials/longhorn/all-node-health-checks.md)
- Status: Managed through Argo CD with an existing node-health runbook.

## Current Deployment Shape
- This app provides cluster storage rather than an end-user service.
- Deploys to namespace `longhorn-system` from the upstream `longhorn` chart at target revision `1.9.1`.
- Argo CD places it at sync wave `1`, making it part of the early infrastructure layer.
- The global values intentionally leave `nodeSelector` empty so Longhorn components remain schedulable across the cluster.
- Both the chart-wide toleration and `defaultSettings.taintToleration` allow Longhorn workloads to run on nodes tainted with `homelab.io/control-infra=true:NoSchedule`.
- `systemManagedComponentsNodeSelector` is explicitly blank so system-managed Longhorn components are not narrowed to a subset of nodes.

## Known Good State
- Argo CD reports the `longhorn` application as `Synced` and `Healthy`.
- The checks in [../../tutorials/longhorn/all-node-health-checks.md](../../tutorials/longhorn/all-node-health-checks.md) pass after chart, taint, or node-selection changes.
- Longhorn workloads remain schedulable on all intended nodes, including tainted control-plane infrastructure nodes.

## Recurring Problems
- Capture repeated failures, replica health issues, disk pressure, and node-rollout regressions.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- After Longhorn chart changes or node-taint updates, run [../../tutorials/longhorn/all-node-health-checks.md](../../tutorials/longhorn/all-node-health-checks.md) before considering the rollout complete.
- If Longhorn system pods stop scheduling on control-plane infrastructure nodes, compare live tolerations against the current values before changing node selectors.

## Dependencies And Secrets
- Depends on Longhorn-compatible disks and node availability across the cluster.
- Depends on the `homelab.io/control-infra=true:NoSchedule` toleration pattern remaining aligned with node taints.

## Important Files
- [../../apps/argocd/longhorn-application.yaml](../../apps/argocd/longhorn-application.yaml)
- [values.yaml](values.yaml)
- [../../tutorials/longhorn/all-node-health-checks.md](../../tutorials/longhorn/all-node-health-checks.md)

## Open Questions
- If node-role or taint strategy changes, confirm whether Longhorn should still span control-plane infrastructure nodes.