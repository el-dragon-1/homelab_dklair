# Traefik Context

Use this file to preserve durable outcomes from Traefik deployment and troubleshooting sessions. Keep conclusions short and validated.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/traefik-application.yaml](../../apps/argocd/traefik-application.yaml)
- Status: Installed as Helm release `default/my-traefik`; now represented in GitOps for Argo CD adoption.

## Current Deployment Shape
- Namespace: `default`
- Chart: `traefik/traefik`
- Pinned chart version: `37.1.2`
- Service: `LoadBalancer` with VIP `192.168.4.100`
- IngressClass: `my-traefik` (default class)

## Known Good State
- Traefik deployment `default/my-traefik` is ready with one replica.
- Service `default/my-traefik` serves ports 80 and 443 at `192.168.4.100`.
- IngressClass `my-traefik` exists and is marked as default.

## Troubleshooting History
- Date: 2026-08-02
- Issue: Cluster used a separate Helm-managed Traefik release while GitOps and Argo CD had no Traefik Application manifest.
- Root cause: Traefik release was provisioned outside repo-managed Argo CD application definitions.
- Fix: Added [../../apps/argocd/traefik-application.yaml](../../apps/argocd/traefik-application.yaml) and [values.yaml](values.yaml) to represent live release configuration and allow safe Argo CD adoption.
- Validation: Release metadata confirmed (`my-traefik`, chart `traefik-37.1.2`), resources confirmed (`deployment`, `service`, `ingressclass`), and service VIP verified as `192.168.4.100`.

## Working Fixes
- Keep `helm.releaseName: my-traefik` in the Argo CD app so rendered object names match the live release.
- Keep `service.loadBalancerIP: 192.168.4.100` pinned to avoid unintended VIP changes on reconciliation.
- Keep `providers.kubernetesCRD.allowCrossNamespace: true` to preserve middleware usage patterns across namespaces.

## Open Questions
- After first healthy manual Argo CD sync, decide whether to enable automated sync for Traefik by adding `syncPolicy.automated`.
