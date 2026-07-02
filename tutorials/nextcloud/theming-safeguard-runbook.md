# Nextcloud Theming Safeguard Runbook

## Purpose

Prevent post-login HTTP 500 errors on dashboard and TOTP challenge routes that can occur when Nextcloud theming color values are invalid or empty.

## Owning Configuration

- Argo CD app: [apps/argocd/nextcloud-application.yaml](../../apps/argocd/nextcloud-application.yaml)
- Helm values: [values/nextcloud/values.yaml](../../values/nextcloud/values.yaml)

The safeguard is implemented with chart-native Nextcloud hooks:

- post-installation
- post-upgrade

These hooks enforce:

- disable-user-theming = yes
- color = #0082c9
- background_color = #0082c9

## Prerequisites

- Access to the cluster with kubectl
- KUBECONFIG set to your cluster config (for this repo, usually ~/kube/k3s.yaml)
- Argo CD application nextcloud exists in namespace argocd

## Verification

1. Confirm Argo app status:

```bash
kubectl get application nextcloud -n argocd
```

2. Confirm hooks are present in deployed values and pod mounts:

```bash
kubectl get deploy -n nextcloud nextcloud -o yaml | grep -n "docker-entrypoint-hooks.d" -n
```

3. Confirm runtime theming values:

```bash
kubectl exec -n nextcloud deploy/nextcloud -c nextcloud -- php occ config:app:get theming disable-user-theming
kubectl exec -n nextcloud deploy/nextcloud -c nextcloud -- php occ config:app:get theming color
kubectl exec -n nextcloud deploy/nextcloud -c nextcloud -- php occ config:app:get theming background_color
```

Expected:

- yes
- #0082c9
- #0082c9

## Troubleshooting

If login succeeds but redirect to dashboard or TOTP challenge returns HTTP 500:

1. Check Nextcloud application logs for theming TypeError:

```bash
kubectl exec -n nextcloud deploy/nextcloud -c nextcloud -- sh -lc "grep -E 'ThemingDefaults.php|preg_match\(\): Argument #2|/apps/dashboard/|/login/challenge/totp' /var/www/html/data/nextcloud.log | tail -n 40"
```

2. Re-apply safe values manually (temporary remediation):

```bash
kubectl exec -n nextcloud deploy/nextcloud -c nextcloud -- php occ config:app:set theming disable-user-theming --value='yes'
kubectl exec -n nextcloud deploy/nextcloud -c nextcloud -- php occ config:app:set theming color --value='#0082c9'
kubectl exec -n nextcloud deploy/nextcloud -c nextcloud -- php occ config:app:set theming background_color --value='#0082c9'
```

3. If manual remediation works, verify Git state for hooks in [values/nextcloud/values.yaml](../../values/nextcloud/values.yaml) and sync Argo CD.

## Rollback or Cleanup

If this safeguard must be reverted:

1. Remove or modify hook entries in [values/nextcloud/values.yaml](../../values/nextcloud/values.yaml).
2. Commit and sync Argo CD.
3. Validate post-login routes after rollback.

Only revert if a chart release introduces a documented incompatibility with nextcloud.hooks.
