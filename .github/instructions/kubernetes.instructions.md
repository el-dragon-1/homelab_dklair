---
description: "Use when editing Kubernetes, Helm, Argo CD, values, hardware, or cluster documentation files."
applyTo: ["README.md", "HARDWARE.md", "application-template.yaml", "root-application.yaml", "apps/argocd/**", "values/**", "tutorials/argocd/**", "tutorials/cloudflare/**", "tutorials/external-secrets-application.yaml"]
---

# Kubernetes and GitOps Workflow

- Start with `README.md`, `HARDWARE.md`, and the nearest manifest.
- Use `application-template.yaml` as the baseline for new Argo CD applications.
- Keep app-specific settings in `values/<app>/values.yaml`.
- Preserve the repo's two-source Argo CD pattern and `CreateNamespace=true` unless a concrete exception is needed.
- Prefer the shared PostgreSQL instance for new databases.
- If a change affects deployment order or sync behavior, verify the sync-wave and automated sync settings.
- Update the nearest tutorial or README when operators need new steps.