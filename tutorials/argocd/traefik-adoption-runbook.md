# Traefik Argo CD Adoption Runbook

Use this runbook to safely adopt the existing Helm release `default/my-traefik` under Argo CD management.

## Scope
- Application: Traefik ingress controller
- Namespace: `default`
- Existing Helm release: `my-traefik`
- Argo CD app manifest: [../../apps/argocd/traefik-application.yaml](../../apps/argocd/traefik-application.yaml)
- Source-of-truth values: [../../values/traefik/values.yaml](../../values/traefik/values.yaml)

## Prerequisites
1. `kubectl`, `helm`, and Argo CD access are available.
2. Kubeconfig points to this cluster (`~/kube/k3s.yaml` in this repo).
3. K3s bundled Traefik addon is disabled on all server nodes.

## Pre-Sync Checks
1. Confirm existing Helm release identity and version:

```bash
helm ls -A | grep '^my-traefik\s\+default\s'
```

Success criteria:
- Release `my-traefik` exists in namespace `default`.
- Chart is `traefik-37.1.2`.

2. Confirm core live resources are healthy:

```bash
KUBECONFIG=~/kube/k3s.yaml kubectl get deploy,svc,ingressclass -n default | grep my-traefik || true
KUBECONFIG=~/kube/k3s.yaml kubectl get ingressclass my-traefik
KUBECONFIG=~/kube/k3s.yaml kubectl -n default get deploy my-traefik
```

Success criteria:
- Deployment `my-traefik` is `Available=True`.
- Service `my-traefik` exists and is `LoadBalancer`.
- IngressClass `my-traefik` exists.

3. Confirm VIP pin and service addressing before adoption:

```bash
KUBECONFIG=~/kube/k3s.yaml kubectl -n default get svc my-traefik -o jsonpath='{.spec.loadBalancerIP}{"\n"}{.status.loadBalancer.ingress[0].ip}{"\n"}{.metadata.annotations.kube-vip\.io/loadbalancerIPs}{"\n"}'
```

Success criteria:
- `spec.loadBalancerIP` is `192.168.4.100`.
- Reported ingress IP is `192.168.4.100`.
- Kube-vip annotation remains `192.168.4.100`.

4. Confirm the Argo CD app is configured to match live release naming:

```bash
grep -nE 'name: traefik|releaseName: my-traefik|targetRevision: 37.1.2|namespace: default' apps/argocd/traefik-application.yaml
```

Success criteria:
- `releaseName: my-traefik` is present.
- `targetRevision: 37.1.2` is present.
- Destination namespace is `default`.

## First Sync
1. Commit and push changes containing:
- [../../apps/argocd/traefik-application.yaml](../../apps/argocd/traefik-application.yaml)
- [../../values/traefik/values.yaml](../../values/traefik/values.yaml)

2. Wait for the root app to register the Traefik app.
3. Trigger sync for the `traefik` application from Argo CD UI or CLI.

## Post-Sync Checks
1. Confirm Argo CD reports healthy and synced:

```bash
KUBECONFIG=~/kube/k3s.yaml kubectl -n argocd get applications.argoproj.io traefik -o jsonpath='{.status.sync.status}{"\n"}{.status.health.status}{"\n"}'
```

Success criteria:
- Sync status is `Synced`.
- Health status is `Healthy`.

2. Confirm service VIP and type did not change:

```bash
KUBECONFIG=~/kube/k3s.yaml kubectl -n default get svc my-traefik -o jsonpath='{.spec.type}{"\n"}{.spec.loadBalancerIP}{"\n"}{.status.loadBalancer.ingress[0].ip}{"\n"}'
```

Success criteria:
- Service type remains `LoadBalancer`.
- VIP remains `192.168.4.100` in spec and status.

3. Confirm ingress class remains default:

```bash
KUBECONFIG=~/kube/k3s.yaml kubectl get ingressclass my-traefik -o jsonpath='{.metadata.annotations.ingressclass\.kubernetes\.io/is-default-class}{"\n"}'
```

Success criteria:
- Annotation value is `true`.

4. Confirm data-plane readiness and rollout state:

```bash
KUBECONFIG=~/kube/k3s.yaml kubectl -n default rollout status deploy/my-traefik --timeout=120s
KUBECONFIG=~/kube/k3s.yaml kubectl -n default get pods -l app.kubernetes.io/name=traefik -o wide
```

Success criteria:
- Rollout completes successfully.
- Traefik pod is Running and Ready.

## Rollback
If post-sync checks fail and traffic is affected:
1. Disable auto-sync for Traefik app in Argo CD.
2. Revert the commit that introduced Traefik app/values changes.
3. Re-sync root app.
4. Verify service VIP and ingress class return to expected state.

## Related Context
- Traefik app context: [../../values/traefik/context.md](../../values/traefik/context.md)
- K3s addon remediation context: [../../values/prometheus-stack/context.md](../../values/prometheus-stack/context.md)
