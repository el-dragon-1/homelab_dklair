# Argo CD Server Placement Validation Runbook

Use this runbook after Argo CD upgrades, chart changes, or node maintenance to verify that `argocd-server` keeps two healthy replicas on separate arm64 nodes from the approved set.

## Scope
- Application: Argo CD server deployment
- Namespace: `argocd`
- Public URL: `https://argocd.dklair.io`
- Source of truth values: [tutorials/argocd/values.yaml](values.yaml)

## Prerequisites
1. `kubectl` access with working kubeconfig.
2. Cluster API reachable.
3. DNS and ingress for `argocd.dklair.io` already configured.

## Expected Policy
1. `server.replicas: 2`
2. `server.nodeSelector` includes:
   - `kubernetes.io/arch: arm64`
   - `kubernetes.io/os: linux`
3. `server.affinity.nodeAffinity` restricts hostnames to:
   - `node1`, `node2`, `node3`, `orangepi5`
4. `server.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution` enforces cross-node placement.
5. `server.tolerations` includes:
   - `key=homelab.io/control-infra`, `effect=NoSchedule`, `operator=Exists`

## Validation Steps
1. Verify deployment policy from values file:

```bash
sed -n '1100,1395p' tutorials/argocd/values.yaml
```

2. Verify live deployment policy:

```bash
KUBECONFIG=~/kube/k3s.yaml kubectl get deploy argocd-server -n argocd -o jsonpath='{.spec.replicas}{" replicas\nnodeSelector="}{.spec.template.spec.nodeSelector}{"\naffinity="}{.spec.template.spec.affinity}{"\ntolerations="}{.spec.template.spec.tolerations}{"\n"}'
```

3. Confirm two running replicas and separate nodes:

```bash
KUBECONFIG=~/kube/k3s.yaml kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o wide
```

Success criteria:
- Two `Running` pods.
- Pod nodes are different.
- Nodes are in `node1|node2|node3|orangepi5`.

4. Confirm stable web asset behavior (no hash flapping with 404):

```bash
for i in 1 2 3 4 5; do
  h=$(curl -sk https://argocd.dklair.io | grep -o 'main\.[^" ]*\.js' | head -n1)
  code=$(curl -sk -o /dev/null -w '%{http_code}' https://argocd.dklair.io/$h)
  echo "$i $h asset=$code"
done
```

Success criteria:
- Repeated checks return `asset=200`.
- No intermittent JavaScript 404s.

## Troubleshooting
1. If one replica is `Pending`, inspect scheduling reason:

```bash
KUBECONFIG=~/kube/k3s.yaml kubectl describe pod -n argocd <pending-pod-name>
KUBECONFIG=~/kube/k3s.yaml kubectl get events -n argocd --sort-by=.lastTimestamp | tail -n 60
```

2. Common blocker: control-plane taint without matching toleration.
3. Common blocker: anti-affinity with too few eligible nodes.

## Temporary Mitigation
If web access is unstable during incident response, temporarily reduce to one replica:

```bash
KUBECONFIG=~/kube/k3s.yaml kubectl scale deploy argocd-server -n argocd --replicas=1
KUBECONFIG=~/kube/k3s.yaml kubectl rollout status deploy argocd-server -n argocd --timeout=120s
```

After stabilizing, restore policy-driven HA via GitOps values and sync.

## Related Context
- Argo CD application context: [values/argocd/context.md](../../values/argocd/context.md)
