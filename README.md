# Homelab - Kubernetes Cluster with GitOps

A production-ready Kubernetes homelab built on K3S with 3 control plane nodes and 2 worker nodes, managed entirely through GitOps using Argo CD.

## Working In This Repo

Repo-wide agent instructions live in [.github/copilot-instructions.md](.github/copilot-instructions.md). For cluster changes, start with this README and [HARDWARE.md](HARDWARE.md). For OpenWRT changes, start with [openwrt/README.md](openwrt/README.md).

## Cluster Overview

- **Orchestration**: Kubernetes 1.36.2+k3s1 (K3S lightweight distribution)
- **High Availability**: 3-node control plane with KubeVIP virtual IP (192.168.4.20)
- **Load Balancing**: KubeVIP v1.0.0 for control plane HA and ingress LB
- **Networking**: Flannel CNI with 192.168.4.0/24 VLAN
- **Storage**: Longhorn v4.9.0 distributed storage across all nodes
- **GitOps**: Argo CD for declarative infrastructure and application management
- **Container Runtime**: containerd via K3S

## Hardware Architecture

For detailed hardware specifications and node configurations, see [HARDWARE.md](HARDWARE.md).

### Control Plane (3x Raspberry Pi 4 8GB)
- **node1** (192.168.4.110): Primary etcd leader, API server
- **node2** (192.168.4.115): etcd member, scheduler
- **node3** (192.168.4.116): etcd member, controller manager
- **Virtual IP**: 192.168.4.20 (KubeVIP-managed endpoint)

### Worker Nodes (2)
- **eldragon** (192.168.4.213): GPU compute node (NVIDIA RTX 4060, 64GB RAM, Intel Xeon)
- **orangepi5** (192.168.4.84): General compute node (8x ARM cores, 8GB RAM, NPU 6 TOPS)

## Network Topology

```
Internet
   ↓
Cloudflare DNS & Routes
   ↓
Bananapi R3 Gateway (OpenWRT) - 192.168.4.1
   ├─ Bananapi R3 AP (OpenWRT, 5GHz mesh backhaul)
   ├─ Cudy M3000 hades (OpenWRT AP)
   ├─ Cudy M3000 gemini (OpenWRT AP)
   │  └─ Netgear GS108PE PoE Switch
   │     ├─ Control Plane (3x RPi4)
   │     ├─ eldragon GPU Node
   │     ├─ orangepi5 Compute Node
   │     └─ UPS: APC Back-UPS Pro 1500VA
   └─ Cudy M3000 orchid (OpenWRT mesh AP)
```

All nodes and OpenWRT devices are configured with static IPs on the 192.168.4.0/24 subnet, with the managed switch uplinked through Gemini and remote links carried over mesh backhaul where applicable.

## KubeVIP Architecture

KubeVIP provides both control plane HA and load balancing for the cluster:

### Control Plane HA
- **Virtual IP**: 192.168.4.20
- **Endpoint**: Dynamically managed across all 3 control plane nodes
- **Mode**: Leader election for HA failover
- **Use Case**: Ensures Kubernetes API server remains available if any control node fails

### Ingress Load Balancing
- Manages virtual IPs for Ingress and LoadBalancer services
- Routes external traffic through Traefik ingress controller
- Integrates with Longhorn persistent volume endpoints

## K3S Architecture

### K3S Components
K3S is a minimal Kubernetes distribution that includes:
- **containerd**: Container runtime (replaces Docker daemon)
- **Flannel**: Default CNI for pod networking
- **Traefik**: Built-in addon is disabled; ingress is provided by a separately managed Traefik deployment
- **CoreDNS**: Service DNS discovery

### Deployment Model
- **Server Nodes** (Control Plane): Run API server, controller manager, scheduler, and etcd
- **Agent Nodes** (Workers): Run kubelet and kube-proxy for workload execution
- **Single Binary**: K3S runs as a single systemd service per node

### Data Path
```
Applications (Pods)
   ↓ (kubelet)
Node Agent (containerd runtime)
   ↓ (CNI plugin)
Flannel Network Plugin
   ↓ (routing)
Inter-node Communication & External Network
```

## Storage Architecture

### Longhorn Distributed Storage
- **Version**: v4.9.0
- **Replica Factor**: 5 copies across cluster
- **Storage Nodes**: All 5 nodes (node1, node2, node3, eldragon, orangepi5)
- **Backend Storage**: NVMe/SSD on each node
- **GitOps Management**: Argo CD app at `apps/argocd/longhorn-application.yaml` with values in `values/longhorn/values.yaml`
- **Operations Runbook**: `tutorials/longhorn/all-node-health-checks.md`
- **Use Cases**: 
  - Persistent volumes for databases (PostgreSQL via CloudNativePG)
  - Redis cluster data persistence
  - Application state storage

