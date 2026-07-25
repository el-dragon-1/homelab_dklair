---
description: "Use when reviewing or editing application manifests, Helm values, or Argo CD app resources."
applyTo: "application-template.yaml, root-application.yaml, apps/argocd/**, values/**"
---

# Application Deployment Review

Before changing an app manifest or values file, review the upstream Helm chart and confirm the deployment model fits this cluster.

- Read the chart docs before proposing or applying a deployment.
- Check whether the chart creates its own database, ingress, persistence, controllers, or other stateful components that need explicit disabling.
- Verify whether the workload can safely run with multiple replicas before enabling HA.
- Prefer ARM64 scheduling when the image supports it.
- If the image requires AMD64, keep the workload to a single replica and pin it to the appropriate AMD64 node or node pool with affinity or selectors.
- For PostgreSQL-backed apps, create the Vault secret path first, sync the ExternalSecret, run the provisioner script, and only then sync the Argo CD application.
- Prefer the shared PostgreSQL instance unless isolation or performance requirements justify a dedicated database.
- Keep app-specific overrides in values/<app-name>/values.yaml and preserve the repo's two-source Argo CD pattern.
- Update the nearest tutorial or context file when the operator workflow changes.
