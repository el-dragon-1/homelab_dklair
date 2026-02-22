# ArgoCD

ArgoCD was added using helm and the following yaml file [values.yaml](tutorials/argocd/values.yaml). The configuration is working but I didnt trim the fat before running:

There is sample documentation within the ArgoCD docs [Here](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/#helm). I was directed to where the [helm charts](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd) are being maintained.


```
helm repo add argocd https://argoproj.github.io/argo-helm
```
```
helm repo update
```

I started with the values.yaml and vibe coded the following yaml file (i think) using a ton of back and forth and error troubleshooting.

```yaml
global:
  domain: argocd.dklair.io

# redis
redis:
  enabled: false

# redis-ha disables redis single node deployment.
redis-ha:
  enabled: true
  persistentVolume:
    enabled: true
    size: 1Gi
    storageClass: "longhorn"

# -- Application Controller (StatefulSet)
controller:
  replicas: 3

# -- Repo Server
repoServer:
  replicas: 2

# -- Argo CD Server
server:
  replicas: 1

  ingress:
    enabled: true
    controller: generic
    ingressClassName: "traefik"
    hostname: "argocd.dklair.io"
    tls: false
    annotations:
      traefik.ingress.kubernetes.io/router.entrypoints: web

# -- ApplicationSet Controller
applicationSet:
  replicas: 2

# required for Traefik to handle tls.
params:
    create: true
    annotations: {}
    server.insecure: true
```

Make sure you run this command from the directory with values.yaml

```
helm install argocd argo/argo-cd -n argocd --create-namespace --values values.yaml
```
