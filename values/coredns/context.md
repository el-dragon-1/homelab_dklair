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
  homelab names. A GitOps handoff was completed using a local chart that keeps
  the existing deployment selector and Service IP. K3s addon skip files were
  installed on all three servers; node3's listing was confirmed by the owner
  in an interactive sudo session. Argo CD adopted the existing resources
  without a deployment spec change, and both the child and root applications
  reported Synced. Two DNS endpoints remained ready, direct and Service DNS
  queries passed, and CoreDNS alerts cleared. A harmless deployment-label
  drift was automatically corrected by Argo self-heal. The ConfigMap retained
  `NodeHosts`, with managed fields still owned by the K3s supervisor; a
  subsequent dynamic NodeHosts update was not exercised.
