# Raspberry Pi 4 Control Plane Replacement - K3S Rejoin Runbook

This runbook continues after board prep in `tutorials/rpi4-control-plane-replacement-prep.md`.

Fast-path command version:
- `tutorials/rpi4-control-plane-replacement-quick-commands.md`

Goal:
- safely reintroduce a replacement Raspberry Pi 4 as a K3S server (control-plane node)
- restore 3 control-plane members
- verify etcd and API high availability are healthy

---

## Scope and Safety

This procedure assumes:
- the failed node is offline
- the replacement node is already installed with Ubuntu and reachable by SSH
- static IP and hostname are stable

Do not proceed if the failed node may still come online with the same hostname/IP.

---

## Prerequisites

From your admin workstation:

- `kubectl` access to the cluster
- kubeconfig exported:

```bash
export KUBECONFIG=~/kube/k3s.yaml
```

- SSH access to:
  - one healthy existing control-plane node (recommended: `node1`)
  - the replacement Pi

- Cluster endpoint/VIP known:
  - `https://192.168.4.20:6443`

- Replacement node details known:
  - hostname (example: `node2`)
  - static IP (example: `192.168.4.115`)

---

## Step 1 - Confirm Current Cluster State

From admin workstation:

```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system -o wide
```

Expected:
- at least one healthy control-plane node is `Ready`
- API is reachable via current kubeconfig

If cluster API is unstable, stop and recover control-plane availability before adding nodes.

---

## Step 2 - Determine Replacement Mode

Choose one mode:

1. **Same identity replacement** (recommended):
   - replacement uses the same hostname/IP as failed node
   - minimizes config drift
2. **New identity replacement**:
   - replacement uses a new hostname and/or IP
   - requires updating inventory/docs and possibly node-specific operational references

For this homelab, same identity is usually best.

---

## Step 3 - Remove Stale Kubernetes Node Object (If Present)

If old node object still exists and is NotReady for the failed host:

```bash
kubectl get nodes
kubectl delete node <failed-node-name>
```

Example:

```bash
kubectl delete node node2
```

This removes stale scheduling metadata before rejoin.

---

## Step 4 - Remove Stale etcd Member (Critical)

If the failed control-plane node was a server member, remove the stale etcd member before rejoin.

SSH to healthy control-plane node (example `node1`):

```bash
ssh <user>@192.168.4.110
sudo -i
```

List etcd members:

```bash
export K3S_DATASTORE_ENDPOINT=''
export ETCDCTL_API=3
ETCDCTL_BIN="$(find /var/lib/rancher/k3s/data -type f -name etcdctl 2>/dev/null | sort | tail -n1)"
[ -x "$ETCDCTL_BIN" ] || ETCDCTL_BIN="$(command -v etcdctl || true)"
if [ ! -x "$ETCDCTL_BIN" ]; then
  ARCH="$(dpkg --print-architecture)"
  case "$ARCH" in
    arm64) ETCD_ARCH=arm64 ;;
    amd64) ETCD_ARCH=amd64 ;;
    *) ETCD_ARCH="" ;;
  esac

  if [ -n "$ETCD_ARCH" ]; then
    ETCD_VER="v3.5.15"
    TMP_DIR="$(mktemp -d)"
    curl -fsSL -o "$TMP_DIR/etcd.tar.gz" "https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-${ETCD_ARCH}.tar.gz"
    tar -xzf "$TMP_DIR/etcd.tar.gz" -C "$TMP_DIR"
    install -m 0755 "$TMP_DIR/etcd-${ETCD_VER}-linux-${ETCD_ARCH}/etcdctl" /usr/local/bin/etcdctl
    ETCDCTL_BIN="/usr/local/bin/etcdctl"
    rm -rf "$TMP_DIR"
  fi
fi

[ -x "$ETCDCTL_BIN" ] || { echo "etcdctl not found; install manually and retry"; }
[ -x "$ETCDCTL_BIN" ] && "$ETCDCTL_BIN" \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  --endpoints=https://127.0.0.1:2379 member list -w table
```

Identify the stale member by name/peer URL of the failed node, then remove it:

```bash
"$ETCDCTL_BIN" \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  --endpoints=https://127.0.0.1:2379 member remove <stale-member-id>
```

Re-list members to confirm stale member is gone.

---

## Step 5 - Retrieve K3S Server Token

On healthy control-plane node (`node1`):

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

Copy the token for the join command.

---

## Step 6 - Prepare Replacement Node for Join

SSH to replacement node:

```bash
ssh <user>@<replacement-node-ip>
sudo -i
```

Clean any previous partial K3S install if this host was reused:

```bash
if [ -x /usr/local/bin/k3s-uninstall.sh ]; then
  /usr/local/bin/k3s-uninstall.sh
fi

rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /etc/cni /opt/cni
```

Ensure time is synced and swap is off:

```bash
timedatectl status
swapon --show
```

If swap is still active, disable it before continuing.

---

## Step 7 - Join as K3S Server (Control Plane)

On replacement node, run:

```bash
# Use the same k3s version as existing control-plane nodes.
# Get this on node1:
# sudo k3s --version | awk '/^k3s version/ {print $3; exit}'
K3S_VERSION='<paste-version-from-node1>'

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="$K3S_VERSION" \
  K3S_URL=https://192.168.4.20:6443 \
  K3S_TOKEN='<paste-server-node-token>' \
  INSTALL_K3S_EXEC='server' \
  sh -
```

