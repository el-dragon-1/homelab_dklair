# CoreDNS Context

Cluster DNS is distinct from the `coredns-custom` deployment. See the
[operator guide](README.md), [values](values.yaml), and
[Argo CD application](../../apps/argocd/coredns-application.yaml).

## Troubleshooting History

- 2026-11-07: The K3s deployment had one ready replica because required node
  affinity permitted `node1`, `node2`, and `eldragon`, but the two control-plane
  nodes had an untolerated `homelab.io/control-infra` taint. A live toleration
  and `maxUnavailable: 0` restored two ready replicas and cleared the alerts.
  Direct queries to each endpoint and the Service resolved cluster, public, and
  homelab names. A GitOps handoff was prepared using a local chart that keeps
  the existing deployment selector and Service IP. Server-side dry-run showed
  the deployment spec unchanged and preserved the supervisor-managed
  ConfigMap `NodeHosts` key. Verify the actual adoption and supervisor updates
  before treating the handoff as complete.
