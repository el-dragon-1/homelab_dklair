# Cloudflared Context

## Adoption Baseline

- Inspected on `K3S` on 2026-10-22; live adoption has not yet been performed.
- Existing Deployment: `default/cloudflared`, three replicas, immutable selector
  `app: cloudflared`. Preserve the name, namespace, and selector during adoption.
- Existing ConfigMap: `default/cloudflared`, key `config.yaml`.
- Existing Secret: `default/tunnel-credentials`, key `credentials.json`.
  The chart references but does not manage this Secret. Vault credential comparison
  was performed in memory without printing or writing credential values to disk.
- Tunnel name: `k3s`; locally managed with a credentials JSON file, not a tunnel token.
- Existing route: `*.dklair.io` to `http://my-traefik.default.svc.cluster.local:80`,
  followed by `http_status:404`. Cloudflare DNS and Access policies remain external.
- Pinned image digest was observed on all three existing pods across ARM64 and
  AMD64 nodes. Adoption does not intentionally upgrade the running binary.
- A local Helm chart avoids the community chart's incompatible immutable selector
  and additional certificate configuration. No database, persistence, Service,
  ingress resource, or controller is needed.
- The readiness probe and zero-unavailable rolling strategy gate replacement pods
  on an active Cloudflare connection. The existing liveness settings are retained;
  high historical restart counts were observed but not investigated in this adoption.

## Validation

- `helm lint charts/cloudflared -f values/cloudflared/values.yaml`: passed.
- Rendered Deployment and ConfigMap: Kubernetes server-side apply dry run passed
  against the existing resources on `K3S`.
- Application manifest: server-side dry run passed against the Argo CD CRD.
- Vault credential check on 2026-10-22: KV v2 mount `homelab`, path
  `cloudflare/tunnel`, property `credential_json` (singular). Its JSON contains the
  required nonempty fields and matches the existing Kubernetes credential.
  The previously suggested `cloudflared/tunnel` path does not exist.
- The proposed ExternalSecret mapping `homelab/cloudflare/tunnel` /
  `credential_json` to `default/tunnel-credentials` / `credentials.json`, using
  `vault-backend` and `creationPolicy: Orphan`, passed a server-side dry run.
  No ExternalSecret has been created or added to Git for this tunnel yet; actual
  ESO reconciliation and its authorization to this entry remain unverified.
- `cloudflared tunnel --config /etc/cloudflared/config/config.yaml ingress validate`
  returned `OK` in the running Deployment. Helm-rendered configuration matches the
  validated live configuration. All three existing connector replicas were ready.
- The local Vault CLI address was stale (`192.168.4.102:8200`); a per-command
  override to the current `vault-ui` address `http://192.168.4.103:8200` allowed
  authenticated reads. No saved client settings were changed.
- Live reconciliation and external routing still require publishing the files and
  completing the [adoption runbook](../../tutorials/cloudflare/argocd-tunnel-adoption.md).