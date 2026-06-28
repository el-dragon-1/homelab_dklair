# Home Lab Hardware Specification

## Control Plane (Raspberry Pi Cluster)

The control plane consists of three Raspberry Pi 4 Model B units configured as a Kubernetes master cluster.

### node1 (control plane)
- **Model**: Raspberry Pi 4 Model B
- **CPU**: Broadcom BCM2711, Quad core Cortex-A72 (ARM v8) 64-bit SoC @ 1.5GHz
- **RAM**: 8GB LPDDR4
- **Storage**: 256GB flash SSD (mounted via USB 3.0)
- **Network**: inet 192.168.4.110/24
- **Peripherals**: Rackmounted (active cooling)
- **Role**: Primary Kubernetes master (etcd leader, API server)
- **OS**: Debian GNU/Linux 12 (bookworm)

### node2 (control plane)
- **Model**: Raspberry Pi 4 Model B
- **CPU**: Broadcom BCM2711, Quad core Cortex-A72 (ARM v8) 64-bit SoC @ 1.5GHz
- **RAM**: 8GB LPDDR4 (each)
- **Storage**: 256GB flash SSD (mounted via USB 3.0)
- **Network**: inet 192.168.4.115/24
- **Peripherals**: Rackmounted (active cooling)
- **Role**: Secondary Kubernetes masters (etcd members)
- **OS**: Debian GNU/Linux 13 (trixie)

### node3 (control plane)
- **Model**: Raspberry Pi 4 Model B
- **CPU**: Broadcom BCM2711, Quad core Cortex-A72 (ARM v8) 64-bit SoC @ 1.5GHz
- **RAM**: 8GB LPDDR4 (each)
- **Storage**: 256GB flash SSD (mounted via USB 3.0)
- **Network**: inet 192.168.4.116/24
- **Peripherals**: Rackmounted (active cooling)
- **Role**: Secondary Kubernetes masters (etcd members)
- **OS**: Debian GNU/Linux 12 (bookworm)

## Worker Nodes

### eldragon (GPU Compute Node)
- **Host**: Custom Desktop PC
- **CPU**: Intel(R) Xeon(R) E-2324G CPU @ 3.10GHz
- **RAM**: 64GB DDR4 3200MHz
- **GPU**: NVIDIA GeForce RTX 4060 (8GB VRAM), Driver v580.159.03, CUDA v12.4
- **Storage**: 256GB NVMe SSD (OS), 4TB SATA SSD (data)
- **Network**: 2.5GbE (static IP: 192.168.4.213), Wi-Fi 6 (disabled)
- **Power Supply**: Corsair RM600x (600W, 80+ Gold)
- **Cooling**: Corsair water cooler, 2x 120mm case fans
- **Role**: Primary GPU-accelerated workloads, CUDA compute
- **OS**: Ubuntu 24.04.3 LTS
- **Software**: NVIDIA Container Toolkit, CUDA 12.4

#### GPU Recovery Runbook (eldragon)

Use this when `nvidia.com/gpu` shows `0` on `eldragon` and GPU workloads (for example `open-webui-ollama`) are Pending.

1. Confirm node GPU resource is missing:

    ```bash
    export KUBECONFIG=~/kube/k3s.yaml
    kubectl get node eldragon -o jsonpath='{.status.capacity.nvidia\.com/gpu} {.status.allocatable.nvidia\.com/gpu}' && echo
    ```

2. Check GPU operator driver-validation logs:

    ```bash
    kubectl logs -n gpu-operator $(kubectl get pod -n gpu-operator -o name | grep nvidia-container-toolkit-daemonset | head -1 | cut -d/ -f2) -c driver-validation --tail=120
    ```

    If you see `NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver`, continue.

3. Confirm kernel/module mismatch on host:

    ```bash
    kubectl debug node/eldragon -it --image=ubuntu -- chroot /host bash -lc 'uname -r; dpkg -l | grep -E "linux-modules-nvidia-580-open|nvidia-driver-580-open"'
    ```

