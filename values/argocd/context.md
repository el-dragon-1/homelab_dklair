# Argo CD Context

Use this file to preserve durable outcomes from Argo CD troubleshooting and operations changes.

## Repo Anchors
- Values file: [../../tutorials/argocd/values.yaml](../../tutorials/argocd/values.yaml)
- Root application: [../../root-application.yaml](../../root-application.yaml)

## Troubleshooting History
- Date: 2026-07-25
- Issue: Argo CD web UI intermittently failed with JavaScript bundle 404 errors.
- Root cause: Different argocd-server pods served different main.<hash>.js references, and mixed backend routing caused HTML from one pod to reference a bundle not present on another pod.
- Fix: Temporary recovery used one server replica; durable fix restored two replicas on arm64 with node constraints and hard pod anti-affinity across hostnames.
- Validation: Repeated public checks returned a stable single bundle hash and HTTP 200 for the referenced bundle.

- Date: 2026-07-25
- Issue: Argo CD CLI context existed but API calls failed with expired token and password login failures.
- Root cause: Stored CLI auth token had expired and the bootstrap initial-admin secret no longer matched active admin credentials.
- Fix: Rotated admin password in `argocd-secret` (`admin.password` + `admin.passwordMtime`), restarted `argocd-server`, and re-authenticated CLI with `--grpc-web --insecure`.
- Validation: `argocd account get-user-info`, `argocd proj list`, and `argocd app list` succeeded against `argocd.dklair.io`.

## Working Fixes
- If the UI fails with intermittent main.<hash>.js 404, test for hash flapping by repeating HTML fetches from https://argocd.dklair.io and verifying referenced bundle status codes.
- Fast mitigation: temporarily scale argocd-server to one replica.
- Durable policy for this cluster:
  - Keep argocd-server on arm64 only.
  - Restrict placement to node1, node2, node3, orangepi5.
  - Keep hard pod anti-affinity by hostname so replicas run on separate nodes.
  - Tolerate homelab.io/control-infra:NoSchedule to allow control-plane placement.
  - If one replica stays Pending during rollout, check for control-plane taint tolerance and anti-affinity conflicts first.
- For CLI/API access through this ingress, use `--grpc-web` (or configure it once via `argocd login ... --grpc-web`).

## Open Questions
- Evaluate whether to add topology spread constraints for stronger distribution behavior during rollouts.
