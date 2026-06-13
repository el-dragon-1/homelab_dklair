# Homelab DKLair Agent Instructions

## Working Principle

Start from the nearest owning file and the smallest relevant document set. Do not widen scope until the local change is understood.

## Context Map

- Cluster and GitOps behavior: `README.md`, `HARDWARE.md`, `application-template.yaml`, `root-application.yaml`
- Kubernetes app changes: `apps/argocd/`, `values/`
- OpenWRT changes: `openwrt/`, `apps/openwrt-ops/`, `openwrt/README.md`
- Tutorials and runbooks: the nearest file under `tutorials/`

## Change Process

- Read the nearest README or manifest before editing.
- Prefer existing patterns over introducing new structure.
- Make the smallest diff that satisfies the request.
- Update documentation only when the behavior or operator workflow changes.
- When a change crosses domains, update the nearest domain README before the root README.

## Repository Rules

- Keep Kubernetes apps in the Helm chart plus `values/<app>/values.yaml` plus `apps/argocd/<app>-application.yaml` pattern.
- Prefer the shared PostgreSQL instance for new app databases unless isolation or performance requires a separate database.
- Treat `openwrt/baseline` as read-only evidence and `openwrt/desired` as the enforced state.
- Never commit secrets or raw OpenWRT exports.
- Keep per-device OpenWRT configuration split by area into one UCI file each.

## Validation

- Use the narrowest useful validation command for the touched files.
- If behavior changes, prefer a focused test, lint, or manifest check over a broad repo-wide run.
- Report any assumptions or unresolved gaps explicitly.