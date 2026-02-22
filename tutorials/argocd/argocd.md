# ArgoCD

ArgoCD was added using helm and the following yaml file [values.yaml](tutorials/argocd/values.yaml). The configuration is working but I didnt trim the fat before running:

There is ample documentation within the ArgoCD docs. [Here](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/#helm) is the location where I was directed to where the [helm charts](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd) are being maintained.


```
helm repo add argocd https://argoproj.github.io/argo-helm
```
```
helm repo update
```

Make sure you run this command from the directory with values.yaml

```
helm install argocd argo/argo-cd -n argocd --create-namespace --values values.yaml
```