## GitOps Workflow

This repository is managed as infrastructure-as-code using Argo CD. All cluster state is declaratively defined in Git.

### Repository Structure
```
homelab_dklair/
├── .github/
│   ├── copilot-instructions.md                # Repo guidance entrypoint
│   └── instructions/                           # File-scoped Copilot instructions
├── .vscode/
│   └── mcp.json                                # VS Code MCP configuration
├── apps/                                       # Kubernetes manifests
│   ├── argocd/                                 # Argo CD Application resources
│   ├── baserow/                                # App-specific manifests
│   ├── cert-manager/
│   ├── external-secrets-config/
│   ├── nextcloud/
│   └── openwrt-ops/
├── openwrt/
│   ├── baseline/                               # Evidence snapshot (read-only reference)
│   ├── desired/                                # Enforced desired OpenWRT state
│   └── README.md
├── scripts/
│   ├── check-openwebui-gpu-post-update.sh
│   ├── check-openwebui-runtime-health.sh
│   ├── provision-authentik-db-from-secrets.sh
│   └── provision-baserow-db-from-secrets.sh
├── tutorials/
│   ├── argocd/
│   ├── cloudflare/
│   ├── longhorn/
│   ├── nextcloud/
│   ├── openwrt/
│   └── readme-images/
├── values/                                     # Helm values and app context files
│   ├── argocd/
│   ├── authentik/
│   ├── cloudnativepg/
│   ├── open-webui/
│   ├── postgresql/
│   └── ...
├── application-template.yaml                   # Template for new Argo CD applications
├── root-application.yaml                       # Root app-of-apps definition
├── HARDWARE.md                                 # Hardware and OpenWRT device inventory
└── README.md
```

### Per-App Copilot Context

Each application directory under `values/<app>/` may include a `context.md` companion file.

Use that file to preserve the distilled outcome of meaningful Copilot build and troubleshooting chats for the app:
- current deployment shape and important repo anchors
- recurring failures, misleading symptoms, and working fixes
- validated decisions worth carrying forward into future sessions

Keep these files concise and update them with durable conclusions, not raw chat transcripts.

### Longhorn Runbook Trigger Points

Run `tutorials/longhorn/all-node-health-checks.md` after any of the following:

- Longhorn chart/version changes
- Node taint or node-selector changes
- Argo CD syncs that modify Longhorn resources
- Alerts related to Longhorn DaemonSet rollout or storage health

## Deploying Applications with GitOps

All applications are deployed through Argo CD using a two-file pattern: a Helm values file and an Argo CD Application manifest.

### Pre-Deployment Review

Before adding or updating an app, review the upstream Helm chart first and confirm the deployment model fits this cluster.

- Check whether the chart creates its own database, ingress, persistence, or other stateful controllers that need explicit disabling.
- Confirm whether the workload can safely run with multiple replicas before treating it as HA.
- Prefer ARM64 scheduling when the image supports it, since most worker capacity in this cluster is ARM64.
- If the image requires AMD64, keep the workload to a single replica and pin it to the appropriate AMD64 node or node pool.
- Keep app-specific overrides in [values/<app-name>/values.yaml](values/) and preserve the repo's two-source Argo CD pattern.
- For database-backed apps, prefer the shared PostgreSQL instance unless there is a clear isolation or performance requirement.
- If a database is needed, run [scripts/onboard-app-postgres-from-vault.sh](scripts/onboard-app-postgres-from-vault.sh) after chart review to guide Vault secret updates, ExternalSecret sync, PostgreSQL role/database provisioning, commit/push, and root application sync in the expected order.

Non-interactive example:

```bash
APP_NAME=paperless \
APP_NAMESPACE=paperless \
APP_DB=paperless \
APP_SECRET=paperless-db \
APP_USER_KEY=DATABASE_USER \
APP_PASSWORD_KEY=DATABASE_PASSWORD \
VAULT_PATH=homelab/paperless/postgresql \
VAULT_USER_FIELD=username \
VAULT_PASSWORD_FIELD=password \
VAULT_DB_FIELD=database \
VAULT_DB_USER=paperless \
VAULT_DB_PASSWORD='REPLACE_ME' \
EXTERNAL_SECRETS_APP=external-secrets-config \
ROOT_APP=root \
PG_NAMESPACE=postgresql \
PG_HOST=postgresql-rw.postgresql.svc.cluster.local \
APP_SYNC_TIMEOUT=300 \
./scripts/onboard-app-postgres-from-vault.sh
```

