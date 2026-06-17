# OpenWRT Desired State

This directory holds sanitized OpenWRT configuration snapshots and the desired state used by the GitOps workflow.

## Layout

- `baseline/`: sanitized snapshot of current router configuration
- `desired/`: sanitized configuration that GitOps should enforce

## Device Folders

- `gateway/`: Bananapi R3 gateway
- `ap/`: Bananapi R3 access point with mesh backhaul
- `hades/`: Bananapi R3 AP with LAN, IoT, and guest SSIDs
- `gemini/`: Bananapi R3 AP with LAN, IoT, and guest SSIDs
- `orchid/`: Bananapi R3 mesh AP

## File Convention

Keep one UCI file per configuration area:

- `system.uci`
- `network.uci`
- `dhcp.uci`
- `firewall.uci`
- `wireless.uci`

Do not commit raw exports or secrets.

## Declarative Contract

OpenWRT reconcile is GitOps-driven from `openwrt/desired`.

- `baseline/` is evidence only and must not be treated as the enforcement source.
- `desired/` is the only source of truth for enforced UCI state.
- For each managed device, define all package files below:
	- `system.uci`
	- `network.uci`
	- `dhcp.uci`
	- `firewall.uci`
	- `wireless.uci`

If any required desired file is missing for a device, reconcile should fail fast instead of applying partial assumptions.

## Reconcile Behavior

The OpenWRT automation imports package configs from `openwrt/desired/<device>/<package>.uci` and commits each package.

- Avoid hardcoded device policy in playbooks when the same policy can live in desired files.
- Keep secret values templated (for example `{{ mesh_key }}`, `{{ smz_homex_ssid_key }}`) and resolve them at runtime from Vault/External Secrets.
- Prefer targeted runtime refreshes (`ifup`, service reloads, `wifi reload`) over broad network restarts where possible.

### Runtime Safety Defaults

To reduce remote lockout risk during enforcement:

- `gateway` uses full runtime apply (network `ifup` set plus firewall service reload/restart).
- AP-class remote nodes (`ap`, `hades`, `gemini`, `orchid`) default to conservative runtime behavior:
	- no automatic network `ifup`
	- no automatic firewall reload
	- DHCP and wireless runtime refresh still run

Optional overrides can be passed to Ansible when needed:

- `openwrt_apply_remote_network_runtime=true`
- `openwrt_apply_remote_firewall_runtime=true`

Use these overrides only for staged maintenance windows when remote recovery is available.

## Failsafe Recovery

Use this when a device is unreachable after a reconcile or network/firewall change.

### 1. Enter Failsafe Mode

1. Power cycle the router.
2. Hold the reset button during boot until the status LED indicates failsafe mode.
3. Connect your laptop directly by Ethernet.
4. Set your laptop to the same subnet as the failsafe address (commonly `192.168.1.0/24`).
5. Confirm reachability:

```bash
ping 192.168.1.1
```

### 2. Resolve SSH Host Key Mismatch

After reset/failsafe, SSH host keys often change.

```bash
ssh-keygen -R 192.168.1.1
ssh-keygen -R '[192.168.1.1]:22'
ssh -o StrictHostKeyChecking=accept-new root@192.168.1.1
```

For one-time emergency access only:

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.1.1
```

### 3. Reset Broken Overlay Config

In the router shell:

```sh
mount_root
firstboot -y
reboot -f
```

This clears persistent overlay config and returns to a known-safe state.

### 4. Reapply Minimal Management Config

After reboot and reconnecting over SSH, set the management LAN back to the intended static address.

Example for `gemini` (`192.168.4.4`):

```sh
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.4.4'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.4.1'
uci set network.lan.peerdns='0'
uci -q delete network.lan.dns
uci add_list network.lan.dns='1.1.1.1'
uci set network.wan.proto='none'
uci set network.wan6.proto='none'
uci set dhcp.lan.ignore='1'
uci commit network
uci commit dhcp
reboot -f
```

### 5. Validate Before Reconcile

After the device comes back on its management IP:

```sh
uci show network.lan
uci show network.wan
uci show network.wan6
uci show dhcp.lan | grep ignore
uci show firewall | head -n 40
```

Operational guardrails:

- Keep affected reconcile CronJobs suspended during recovery.
- Recover one device at a time.
- Run one manual reconcile job and observe connectivity before resuming schedules.

## Device Coverage Checklist

Before enabling or unsuspending reconcile jobs for any device, verify:

- `openwrt/desired/<device>/system.uci` exists and has the intended hostname.
- `openwrt/desired/<device>/network.uci` exists and reflects interface and bridge intent.
- `openwrt/desired/<device>/dhcp.uci` exists and reflects DHCP/DNS intent.
- `openwrt/desired/<device>/firewall.uci` exists and reflects zone/rule intent.
- `openwrt/desired/<device>/wireless.uci` exists and reflects AP/mesh intent.

## Vault Mapping

Keep all secrets for each device in a single root path so the current ExternalSecrets can pull them together:

- `homelab/openwrt/gateway`
- `homelab/openwrt/ap`
- `homelab/openwrt/hades`
- `homelab/openwrt/gemini`
- `homelab/openwrt/orchid`

For each device path, store:

- `host`
- `port`
- `username`
- `ssh_private_key`
- `mesh_key`
- `ssid keys`
