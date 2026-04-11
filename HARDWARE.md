# Home Lab Hardware Specification

## Control Plane (Raspberry Pi Cluster)

The control plane consists of three Raspberry Pi 4 Model B units configured as a Kubernetes master cluster.

### Pi-Control-01 (Primary Master)
- **Model**: Raspberry Pi 4 Model B
- **CPU**: Broadcom BCM2711, Quad core Cortex-A72 (ARM v8) 64-bit SoC @ 1.5GHz
- **RAM**: 8GB LPDDR4
- **Storage**: 128GB Samsung EVO+ microSD (OS), 1TB Samsung T7 SSD (mounted via USB 3.0)
- **Network**: Gigabit Ethernet (static IP: 192.168.1.10), 5GHz Wi-Fi (disabled)
- **Peripherals**: Official Raspberry Pi 4 Case with active cooling
- **Role**: Primary Kubernetes master (etcd leader, API server)
- **OS**: Ubuntu Server 22.04 LTS (64-bit), Kernel 5.15

### Pi-Control-02 & Pi-Control-03 (Secondary Masters)
- **Model**: Raspberry Pi 4 Model B
- **CPU**: Broadcom BCM2711, Quad core Cortex-A72 (ARM v8) 64-bit SoC @ 1.5GHz
- **RAM**: 8GB LPDDR4 (each)
- **Storage**: 64GB SanDisk Ultra microSD (OS), 500GB WD My Passport SSD (mounted via USB 3.0)
- **Network**: Gigabit Ethernet (static IPs: 192.168.1.11, 192.168.1.12)
- **Peripherals**: Flirc Aluminum Case (passive cooling)
- **Role**: Secondary Kubernetes masters (etcd members)
- **OS**: Ubuntu Server 22.04 LTS (64-bit), Kernel 5.15

## Worker Nodes

### Worker-GPU-01 (GPU Compute Node)
- **Host**: Custom Desktop PC
- **CPU**: AMD Ryzen 9 5900X (12-core, 24-thread)
- **RAM**: 64GB DDR4 3200MHz
- **GPU**: NVIDIA GeForce RTX 4090 (24GB VRAM), Driver v550.40.07
- **Storage**: 1TB NVMe SSD (OS), 4TB SATA SSD (data)
- **Network**: 2.5GbE (static IP: 192.168.1.20), Wi-Fi 6 (disabled)
- **Power Supply**: Corsair RM850x (850W, 80+ Gold)
- **Cooling**: Noctua NH-D15 air cooler, 3x 120mm case fans
- **Role**: Primary GPU-accelerated workloads, CUDA/ROCm compute
- **OS**: Ubuntu Desktop 22.04 LTS (64-bit), Kernel 5.15
- **Software**: Docker 24.0, NVIDIA Container Toolkit, CUDA 12.4

### Worker-CPU-01 (General Compute Node)
- **Host**: Dell OptiPlex 7080
- **CPU**: Intel Core i7-10700 (8-core, 16-thread)
- **RAM**: 32GB DDR4 2933MHz
- **Storage**: 512GB NVMe SSD (OS), 2TB HDD (backup)
- **Network**: Gigabit Ethernet (static IP: 192.168.1.21)
- **GPU**: Integrated Intel UHD Graphics 630
- **Role**: General-purpose workloads, CI/CD runners
- **OS**: Ubuntu Server 22.04 LTS (64-bit), Kernel 5.15

## Network & Power
- **Switch**: Netgear GS108PE 8-Port Gigabit PoE+ Switch
- **Router**: Ubiquiti EdgeRouter X
- **UPS**: APC Back-UPS Pro 1500VA
- **Topology**: All nodes on 192.168.1.0/24 VLAN, managed by Pi-hole (192.168.1.1)

## Cluster Management
- **Orchestration**: Kubernetes 1.28 (k3s)
- **CNI**: Flannel (Default K3S CNI)
- **Load Balancer & HA**: KubeVIP v0.5.10 (managing control plane VIP 192.168.4.100)
- **Control Plane IP**: 192.168.4.20 (KubeVIP-managed virtual IP)
- **Storage**: NFS server hosted on Worker-GPU-01
- **Monitoring**: n/a   