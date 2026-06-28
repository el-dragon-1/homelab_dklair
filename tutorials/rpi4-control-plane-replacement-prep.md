# Raspberry Pi 4 (8GB) Control Plane Replacement - Initial Board Preparation

This runbook prepares a Raspberry Pi 4 Model B (8GB) with a 256GB USB 3.0 flash drive to:

- boot directly from USB storage
- run a lightweight Ubuntu install suitable for K3S control-plane use
- be ready for cluster join in a later step

This guide covers only board preparation and operating system readiness.

---

## Scope

Use this when replacing a failed control-plane node in this cluster.

Cluster references:
- Existing control-plane architecture and node/IP conventions: `README.md`
- Hardware inventory and current node roles: `HARDWARE.md`

---

## Prerequisites

- Raspberry Pi 4 Model B (8GB)
- Stable official PSU (5V/3A recommended)
- 256GB USB 3.0 flash drive (or SSD)
- Ethernet connection to the cluster VLAN (`192.168.4.0/24`)
- A laptop/desktop with:
  - Raspberry Pi Imager
  - SSH client
  - Optional serial/HDMI access for break-glass recovery
- Reserved static IP for the replacement node (same IP as failed node, or new reserved IP)
- Router/DHCP awareness so no IP conflict exists

---

## Step 1 - Decide Identity for the Replacement Node

Before flashing, define:

- Hostname (example: `node2`)
- Static IP (example: `192.168.4.115`)
- Gateway (`192.168.4.1`)
- DNS (example: `192.168.4.1` and/or public DNS)

If you are taking over a failed node identity, reusing hostname and IP minimizes downstream changes.

---

## Step 2 - Prepare USB Drive and Image Ubuntu Server

Preferred image:
- **Ubuntu Server 24.04 LTS 64-bit (minimal/lightweight server install)**

Using Raspberry Pi Imager:

1. Open Raspberry Pi Imager.
2. Choose device: **Raspberry Pi 4**.
3. Choose OS: **Ubuntu Server 24.04 LTS (64-bit)**.
4. Choose storage: your 256GB USB drive.
5. Click the settings/customization screen and set:
   - hostname (from Step 1)
   - enable SSH
   - add your SSH public key
   - set locale/timezone
   - set username
   - preconfigure network (if available in your Imager workflow)
6. Write the image.
7. Safely eject and reconnect the USB drive.

Optional post-flash check from your workstation:

```bash
# Replace /dev/diskX with your USB device identifier
sudo diskutil unmountDisk /dev/diskX
sudo fsck_exfat -n /dev/diskXs1 2>/dev/null || true
```

---

## Step 3 - Ensure Raspberry Pi 4 USB Boot Is Enabled

Most Pi 4 boards already support USB boot via EEPROM, but verify if this board is older.

1. Insert the imaged USB drive.
2. Disconnect any SD card (to force USB boot path).
3. Power on and observe activity LED / network link.
4. If it fails to boot from USB:
   - Temporarily boot with a known-good Raspberry Pi OS SD card.
   - Update EEPROM and set boot order with `USB` first.
   - Re-test boot with SD removed.

On Raspberry Pi OS (recovery path):

```bash
sudo apt update
sudo apt install -y rpi-eeprom
sudo rpi-eeprom-update -a
sudo raspi-config  # Advanced Options -> Boot Order -> USB Boot
sudo reboot
```

---

## Step 4 - First Boot and Access Validation

1. Connect Pi to Ethernet.
2. Power on.
3. Wait 2-5 minutes for first boot cloud-init completion.
4. Find the host via DHCP lease table or mDNS/ARP scan.
5. SSH in:

```bash
ssh <username>@<new-node-ip>
```

6. Validate OS and architecture:

```bash
uname -a
cat /etc/os-release
```

Expected:
- Ubuntu 24.04 LTS
- `aarch64` / `arm64`

---

## Step 5 - Move to Static Network Configuration

If static networking was not preconfigured during imaging, set it now using netplan.

1. Identify active interface:

```bash
ip -br a
```

2. Create/update netplan config (`/etc/netplan/50-cloud-init.yaml` or equivalent):

```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 192.168.4.115/24
      routes:
        - to: default
          via: 192.168.4.1
      nameservers:
        addresses: [192.168.4.1, 1.1.1.1]
```

3. Apply configuration:

```bash
sudo netplan generate
sudo netplan apply
```

4. Reconnect SSH using static IP and verify route:

```bash
ip route
ping -c 3 192.168.4.1
```

---

## Step 6 - Baseline Hardening and System Prep

Run the following before joining K3S:

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y curl jq vim htop chrony
sudo timedatectl set-timezone America/New_York
sudo systemctl enable --now chrony
```

Recommended kernel/cgroup settings for K3S on Pi:

```bash
# Add only if not already present
grep -q "cgroup_memory=1" /boot/firmware/cmdline.txt || \
  sudo sed -i 's/$/ cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt
```

Disable swap for Kubernetes consistency:

```bash
sudo swapoff -a
sudo sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab
```

Reboot after kernel boot-arg changes:

```bash
sudo reboot
```

---

## Step 7 - Post-Reboot Verification Checklist

Run and confirm:

```bash
hostnamectl
ip -br a
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
df -h /
free -h
timedatectl status
```

Acceptance criteria:

- Hostname is correct for replacement role
- Static IP is present and reachable
- Root filesystem is on USB storage (not SD)
- Time sync is active
- Swap is disabled
- SSH key login works

---

## Step 8 - Handover State (Ready for Cluster Join)

At this point, the board is ready for the next runbook (K3S server join/rejoin).

Next step:
- `tutorials/rpi4-control-plane-rejoin-runbook.md`
- `tutorials/rpi4-control-plane-replacement-quick-commands.md` (outage copy/paste sheet)

Capture these details for the join step:

- Hostname and static IP
- OS version (`Ubuntu 24.04 LTS`)
- Confirmation of USB-root filesystem
- SSH reachability from your admin workstation

---

## Verification from Admin Workstation

From your management machine:

```bash
ssh <username>@192.168.4.115 'hostname; hostname -I; uptime'
ping -c 3 192.168.4.115
```

---

## Rollback / Recovery

If the board does not reach a stable state:

1. Power off and remove USB media.
2. Re-image USB with the same Ubuntu profile.
3. Boot with HDMI attached and confirm cloud-init completed successfully.
4. If USB boot still fails, perform EEPROM USB boot update via temporary SD boot (Step 3).
5. Keep the failed node powered off during cutover to avoid duplicate hostname/IP conflicts.

---

## Notes

- Avoid joining this node to K3S until hostname, static IP, and time sync are all stable.
- For control-plane replacement, preserving the old node identity (name/IP) is usually the safest approach.
- Once the node is joined, validate etcd and control-plane health before declaring recovery complete.
