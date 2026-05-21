# OpenWRT GitOps Bootstrap (Gateway + AP)

This setup introduces OpenWRT fleet automation with Argo CD, Vault, External Secrets, and Ansible.

## What This Deploys

- Namespace: `openwrt-ops`
- 2 ExternalSecrets:
  - `openwrt-gateway-auth`
  - `openwrt-ap-auth`
- 2 CronJobs:
  - `openwrt-gateway-reconcile`
  - `openwrt-ap-reconcile`
- Shared Ansible playbook in ConfigMap

The CronJobs run in `audit` mode by default so no configuration changes are pushed yet.

## Vault Paths and Required Properties

Ensure these KV v2 paths exist under your configured mount/path:

- `homelab/openwrt/gateway` for all gateway secrets
- `homelab/openwrt/ap` for all AP secrets

Each path must contain:

- `homelab/openwrt/gateway`
  - `host`
  - `port`
  - `username`
  - `ssh_private_key`
  - `mesh_key`
  - `openwrt_ssid_key`
  - `smz_guest_ssid_key`
- `homelab/openwrt/ap`
  - `host`
  - `port`
  - `username`
  - `ssh_private_key`
  - `mesh_key`
  - `smz_homex_ssid_key`

The UCI files in `openwrt/baseline/.../wireless.uci` already use these placeholder names, so the playbook can inject them from Vault at runtime.

## Apply with Argo CD

Apply the Argo CD application:

```bash
kubectl apply -f apps/argocd/openwrt-ops-application.yaml -n argocd
```

## Validate

Check generated secrets and jobs:

```bash
kubectl get externalsecret -n openwrt-ops
kubectl get secret -n openwrt-ops | grep openwrt
kubectl get cronjob -n openwrt-ops
```

Inspect a run:

```bash
kubectl get jobs -n openwrt-ops
kubectl logs -n openwrt-ops job/<job-name>
```

## Move from Audit to Enforce

In each CronJob manifest, change:

- `OPENWRT_MODE` from `audit` to `enforce`

Current enforce logic only sets hostname with UCI and commits `system`.

Expand the playbook gradually (firewall, DHCP, wireless) after validation.

## Repository Standards Reminder

This OpenWRT automation follows the same repository-wide GitOps standards in [README.md](../../README.md):

- Kubernetes applications should be deployed from Helm charts.
- Customization should live in `values/<app-name>/values.yaml`.
- New applications that require a database should use the existing PostgreSQL instance by default.

## Suggested Repo Layout

Keep the raw router exports local, and commit only sanitized desired state.

```text
openwrt/
  baseline/
    gateway/
      system.uci
      network.uci
      dhcp.uci
      firewall.uci
      wireless.uci
    ap/
      system.uci
      network.uci
      dhcp.uci
      firewall.uci
      wireless.uci

  desired/
    gateway/
      system.uci
      network.uci
      dhcp.uci
      firewall.uci
      wireless.uci
    ap/
      system.uci
      network.uci
      dhcp.uci
      firewall.uci
      wireless.uci
```

### Mapping Your Current Files

Use these as the starting point for the sanitized `baseline/` or `desired/` tree:

- `/tmp/openwrt-baseline/gateway-system.uci` -> `openwrt/baseline/gateway/system.uci`
- `/tmp/openwrt-baseline/gateway-network.uci` -> `openwrt/baseline/gateway/network.uci`
- `/tmp/openwrt-baseline/gateway-dhcp.uci` -> `openwrt/baseline/gateway/dhcp.uci`
- `/tmp/openwrt-baseline/gateway-firewall.uci` -> `openwrt/baseline/gateway/firewall.uci`
- `/tmp/openwrt-baseline/gateway-wireless.uci` -> `openwrt/baseline/gateway/wireless.uci`
- `/tmp/openwrt-baseline/ap-system.uci` -> `openwrt/baseline/ap/system.uci`
- `/tmp/openwrt-baseline/ap-network.uci` -> `openwrt/baseline/ap/network.uci`
- `/tmp/openwrt-baseline/ap-dhcp.uci` -> `openwrt/baseline/ap/dhcp.uci`
- `/tmp/openwrt-baseline/ap-firewall.uci` -> `openwrt/baseline/ap/firewall.uci`
- `/tmp/openwrt-baseline/ap-wireless.uci` -> `openwrt/baseline/ap/wireless.uci`

The same filenames should be reused under `openwrt/desired/` once you have converted the baseline into the state you actually want GitOps to enforce.

### What Stays Out of Git

Do not commit raw exports or secrets such as:

- wireless PSKs and mesh keys
- password fields
- private keys
- tokens or API secrets

Store those in Vault and inject them through the OpenWRT automation at runtime.