Set `VAULT_DB_PASSWORD` from a secure source in CI and avoid hardcoding secrets in shell history.

The goal is to catch chart-level deployment requirements before the app is synced, rather than discovering them after rollout.

### Open WebUI Post-Update GPU Checks

After updating Open WebUI or Ollama values, run the post-update validation script:

./scripts/check-openwebui-gpu-post-update.sh

This verifies:
- Argo CD app sync and health for open-webui
- Ollama deployment rollout and service endpoints
- GPU resource request, runtime class, and CPU cap in deployment spec
- Ollama throttling env settings (`OLLAMA_NUM_PARALLEL`, `OLLAMA_MAX_LOADED_MODELS`)
- NVIDIA device visibility in the Ollama container
- A short inference run and GPU processor usage via ollama ps

### Nextcloud Post-Install/Upgrade Safeguard

Nextcloud safeguard details and troubleshooting are documented in [tutorials/nextcloud/theming-safeguard-runbook.md](tutorials/nextcloud/theming-safeguard-runbook.md).

### Authentik Bootstrap

Authentik uses the shared PostgreSQL instance and bootstrap credentials from Vault-synced secrets. Before the first sync, run [scripts/provision-authentik-db-from-secrets.sh](scripts/provision-authentik-db-from-secrets.sh) so the Authentik role and database exist in PostgreSQL.

### Repository Standards

- Deploy Kubernetes applications as Helm charts.
- Store customization only in per-app values files at `values/<app-name>/values.yaml`.
- For new applications requiring a database, reuse the existing PostgreSQL instance (CloudNativePG) instead of deploying a separate database by default.
- Only create a dedicated database instance when there is a clear isolation or performance requirement.

### OpenWRT Ops Runtime Guardrails

The `openwrt-ops` CronJobs include runtime safeguards to prevent stale long-running jobs from degrading application health:

- `activeDeadlineSeconds: 900` (hard 15-minute runtime cap)
- `ttlSecondsAfterFinished: 600` (cleanup finished Jobs after 10 minutes)

Argo CD is configured with a CronJob health customization (`resource.customizations.health.batch_CronJob`) in [tutorials/argocd/values.yaml](tutorials/argocd/values.yaml) so `openwrt-ops` health reflects operational state accurately.

### Application Deployment Pattern

#### 1. Create Values File

Create a new values file at `values/<app-name>/values.yaml` with application-specific overrides:

```yaml
# Example: values/whoami/values.yaml
replicaCount: 1

image:
  repository: traefik/whoami
  pullPolicy: IfNotPresent

ingress:
  enabled: true
  className: 'my-traefik'
  annotations: {}
  hosts:
    - host: whoami.dklair.io
      paths:
        - path: /
          pathType: ImplementationSpecific
```

**Values File Sections:**
- **replicaCount**: Number of pod replicas for the deployment
- **image**: Container image repository and pull policy
- **ingress**: Traefik ingress configuration for external access
  - Set `className: 'my-traefik'` for all apps (cluster standard)
  - Configure DNS hostnames matching your Cloudflare application routes
  - For domain setup details, see [cloudflare application routes guide](tutorials/cloudflare/application-routes/configure-app-routes.md)
- **database**: Prefer connection settings that point to the shared PostgreSQL cluster (host/db/user/password from Kubernetes Secret via External Secrets)

#### 2. Create Application Manifest

Create an Argo CD Application at `apps/argocd/<app-name>-application.yaml` using the template:

```yaml
# Example: apps/argocd/whoami-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: whoami
  namespace: argocd
  annotations:
    argocd.argoproj.io/managed-by-cluster-argocd: argocd
    argocd.argoproj.io/sync-wave: "1"  # Controls deployment order
  finalizers:
    - resources-finalizer.argocd.argoproj.io  # Ensures proper cleanup
spec:
  destination:
    namespace: whoami  # Target namespace for app
    server: https://kubernetes.default.svc
  sources:
    - repoURL: https://<helm-repo-url>/  # Helm chart repository
      chart: whoami                        # Chart name
      targetRevision: 0.1.2               # Chart version to deploy
      helm:
        valueFiles:
          - $values/values/whoami/values.yaml  # Points to values file
    - repoURL: https://github.com/el-dragon-1/homelab_dklair.git
      targetRevision: HEAD
      ref: values  # Enables $values variable substitution
  project: default
  syncPolicy:
    automated:
      prune: true          # Delete resources removed from Git
      selfHeal: true       # Correct drift from desired state
      allowEmpty: false    # Prevent accidental deletion
    syncOptions:
      - CreateNamespace=true  # Auto-create namespace if missing
```

