# Homelab Hardware

This homelab is running on a k3s cluster with a 3 node control plane and two worker nodes.

- Node 1
  - raspberry pi 4b+
- Node 2
  - raspberry pi 4b+

## ArgoCD and Gitops

# once completed you must run the command
# kubectl apply -f apps/whoami-application.yaml -n argocd
# this is because the UI reverts the multiple source configuration to a single source.