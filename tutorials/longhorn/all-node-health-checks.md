# Longhorn All-Node Health Checks

Use this runbook to verify Longhorn is healthy and scheduled on all five cluster nodes.

## Prerequisites

- `kubectl` access to the cluster
- `KUBECONFIG` set to this cluster context
- Longhorn GitOps resources present:
  - `apps/argocd/longhorn-application.yaml`
  - `values/longhorn/values.yaml`

## Expected Healthy State

- Argo CD `longhorn` application is `Synced` and `Healthy`.
- DaemonSets `longhorn-manager`, `longhorn-csi-plugin`, and `engine-image-*` are at `5/5` with `MISSCHED=0`.
- All Longhorn nodes report `ready=True` and `sched=True`.
- No volumes are `degraded`, `faulted`, or `unknown`.

## Validation Steps

```bash
export KUBECONFIG=~/kube/k3s.yaml

echo "=== Argo CD app health ==="
kubectl -n argocd get application longhorn \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

echo
echo "=== Longhorn DaemonSets ==="
kubectl -n longhorn-system get ds \
  -o custom-columns=NAME:.metadata.name,DESIRED:.status.desiredNumberScheduled,CURRENT:.status.currentNumberScheduled,READY:.status.numberReady,AVAILABLE:.status.numberAvailable,MISSCHED:.status.numberMisscheduled

echo
echo "=== Longhorn node readiness ==="
kubectl -n longhorn-system get nodes.longhorn.io \
  -o jsonpath='{range .items[*]}{.metadata.name}{" ready="}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{" sched="}{range .status.conditions[?(@.type=="Schedulable")]}{.status}{end}{"\n"}{end}'

echo
echo "=== Volume robustness issues ==="
kubectl -n longhorn-system get volumes.longhorn.io \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.robustness}{"\n"}{end}' | egrep 'degraded|faulted|unknown' || echo 'No degraded/faulted/unknown volumes'
```

## Drift Check (All-Node Scheduling)

Run this when health is green but counts are lower than expected.

```bash
export KUBECONFIG=~/kube/k3s.yaml

for ds in longhorn-manager longhorn-csi-plugin $(kubectl -n longhorn-system get ds -o name | sed 's#daemonset.apps/##' | grep '^engine-image-'); do
  echo "=== $ds selector/tolerations ==="
  kubectl -n longhorn-system get ds "$ds" -o jsonpath='nodeSelector={.spec.template.spec.nodeSelector}{"\ntolerations="}{.spec.template.spec.tolerations}{"\n\n"}'
done

echo "=== Longhorn settings ==="
kubectl -n longhorn-system get settings.longhorn.io taint-toleration system-managed-components-node-selector \
  -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.value}{"\n"}{end}'
```

For all-node scheduling, expected values are:

- `taint-toleration=homelab.io/control-infra=true:NoSchedule`
- `system-managed-components-node-selector=` (empty)

## Rollback / Cleanup

- If validation fails right after a sync, inspect the `longhorn` Argo CD app events and the `longhorn-system` namespace events.
- Revert the latest Longhorn GitOps commit if the cluster enters an unhealthy state.
- After rollback, re-run the validation block to confirm recovery.