**Important Fields:**
- **sync-wave annotation**: Controls deployment order (lower values deploy first)
- **sources[0]**: Helm chart repository URL and chart details
- **sources[1]**: This repository (enables values file reference via `$values`)
- **syncPolicy.automated**: Keeps cluster in sync with Git state

#### 3. Deploy the Application

Register the application with the cluster:

```bash
kubectl apply -f apps/argocd/whoami-application.yaml -n argocd
```

> **Note**: Apply via `kubectl` instead of the Argo CD UI because the UI reverts multi-source configurations to single-source.

#### 4. Monitor Deployment

Check application status in Argo CD:

```bash
kubectl get application -n argocd
```

Visit the Argo CD UI (typically `argocd.dklair.io`) to view sync status, resource tree, and logs.

**Expected Resource Deployment:**
- Application resource → deployed to `argocd` namespace
- All other resources → deployed to target namespace (e.g., `whoami`)

#### Using the Application Template

Start new applications from the template:

```bash
cp application-template.yaml apps/argocd/<app-name>-application.yaml
# Edit: update name, namespace, chart, and values file path
```

Then create the corresponding values directory:

```bash
mkdir -p values/<app-name>
# Create values/<app-name>/values.yaml
```

### Sync Waves for Deployment Ordering

Control application deployment order using sync-wave annotations:

```yaml
annotations:
  argocd.argoproj.io/sync-wave: "0"   # Deploy first (infrastructure)
```

```yaml
annotations:
  argocd.argoproj.io/sync-wave: "3"   # Deploy after wave 0, 1, 2
```

**Current Wave Structure:**
- Wave 0-1: Cert Manager and infrastructure
- Wave 2-3: Storage (Longhorn, PostgreSQL)
- Wave 4+: Applications (Open WebUI, etc.)

### Accessing Deployed Applications

All applications are exposed through Traefik ingress at your configured domain:

```
https://<app-name>.dklair.io
```

This requires:
1. DNS routing configured in Cloudflare
2. Ingress resource created by Helm chart
3. Traefik ingress controller routing traffic

See [cloudflare application routes guide](tutorials/cloudflare/application-routes/configure-app-routes.md) for complete network setup.

### Troubleshooting Applications

**View application status:**
```bash
kubectl describe application <app-name> -n argocd
```

**Check sync status:**
```bash
kubectl get application -n argocd -o wide
```

**View application logs:**
```bash
kubectl logs -n <app-namespace> -l app=<app-name>
```

**Manually sync if auto-sync is disabled:**
```bash
argocd app sync <app-name>
```

## WireGuard VPN Setup

This repository includes a WireGuard VPN application using the same GitOps pattern described above:

- Argo CD Application: `apps/argocd/wireguard-application.yaml`
- Helm values: `values/wireguard/values.yaml`

### 1. Configure WireGuard Server Config

This setup is Vault-native and uses External Secrets instead of storing WireGuard config in Git.

Create a Vault KV secret at:

- `homelab/wireguard/wireguard-config`
- Property: `wg0_config`
- Value: full plaintext `wg0.conf` contents (multi-line)

The ExternalSecret manifest at `apps/external-secrets-config/wireguard-config-externalsecret.yaml` syncs this into Kubernetes Secret `wireguard-config` in namespace `wireguard`.

### 2. Deploy Through GitOps (Root Application)

Do not apply WireGuard manifests directly with `kubectl`.

Commit and push these files to the repository:

- `apps/argocd/wireguard-application.yaml`
- `apps/external-secrets-config/wireguard-config-externalsecret.yaml`
- `values/wireguard/values.yaml`

Deployment flow:

- Root Argo CD app (`root`) reconciles `apps/argocd/*` and creates the `wireguard` Argo CD application.
- `external-secrets-config` Argo CD app reconciles `apps/external-secrets-config/*` and creates the WireGuard ExternalSecret.
- External Secrets Operator syncs Vault key `homelab/wireguard/wireguard-config` into Kubernetes Secret `wireguard-config`.
- WireGuard chart mounts `wireguard-config` as `/etc/wireguard/wg0.conf`.

### 3. Verify Service and External IP

The WireGuard service is exposed as `LoadBalancer` on UDP `51820`.

```bash
kubectl get svc -n wireguard
kubectl get pods -n wireguard
kubectl get externalsecret -n wireguard
kubectl get secret wireguard-config -n wireguard
```

If your router/firewall is not already configured, forward UDP `51820` to the service external IP.