Then verify service:

```bash
sudo systemctl enable k3s
sudo systemctl status k3s --no-pager
```

Note:
- Use the VIP endpoint (`192.168.4.20`) so join is independent of any one server node.

---

## Step 8 - Validate Node Registration and Control-Plane Role

From admin workstation:

```bash
kubectl get nodes -o wide
kubectl describe node <replacement-node-name> | grep -E 'Roles|Taints|InternalIP'
```

Replace `<replacement-node-name>` with the real node name (example `node3`) to avoid shell parsing errors.

Expected:
- replacement node appears as `Ready`
- role includes control-plane/server semantics
- InternalIP matches intended static IP

---

## Step 9 - Validate etcd Membership and Health

On a healthy control-plane node (`node1`):

```bash
sudo -i
export ETCDCTL_API=3
ETCDCTL_BIN="$(find /var/lib/rancher/k3s/data -type f -name etcdctl 2>/dev/null | sort | tail -n1)"
[ -x "$ETCDCTL_BIN" ] || ETCDCTL_BIN="$(command -v etcdctl || true)"
if [ ! -x "$ETCDCTL_BIN" ]; then
  ARCH="$(dpkg --print-architecture)"
  case "$ARCH" in
    arm64) ETCD_ARCH=arm64 ;;
    amd64) ETCD_ARCH=amd64 ;;
    *) ETCD_ARCH="" ;;
  esac

  if [ -n "$ETCD_ARCH" ]; then
    ETCD_VER="v3.5.15"
    TMP_DIR="$(mktemp -d)"
    curl -fsSL -o "$TMP_DIR/etcd.tar.gz" "https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-${ETCD_ARCH}.tar.gz"
    tar -xzf "$TMP_DIR/etcd.tar.gz" -C "$TMP_DIR"
    install -m 0755 "$TMP_DIR/etcd-${ETCD_VER}-linux-${ETCD_ARCH}/etcdctl" /usr/local/bin/etcdctl
    ETCDCTL_BIN="/usr/local/bin/etcdctl"
    rm -rf "$TMP_DIR"
  fi
fi

[ -x "$ETCDCTL_BIN" ] || { echo "etcdctl not found; install manually and retry"; }
[ -x "$ETCDCTL_BIN" ] && "$ETCDCTL_BIN" \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  --endpoints=https://127.0.0.1:2379 member list -w table

"$ETCDCTL_BIN" \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  --endpoints=https://127.0.0.1:2379 endpoint health -w table
```

Expected:
- 3 etcd members present
- all endpoints report healthy

---

## Step 10 - Validate API HA Through VIP

From admin workstation, run repeated API checks against normal kubeconfig path:

```bash
for i in $(seq 1 10); do
  kubectl get --raw=/readyz >/dev/null && echo "ok $i" || echo "fail $i"
  sleep 2
done
```

Expected:
- no intermittent failures

Optional deeper check:

```bash
kubectl get componentstatuses 2>/dev/null || true
kubectl get pods -n kube-system -o wide
```

---

## Step 11 - Post-Recovery Hygiene

- Confirm failed hardware remains powered off or decommissioned.
- If replacement used same identity, update hardware serial/asset notes only.
- If replacement used new identity, update:
  - `HARDWARE.md`
  - any automation/inventory that depends on hostnames/IPs

---

## Step 12 - Optional Safe Scheduling Policy for RPi4 8GB Control Plane

Use this if you want selected lightweight workloads on control-plane nodes while keeping general workloads off those nodes by default.

1. Remove maintenance cordon state:

```bash
kubectl uncordon node1 node2 node3
```

2. Label the control-plane pool:

```bash
kubectl label node node1 node2 node3 \
  homelab.io/class=rpi4b-8gb \
  homelab.io/storage=usb-flash \
  homelab.io/pool=control \
  --overwrite
```

3. Apply a dedicated taint that blocks general scheduling:

```bash
kubectl taint node node1 node2 node3 homelab.io/control-infra=true:NoSchedule --overwrite
```

4. Verify labels and taints:

```bash
kubectl get nodes -L homelab.io/class,homelab.io/pool,homelab.io/storage
kubectl describe node node3 | grep -E 'Taints|Roles|InternalIP'
```

Workloads that are allowed on control-plane nodes should include both toleration and node affinity:

```yaml
tolerations:
  - key: homelab.io/control-infra
    operator: Equal
    value: "true"
    effect: NoSchedule
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: homelab.io/pool
              operator: In
              values: ["control"]
```

---

## Rollback / Break-Glass

If join fails repeatedly:

1. On replacement node:

```bash
sudo /usr/local/bin/k3s-uninstall.sh || true
sudo rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /etc/cni /opt/cni
```

2. Recheck:
- DNS/network reachability to `192.168.4.20:6443`
- token correctness
- clock sync and swap disabled

3. Re-run join command.

If etcd remains degraded after retries, stop and stabilize existing control-plane quorum before additional join attempts.

---

## Completion Criteria

Recovery is complete when all are true:

- 3 control-plane nodes are `Ready`
- replacement node is stable for at least 15 minutes
- etcd member list contains expected 3 members
- etcd endpoint health is green
- API readiness via VIP shows no flapping
