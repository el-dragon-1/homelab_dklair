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
- Prometheus uses a 10 GiB Longhorn PVC with 7-day and `6GB` block-retention
  limits, whichever is reached first. WAL/head data consumes additional space;
  the block limit is not a total-disk quota. Monitor free space and actual
  retention as ingestion changes. Prometheus reports the size flag as `6GiB`.
  The Longhorn three-replica target is retained.
- Summarize namespace, scrape scope, Alertmanager routing, storage, and ingress or dashboard exposure after the next validated review.
- Prometheus and Alertmanager ingress use Traefik ingress class `my-traefik`.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, alert-routing mistakes, missing metrics, and PVC or retention issues.

## Troubleshooting History
- 2026-10-23: Owner subsequently authorized another history reset and downsizing
  to 10 GiB with 7-day / `6GB` retention. Observed approximately 11,360 samples/sec
  and 327,000 active series; daily disk growth was not yet measurable after the
  earlier reset. Rendered chart 78.5.0 and server-side dry-run validated the
  Prometheus resource. Disabled automatic sync temporarily, stopped Prometheus,
  paused operator reconciliation, and recreated its StatefulSet (immutable claim
  template) and PVC. Restored reconciliation and one Prometheus instance.
  New PV `pvc-154244ad-4fcf-4b47-b7f2-6d8302fc8d1e` was attached/healthy
  with three running replicas on `eldragon`, `node1`, and `node3`.
  Verified advancing sample timestamps over 35 seconds, 30 targets up, and
  runtime retention flags of `1w` / `6GiB`. No other application's PVC was reset.
- 2026-10-23: Active 40 GiB PV `pvc-24f2fdfb-ee9d-4c3f-bdc6-31c808bde97c`
  was faulted/detached with both remaining replicas failed since September 19.
  Pod readiness was misleading: Prometheus logged WAL input/output errors and
  failed scrape commits. The original failure cause was not established.
  The owner explicitly authorized discarding Prometheus history. Temporarily
  disabled Argo automatic sync, set the Prometheus CR replicas to zero, waited
  for pod termination, deleted only its verified PVC, and waited for old PV and
  Longhorn volume deletion. Restored one Prometheus instance and original Argo
  automatic-sync settings. New 40 GiB PV:
  `pvc-e96aafb2-450b-4ee6-8787-5030c05ce607`.
  Verified advancing `max(timestamp(up))` across two observations 35 seconds
  apart, with 30 targets up at the latter observation; Argo reported Synced/Healthy.
  After that reset storage remained degraded: one running replica on `eldragon`, two unscheduled
  replicas due to insufficient capacity. The three-replica target was preserved;
  application recovery does not mean storage redundancy is restored.
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