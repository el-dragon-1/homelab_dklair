# Homelab Hardware

This homelab is running on a k3s cluster with a 3 node control plane and two worker nodes.

- Node 1
  - raspberry pi 4b+
- Node 2
  - raspberry pi 4b+

## ArgoCD and Gitops

### Deploying an application

There are two files that need to be created and configured in order to launch the application. There is an application yaml which is placed in the /apps directory and the values.yaml file that is placed in the /values/new-app directory. The configuration of the application yaml requires some constants:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: whoami
  namespace: argocd # <<<< this must always be argocd.
  annotations:
    argocd.argoproj.io/managed-by-cluster-argocd: argocd
    argocd.argoproj.io/sync-wave: "1"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  destination:
    namespace: whoami
    server: https://kubernetes.default.svc
  sources:
    - repoURL: https://harrytang.github.io/helm-charts/ # <<<< the helm chart repository
      targetRevision: 0.1.2 # <<<< the version of the chart to deploy
      chart: whoami # <<<< the name of the chart to deploy
      helm:
        valueFiles:
          - $values/values/whoami/values.yaml # <<<< the values file to use for the helm chart
    - repoURL: https://github.com/el-dragon-1/homelab_dklair.git # <<<< the git repository containing the values file
      targetRevision: HEAD
      ref: values
  project: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
```

Once completed you must run the command

```
kubectl apply -f apps/whoami-application.yaml -n argocd
```

This is because the UI reverts the multiple source configuration to a single source.

