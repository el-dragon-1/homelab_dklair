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

- `homelab/openwrt/gateway`
- `homelab/openwrt/ap`

Each path must contain:

- `host`
- `port`
- `username`
- `ssh_private_key`

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