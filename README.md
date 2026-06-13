# Homelab - Kubernetes Cluster with GitOps

A production-ready Kubernetes homelab built on K3S with 3 control plane nodes and 2 worker nodes, managed entirely through GitOps using Argo CD.

## Working In This Repo

Repo-wide agent instructions live in [.github/copilot-instructions.md](.github/copilot-instructions.md). For cluster changes, start with this README and [HARDWARE.md](HARDWARE.md). For OpenWRT changes, start with [openwrt/README.md](openwrt/README.md).

## Cluster Overview

- **Orchestration**: Kubernetes 1.34.6+k3s1 (K3S lightweight distribution)
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
   └─ Netgear GS108PE PoE Switch
       ├─ Control Plane (3x RPi4)
       ├─ eldragon GPU Node
       ├─ orangepi5 Compute Node
       └─ UPS: APC Back-UPS Pro 1500VA
```

All nodes are configured with static IPs on the 192.168.4.0/24 subnet and connected via the managed switch.

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
- **Traefik**: Built-in ingress controller
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
- **Use Cases**: 
  - Persistent volumes for databases (PostgreSQL via CloudNativePG)
  - Redis cluster data persistence
  - Application state storage

## GitOps Workflow

This repository is managed as infrastructure-as-code using Argo CD. All cluster state is declaratively defined in Git.

### Repository Structure
```
homelab_dklair/
├── apps/                          # Application manifests organized by platform
│   └── argocd/                   # Argo CD Application resources
│       ├── open-webui-application.yaml
│       ├── postgresql-application.yaml
│       ├── redis-cluster-application.yaml
│       └── ...
├── values/                         # Helm values files for each application
│   ├── open-webui/
│   ├── postgresql/
│   ├── redis-cluster/
│   └── ...
├── application-template.yaml       # Template for new applications
├── HARDWARE.md                     # Detailed hardware specifications
└── tutorials/                      # Deployment guides and documentation
```

From time to time the cluster will require troubleshooting using an LLM. To prepare context for LLM analysis:

```bash
npx repomix ~/homelab_dklair # Generate single markdown file for upload
```

This consolidates the repo into a single file suitable for LLM prompts. All content is public and can be uploaded.

## Deploying Applications with GitOps

All applications are deployed through Argo CD using a two-file pattern: a Helm values file and an Argo CD Application manifest.

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
