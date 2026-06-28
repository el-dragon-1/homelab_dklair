# Raspberry Pi 4 Control Plane Replacement - Quick Command Sheet

Use this during an outage for copy/paste commands only.

Detailed runbooks:
- `tutorials/rpi4-control-plane-replacement-prep.md`
- `tutorials/rpi4-control-plane-rejoin-runbook.md`

---

## 0) Set Variables (Admin Workstation)

```bash
export KUBECONFIG=~/kube/k3s.yaml

# Edit these before running other commands
export FAILED_NODE_NAME=node3
export FAILED_NODE_IP=192.168.4.116
export REPLACEMENT_NODE_IP=192.168.4.116
export HEALTHY_CP_IP=192.168.4.110
export HEALTHY_CP_USER=dpolizzi
export REPLACEMENT_USER=dpolizzi
export K3S_VIP=192.168.4.20
# Must match the running cluster server version; set this after logging into node1.
export K3S_VERSION=
```

---

## 1) Preflight (Admin Workstation)

```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system -o wide
kubectl get --raw=/readyz && echo
```

---

## 2) Remove Stale Kubernetes Node Object (If Needed)

```bash
kubectl delete node "node3" || true
kubectl get nodes -o wide
```

---

## 3) On Healthy Control-Plane Node: etcd Member Cleanup + Token

SSH in:

```bash
ssh "$HEALTHY_CP_USER@$HEALTHY_CP_IP"
```

Become root:

```bash
sudo -i
```

List etcd members:

Note: On K3S, embedded etcd can be healthy even if the standalone etcdctl client is not present yet. The next commands auto-discover etcdctl and install etcd-client only if needed.

```bash
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

Remove stale member (replace ID first):

```bash
"$ETCDCTL_BIN" \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  --endpoints=https://127.0.0.1:2379 member remove <stale-member-id>
```

Re-check members:

```bash
"$ETCDCTL_BIN" \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  --endpoints=https://127.0.0.1:2379 member list -w table
```

Get join token:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token

# Capture running k3s version for the join command (example output: v1.36.2+k3s1)
sudo k3s --version | awk '/^k3s version/ {print $3; exit}'
```

Copy token value and k3s version value, then set `K3S_VERSION` on your admin shell before Step 4.

---

## 4) On Replacement Node: Clean Old State and Join as Server

SSH in:

```bash
ssh "$REPLACEMENT_USER@$REPLACEMENT_NODE_IP"
```

Become root:

```bash
sudo -i
```

Cleanup old K3S state:

```bash
if [ -x /usr/local/bin/k3s-uninstall.sh ]; then
  /usr/local/bin/k3s-uninstall.sh
fi
rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /etc/cni /opt/cni
```

Check swap and time:

```bash
swapon --show
timedatectl status
```

Join as control-plane server (paste token):

```bash
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="$K3S_VERSION" \
  K3S_URL="https://$K3S_VIP:6443" \
  K3S_TOKEN='<paste-server-node-token>' \
  INSTALL_K3S_EXEC='server' \
  sh -
```

Service check:

```bash
systemctl enable k3s
systemctl status k3s --no-pager
```

---

## 5) Validate Rejoin (Admin Workstation)

```bash
kubectl get nodes -o wide
kubectl describe node "$FAILED_NODE_NAME" | grep -E 'Roles|Taints|InternalIP' || true
```

API readiness loop via VIP-backed kubeconfig:

```bash
for i in $(seq 1 10); do
  kubectl get --raw=/readyz >/dev/null && echo "ok $i" || echo "fail $i"
  sleep 2
done
```

---

## 6) Validate etcd Health (Healthy Control-Plane Node)

```bash
ssh "$HEALTHY_CP_USER@$HEALTHY_CP_IP"
sudo -i

# Reuse ETCDCTL_BIN discovery from Step 3 if needed, then run:
"$ETCDCTL_BIN" \
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
- 3 members in etcd
- all endpoints healthy

---

## 7) Break-Glass Reset on Replacement Node (If Join Fails)

```bash
ssh "$REPLACEMENT_USER@$REPLACEMENT_NODE_IP" 'sudo -i bash -lc '
'"'"'/usr/local/bin/k3s-uninstall.sh || true
rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /etc/cni /opt/cni
'"'"''
```

Then retry Step 4.

---

## Completion Check

```bash
kubectl get nodes -o wide
```

Done when:
- all 3 control-plane nodes are `Ready`
- etcd has 3 healthy members
- API readiness checks do not flap

---

## Optional: Safe Scheduling Policy for RPi4 8GB Control Plane

Use this if you want selected lightweight workloads on control-plane nodes, while still blocking general scheduling.

```bash
# 1) Uncordon nodes (remove maintenance unschedulable state)
kubectl uncordon node1 node2 node3

# 2) Label hardware/pool for targeting
kubectl label node node1 node2 node3 \
  homelab.io/class=rpi4b-8gb \
  homelab.io/storage=usb-flash \
  homelab.io/pool=control \
  --overwrite

# 3) Apply a dedicated taint so only opted-in workloads can land here
kubectl taint node node1 node2 node3 homelab.io/control-infra=true:NoSchedule --overwrite

# 4) Verify
kubectl get nodes -L homelab.io/class,homelab.io/pool,homelab.io/storage
kubectl describe node node3 | grep -E 'Taints|Roles|InternalIP'
```

Use this pod spec fragment for workloads that are allowed on control-plane nodes:

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
