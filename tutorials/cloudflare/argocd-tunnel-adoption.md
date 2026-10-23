# Adopt the Existing Cloudflare Tunnel in Argo CD

## Prerequisites

- Access to the `K3S` context using `~/kube/k3s.yaml`.
- The existing `default/cloudflared` Deployment and ConfigMap.
- The existing `default/tunnel-credentials` Secret with a `credentials.json` key.
  Vault KV v2 mount `homelab`, path `cloudflare/tunnel`, property `credential_json`
  stores the complete credential JSON string. The
  [ExternalSecret](../../apps/external-secrets-config/cloudflared-tunnel-credentials-externalsecret.yaml)
  syncs it to this Secret. Never commit credential contents to Git.

The owning resources are the [Argo CD Application](../../apps/argocd/cloudflared-application.yaml),
[local Helm chart](../../charts/cloudflared/Chart.yaml), and
[application values](../../values/cloudflared/values.yaml).
The local chart preserves the existing Deployment selector, which cannot be
changed in place by adopting the community chart's selector labels.

## Scope

Argo CD manages the connector Deployment and its configuration, not the Cloudflare
account, tunnel identity, DNS records, or Access policies. This is the existing
locally managed tunnel named `k3s`, not a new token-based remotely managed tunnel.
Its local configuration forwards `*.dklair.io` to the existing Traefik service.
See [application routes](application-routes/configure-app-routes.md) for Cloudflare-side
configuration; do not recreate the tunnel or change DNS for this adoption.

The namespace remains `default` intentionally so Argo CD adopts the existing
resources and continues to use the same credentials. Three replicas are retained.
No database, ingress resource, Service, persistence, or controller is created.
The initial image digest matches the image observed on both ARM64 and AMD64 pods.

## 1. Validate Before Publishing

```bash
export KUBECONFIG="$HOME/kube/k3s.yaml"
kubectl config use-context K3S
kubectl config current-context
kubectl --context K3S -n default get deployment cloudflared
kubectl --context K3S -n default describe secret tunnel-credentials
helm lint charts/cloudflared -f values/cloudflared/values.yaml
helm template cloudflared charts/cloudflared --namespace default \
  -f values/cloudflared/values.yaml \
  | kubectl --context K3S apply --dry-run=server -f -
kubectl --context K3S apply --dry-run=server \
  -f apps/argocd/cloudflared-application.yaml
```

`describe secret` shows key names and sizes, not credential values.

## 2. Publish and Adopt

Commit and push the chart, application values, ExternalSecret, and Application
manifests together, including the manual-sync policies for root, secrets-config,
and Cloudflared. Do not apply the Application before those paths exist in the
remote Git repository, and do not run `helm install`: Argo CD renders the chart
and adopts the resources.

In Argo CD, review the root diff and manually sync the `external-secrets-config`
and `cloudflared` Application resources. This registers the tunnel Application
without deploying its workload because automatic sync is disabled. Then manually
sync `external-secrets-config` and wait for ESO:

```bash
kubectl --context K3S -n default wait --for=condition=Ready \
  externalsecret/cloudflared-tunnel-credentials --timeout=90s
```

ESO reconciles automatically; no restart of the operator is needed. Once the
ExternalSecret is Ready, review the Cloudflared diff and manually sync
`cloudflared`. Do not enable automatic sync during these checks.

If root reconciliation needs a refresh after publishing:

```bash
kubectl --context K3S -n argocd annotate application root \
  argocd.argoproj.io/refresh=hard --overwrite
```

Initial adoption triggers a rolling restart because of the pinned image reference,
readiness probe, and configuration checksum. `maxUnavailable: 0` and `maxSurge: 1`
retain the old replicas until a replacement connects to Cloudflare. Existing
long-lived connections on a replaced pod may still reconnect. Configuration changes
also trigger a rolling restart through the checksum annotation.

## 3. Verify

```bash
kubectl --context K3S -n argocd get application cloudflared
kubectl --context K3S -n default rollout status deployment/cloudflared --timeout=300s
kubectl --context K3S -n default get pods -l app=cloudflared -o wide
kubectl --context K3S -n default logs deployment/cloudflared --tail=50
```

Expect Argo CD `Synced` and `Healthy`, three ready replicas, and successful tunnel
connection registrations. Confirm the existing tunnel connectors in Cloudflare and
open a published application to verify routing and any Access login flow.

## Rollback

If adoption fails, keep the Application manifest in Git. Correct or revert the
chart or values change and push it, manually sync, then verify the rollout again. Do not delete
the Application or remove its manifest from Git: its cascading-deletion finalizer
can remove the tunnel Deployment and ConfigMap, interrupting external access.

For an emergency manual repair, first pause automatic reconciliation on root and
then on this Application so self-heal does not undo the repair:

```bash
kubectl --context K3S -n argocd patch application root --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
kubectl --context K3S -n argocd patch application cloudflared --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
```

Check that no sync is still running before repairing the workload. Publish the
corrected desired state before reapplying the manual-sync policies:

```bash
kubectl --context K3S apply -f apps/argocd/cloudflared-application.yaml
kubectl --context K3S apply -f root-application.yaml
```

The credentials Secret is not part of the Cloudflared application's resource set.
ESO manages it with `creationPolicy: Orphan`, preserving it if the ExternalSecret
is removed. Vault remains the credential source for disaster recovery.