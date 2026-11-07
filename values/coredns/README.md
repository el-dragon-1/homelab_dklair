# Cluster CoreDNS

The [CoreDNS application](../../apps/argocd/coredns-application.yaml) adopts the
existing K3s cluster DNS resources using the local [chart](../../charts/coredns)
and [values](values.yaml). The separate `coredns-custom` application is not the
`kube-dns` Service.

## Ownership requirements

- Every K3s server must have
  `/var/lib/rancher/k3s/server/manifests/coredns.yaml.skip`. Create it before
  allowing Argo CD to manage the addon and verify it on replacement servers
  before they join. K3s does not synchronize these files between servers.
- Do not use K3s `--disable=coredns` for this handoff: it uninstalls the
  packaged addon and can remove live DNS resources. K3s rewrites its packaged
  manifest at startup, so do not edit that manifest.
- Keep server-side apply enabled with client-side apply migration disabled.
  The chart intentionally omits `data.NodeHosts` from the `coredns` ConfigMap:
  the K3s supervisor maintains that key. Do not remove the key or replace the
  ConfigMap.
- Preserve the `kube-dns` Service IP, deployment selector, and two-replica
  rollout policy. Review K3s CoreDNS changes when upgrading K3s; the pinned
  image and chart no longer follow packaged addon upgrades automatically.

## Verification

```bash
kubectl --context K3S rollout status deployment/coredns -n kube-system
kubectl --context K3S get pods -n kube-system -l k8s-app=kube-dns -o wide
kubectl --context K3S get endpointslices -n kube-system \
  -l kubernetes.io/service-name=kube-dns
kubectl --context K3S get configmap coredns -n kube-system \
  -o go-template='{{if index .data "NodeHosts"}}NodeHosts present{{else}}NodeHosts missing{{end}}{{"\n"}}'
```

Confirm two ready endpoints on separate nodes and test cluster, external, and
local hostnames from a workload. Check both endpoints directly as well as the
Service.

## Recovery

Do not delete the `kube-dns` Service, ConfigMap, or deployment to resolve an
Argo CD ownership issue. Restore the last known working Git revision and sync
the application while preserving the skip files. If returning ownership to
K3s is necessary, first disable Argo automated sync and pruning, plan a
maintenance window, verify each server's packaged manifest and access, and
coordinate removal of the skip files with K3s reconciliation. Confirm DNS
endpoints and query resolution throughout. Do not run competing reconcilers.
