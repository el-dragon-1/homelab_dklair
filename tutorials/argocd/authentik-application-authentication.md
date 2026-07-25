# Authentik Application Authentication With Traefik

Use this runbook to protect application ingress endpoints with Authentik using Traefik forward-auth middleware.

## Owning Configuration

- Authentik Argo CD app: [apps/argocd/authentik-application.yaml](../../apps/argocd/authentik-application.yaml)
3. Re-test direct access to ensure the app is reachable without Authentik.
   - Re-check policy order in Authentik.

## Rollback

1. Remove authentik-authentik-forward-auth@kubernetescrd from the app ingress middleware annotation.
2. Sync the app in Argo CD.
3. Re-test direct app access.# Authentik Application Authentication With Traefik

Use this runbook to protect an application ingress with Authentik authentication by attaching a Traefik forward-auth middleware.

## Owning Configuration

- Authentik Argo CD app: [apps/argocd/authentik-application.yaml](../../apps/argocd/authentik-application.yaml)
- Authentik values: [values/authentik/values.yaml](../../values/authentik/values.yaml)
- Forward-auth middleware: [apps/external-secrets-config/authentik-forward-auth-middleware.yaml](../../apps/external-secrets-config/authentik-forward-auth-middleware.yaml)

## Prerequisites

1. Authentik application is healthy in Argo CD.
2. Traefik is the ingress controller for the target app.
3. You can sign in to the Authentik admin UI at `https://authentik.dklair.io`.
4. `kubectl` access is configured for this cluster (usually `KUBECONFIG=~/kube/k3s.yaml` in this repo).

## Step 1: Ensure Forward-Auth Middleware Exists

1. Confirm the middleware resource is present in Git:

```bash
ls apps/external-secrets-config/authentik-forward-auth-middleware.yaml
```

2. Sync `external-secrets-config` if needed:

```bash
kubectl patch application external-secrets-config -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
kubectl get middleware -n authentik authentik-forward-auth
```

Expected: middleware `authentik-forward-auth` exists in namespace `authentik`.

## Step 2: Configure Authentik Provider And Application

1. In Authentik, create a **Proxy Provider** for your target app.
2. Set the external host to the app hostname (example: `https://whoami.dklair.io`).
3. Create an **Application** and bind it to the provider.
4. Add policy/group bindings so only the intended users can access the app.

Note: Authentik owns who can sign in; Traefik only delegates auth checks to Authentik.

## Step 3: Attach Middleware To Target App Ingress

Add the middleware annotation to the target application's values file ingress annotations:

```yaml
ingress:
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: "authentik-authentik-forward-auth@kubernetescrd"
```

If the app already uses one middleware, comma-separate them in one annotation value:

```yaml
ingress:
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: "nextcloud-nextcloud-security-headers@kubernetescrd,authentik-authentik-forward-auth@kubernetescrd"
```

## Step 4: Deploy And Verify

1. Commit and sync the target Argo CD application.
2. Open the protected app URL in a private browser session.
3. Confirm redirect to Authentik login.
4. Sign in as an allowed user and confirm app access.
5. Sign in as a denied user and confirm access is blocked.

Cluster-side checks:

```bash
kubectl get application -n argocd <app-name>
kubectl describe ingress -n <app-namespace> <ingress-name>
kubectl get middleware -n authentik authentik-forward-auth -o yaml
```

## Troubleshooting

1. Redirect loop:
   - Confirm the Authentik provider external URL exactly matches the app hostname and scheme.
   - Confirm app DNS points to Traefik and TLS is valid.

2. Middleware not applied:
   - Confirm annotation key is `traefik.ingress.kubernetes.io/router.middlewares`.
   - Confirm namespace-qualified middleware reference is `authentik-authentik-forward-auth@kubernetescrd`.

3. User always denied:
   - Check Authentik application policy/group bindings.
   - Validate user membership and policy evaluation order in Authentik.

## Rollback

1. Remove `authentik-authentik-forward-auth@kubernetescrd` from the target app ingress middleware annotation.
2. Sync the target app in Argo CD.
3. Re-test direct access to ensure the app is reachable without Authentik.