4. Install matching NVIDIA kernel modules on host:

    ```bash
    kubectl debug node/eldragon -it --image=ubuntu -- chroot /host bash -lc 'export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get install -y linux-modules-nvidia-580-open-generic'
    ```

5. Recycle NVIDIA operator pods on `eldragon`:

    ```bash
    kubectl get pods -n gpu-operator -o wide | grep eldragon
    kubectl delete pod -n gpu-operator <gpu-feature-discovery-pod> <nvidia-container-toolkit-pod> <nvidia-dcgm-exporter-pod> <nvidia-device-plugin-pod> <nvidia-operator-validator-pod>
    ```

6. Verify recovery:

    ```bash
    kubectl get node eldragon -o jsonpath='{.status.capacity.nvidia\.com/gpu} {.status.allocatable.nvidia\.com/gpu}' && echo
    kubectl get pods -n gpu-operator -o wide | grep eldragon
    ```

Expected result: `1 1` for GPU capacity/allocatable and NVIDIA daemonset pods Running on `eldragon`.

### orangepi5 (General Compute Node)
- **Host**: Orange Pi 5
- **CPU**: 8-core 64-bit; 4x Cortex-A76 @ 2.4GHz + 4x Cortex-A55 @ 1.8GHz
- **RAM**: 8GB DDR4 2933MHz
- **Storage**: 512GB NVMe SSD (OS), 2TB HDD (backup)
- **Network**: Gigabit Ethernet (static IP: 192.168.4.84)
- **GPU**: ARM Mali-G610 MP4; OpenGL ES1.1/2.0/3.2, OpenCL 2.2, Vulkan 1.2
- **NPU**: 6 TOPS; supports INT4/INT8/INT16 mixed operation
- **Role**: General-purpose workloads, CI/CD runners
- **OS**: Ubuntu 22.04.5 LTS

## Network & Power
- **Switch**: Netgear GS108PE 8-Port Gigabit PoE+ Switch
- **UPS**: APC Back-UPS Pro 1500VA
- **Topology**: All nodes on 192.168.4.0/24 VLAN

### OpenWRT Devices (managed via Ansible/ArgoCD GitOps)

| Name | Hardware | IP | Role |
|------|----------|----|------|
| gateway | Bananapi R3 | 192.168.4.1 | Router, DHCP server, 802.11s mesh root |
| ap | Bananapi R3 | 192.168.4.2 | 802.11s mesh point, 5GHz backhaul to gateway |
| hades | Cudy M3000 (MediaTek MT7981) | 192.168.4.3 | WiFi AP, serves client SSIDs (2.4GHz + 5GHz) |
| gemini | Cudy M3000 (MediaTek MT7981) | 192.168.4.4 | WiFi AP, serves client SSIDs (2.4GHz + 5GHz ch36, 802.11ax/HE80) |
| orchid | Cudy M3000 (MediaTek MT7981) | 192.168.4.5 | 802.11s mesh point (wpad-mesh-wolfssl) |

All OpenWRT devices run OpenWRT 25.12.4 and are reconciled via Ansible CronJobs (`openwrt-ops` namespace).

`openwrt-ops` reconciliation jobs use a 15-minute runtime cap (`activeDeadlineSeconds: 900`) and 10-minute post-completion cleanup TTL (`ttlSecondsAfterFinished: 600`) to avoid stale running jobs.

## Cluster Management
- **Orchestration**: Kubernetes 1.36.2+k3s1
- **CNI**: Flannel (Default K3S CNI)
- **Load Balancer & HA**: KubeVIP v1.0.0 (managing control plane VIP 192.168.4.20)
- **Control Plane IP**: 192.168.4.20 (KubeVIP-managed virtual IP)
- **Storage**:
    - Longhorn v4.9.0 (distributed block storage)
    - Replica count: 5
    - Storage nodes: node1, node2, node3, eldragon, orangepi5
- **Monitoring**: n/a   