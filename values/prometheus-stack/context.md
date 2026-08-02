# Prometheus Stack Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting the Prometheus stack. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/prometheus-stack-application.yaml](../../apps/argocd/prometheus-stack-application.yaml)
- Status: Managed through Argo CD with the sibling values file.

## Current Deployment Shape
- Summarize namespace, scrape scope, Alertmanager routing, storage, and ingress or dashboard exposure after the next validated review.
- Prometheus and Alertmanager ingress use Traefik ingress class `my-traefik`.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, alert-routing mistakes, missing metrics, and PVC or retention issues.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:
- Date: 2026-08-02
- Issue: `KubeJobFailed` alerts for `kube-system/helm-install-traefik` and `kube-system/helm-install-traefik-crd`.
- Root cause: K3s bundled `HelmChart` resources for `traefik` and `traefik-crd` are still enabled while the cluster is already running a separate Helm release `default/my-traefik`. The active control-plane mismatch was on `node3`, whose K3s service still starts without `--disable traefik --disable servicelb` and still has `/var/lib/rancher/k3s/server/manifests/traefik.yaml` on disk. The bundled jobs fail because CRDs already exist without the Helm ownership metadata expected by the K3s-managed release.
- Fix: Deleting the failed Jobs is only temporary because the K3s Helm controller recreates them. Durable fix is to align `node3` with the other servers by adding `--disable traefik --disable servicelb` to its K3s server startup config, restarting K3s on `node3`, then deleting any leftover bundled `Addon`, `HelmChart`, and Job resources if they remain.
- Validation: `helm ls -A` showed active release `my-traefik`; `kubectl get helmcharts.helm.cattle.io -A` showed bundled `traefik` and `traefik-crd`; recreated job logs showed `Required CRDs are missing` for `helm-install-traefik` and `invalid ownership metadata` for existing Gateway API CRDs during `helm-install-traefik-crd`; live host inspection showed `node1` and `node2` already include `--disable traefik --disable servicelb`, while `node3` does not and still has `traefik.yaml` in `/var/lib/rancher/k3s/server/manifests`.
- Validation after remediation: `node3` returned to `Ready`, `kubectl get helmcharts.helm.cattle.io -n kube-system` returned no resources, `kubectl get jobs -n kube-system | grep traefik` returned no resources, and the live K3s addon list no longer includes `traefik`.
- Prometheus-side validation after remediation: the Prometheus HTTP API returned empty vectors for `kube_job_failed{job="kube-state-metrics",namespace=~".*"} > 0`, `kube_job_failed{job_name=~"helm-install-traefik|helm-install-traefik-crd"}`, and `ALERTS{alertname="KubeJobFailed",job_name=~"helm-install-traefik|helm-install-traefik-crd"}`.

## Working Fixes
- Keep short, validated repair steps worth reusing.
- For `KubeJobFailed` alerts on `helm-install-traefik*`, first check whether a separate Traefik release already exists. If yes, inspect all K3s server nodes for mismatched `--disable traefik --disable servicelb` settings before deleting Jobs, because one server with the bundled addon enabled will recreate the `traefik` Addon and HelmCharts.

## Dependencies And Secrets
- Note Alertmanager receivers, storage expectations, ingress, and cluster-level scrape dependencies.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.
- Confirm where K3s server startup config is managed for this cluster, then disable bundled `traefik` there so the `HelmChart` resources stop reconciling.