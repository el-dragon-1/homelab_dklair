# Homelab Hardware

This homelab is running on a k3s cluster with a 3 node control plane and two worker nodes.

- Node 1
  - raspberry pi 4b+
- Node 2
  - raspberry pi 4b+

## ArgoCD and Gitops

### Deploying an application

There are two files that need to be created and configured in order to launch the application.

There is a values.yaml file that is placed in the /values/new-app directory. This values.yaml file is configured based on my setup.

The first section defines the replica count as well as some default image and pull policy values. They are not needed but are good to show in case you need to adjust them.

```yaml
# This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/
replicaCount: 1

# This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/
image:
  repository: traefik/whoami
  # This sets the pull policy for images.
  pullPolicy: IfNotPresent
```

The second step here is the ingress configuration which is how the service is exposed.

It must be enabled and my ingress className is always "my-traefik".

```yaml
ingress:
  enabled: true # must be set to true.
  className: 'my-traefik' # for my setup this must be my-traefic. Yours may be different.
  annotations: {}
    # traefik.ingress.kubernetes.io/router.entrypoints: web,websecure ## the entrypoint annotation is usually needed but you can try without.
  hosts:
    - host: whoami.dklair.io # this is the path setup in cloudflare.
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []
  #  - secretName: whoami-local-tls
  #    hosts:
  #      - whoami.local
# -- Expose the service via gateway-api HTTPRoute
# Requires Gateway API resources and suitable controller installed within the cluster
# (see: https://gateway-api.sigs.k8s.io/guides/)
```

```yaml
replicaCount: 1

image:
  repository: traefik/whoami
  # This sets the pull policy for images.
  pullPolicy: IfNotPresent

ingress:
  enabled: true
  className: 'my-traefik'
  annotations: {}
    # kubernetes.io/tls-acme: "true"
  hosts:
    - host: whoami.dklair.io
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []
  #  - secretName: whoami-local-tls
  #    hosts:
  #      - whoami.local

# -- Expose the service via gateway-api HTTPRoute
# Requires Gateway API resources and suitable controller installed within the cluster
# (see: https://gateway-api.sigs.k8s.io/guides/)
httpRoute:
  # HTTPRoute enabled.
  enabled: false
  # HTTPRoute annotations.
  annotations: {}
  # Which Gateways this Route is attached to.
  parentRefs:
    - name: gateway
      sectionName: http
      # namespace: default
  # Hostnames matching HTTP header.
  hostnames:
    - whoami.local
  # List of rules and filters applied.
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /headers

# This is to setup the liveness and readiness probes more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
livenessProbe:
  httpGet:
    path: /health
    port: http
readinessProbe:
  httpGet:
    path: /health
    port: http

# This section is for setting up autoscaling more information can be found here: https://kubernetes.io/docs/concepts/workloads/autoscaling/
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
  # targetMemoryUtilizationPercentage: 80
```

There is an application yaml which is placed in the /apps directory.

 The configuration of the application yaml requires some constants:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: whoami  # the name of your application
  namespace: argocd # this must always be argocd.
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
    - repoURL: https://harrytang.github.io/helm-charts/ # the helm chart repository
      targetRevision: 0.1.2 # the version of the chart to deploy
      chart: whoami # the name of the chart to deploy
      helm:
        valueFiles:
          - $values/values/whoami/values.yaml # the values file to use for the helm chart
    - repoURL: https://github.com/el-dragon-1/homelab_dklair.git # the git repository containing the values file
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

At this point you should see the application running in the ArgoCD UI.

![Alt text](/tutorials/readme-images/application-argocd.png)

