# OpenWRT Desired State

This directory holds sanitized OpenWRT configuration snapshots and the desired state used by the GitOps workflow.

For the household device inventory, trust tiers, network placement proposals, and
functional validation/troubleshooting record, see [IoT network layout](../IOT.md).

### Vault VIP Reservation

The desired gateway DHCP configuration reserves `192.168.4.103` using the
non-client hostname `reserved-vault-vip` before Vault is moved to that address.
This is a hostname-only dnsmasq reservation, not a device/MAC binding: a kube-vip
address can move between nodes. Do not configure a client with that hostname.
Apply and verify the reservation before publishing the Vault Service address change.
See the [Vault migration plan](../values/vault/context.md) for sequencing and rollback.

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

## SSID Segmentation Notes

### IoT DNS Exception

Desired gateway firewall permits IoT-initiated IPv4 TCP/UDP DNS only to
Pi-hole `192.168.4.102`, destination port 53, before the broad IoT-to-LAN DROP rules.
This does not allow Pi-hole administration, Vault `.103:8200`, or guest DNS access.
After the IoT-only DNS and blocked Vault tests passed, desired gateway DHCP
option 6 for IoT was changed to advertise only Pi-hole `192.168.4.102`.
Revision `75d04b012c0095e96c458cf896e85019e65a5fb5` was applied on
2026-10-11 by gateway Job `iot-dhcp-gateway-20261011-1625`. Live dnsmasq and
a renewed IoT-only client lease advertise only `.102`. The test Mac's manual
`1.1.1.1` Wi-Fi override was cleared with owner approval; its effective system
resolver became `.102`. An ordinary lookup succeeded with client-to-Pi-hole
DNS request/reply metadata observed. Explicit UDP/TCP DNS passed, and Vault
remained blocked. Other clients still need lease renewal and validation.
Guest DNS remains unchanged. This removes the advertised public fallback; it
does not enforce a ban on manually configured public DNS or encrypted DNS.

2026-10-11 validation: revision `4019ea122271ca9bbf4a51c0e95e35d99a9ba006`
was applied by gateway reconcile. Live TCP/UDP exceptions precede the LAN drop,
and `fw4 check` passed. With Ethernet unplugged, laptop `10.1.1.105` routed
via IoT Wi-Fi: Pi-hole UDP/TCP queries returned NOERROR and Vault `.103:8200`
timed out. DNS allow counters increased. This validates the scoped IPv4 path,
not complete VLAN isolation; the DHCP resolver change was validated separately.

### Gemini Mesh VLAN Transport

Gemini's wired uplink passes through AP, which backhauls to gateway over 802.11s;
Hades connects through gateway. The gateway mesh interface `phy1-mesh0` must carry
LAN VLAN 1 untagged/PVID and IoT/guest VLANs 10/20 tagged. Its interface name is
explicitly pinned in desired wireless configuration to match the bridge port rules.
AP currently bridges Ethernet and mesh without VLAN filtering, transporting tags
transparently; no AP management-address or subnet-ownership change is needed for
this gateway admission fix.

Apply the gateway change in a controlled window while retaining wired management.
Verify live `br-lan` VLAN membership after wireless reload and again after a later
reconcile. From Gemini, verify a client gets a gateway-issued `10.1.1.x` lease,
then test guest VLAN 20 and confirm cross-zone isolation. Do not replace missing
VLAN transport with AP DHCP servers or untagged IoT on the LAN.
If tagged traffic still fails, trace the AP Ethernet/mesh path before widening the
change. Rollback the gateway network/wireless changes together through Git.

2026-10-11 validation: after gateway reconciliation and wireless reload, live mesh
membership included tagged VLANs 10/20, and a Gemini Wi-Fi client obtained
`10.1.1.105` from gateway `10.1.1.1`. Wi-Fi-bound gateway reachability passed.
Guest-client and subsequent scheduled-reconcile checks remain pending.

### IPv6 and Gateway Access Audit

Gateway administration restriction prepared after the audit: the input-only
`Reject IoT gateway administration` rule rejects new IoT TCP connections to
ports 22/80/443 over IPv4 and IPv6, on any gateway-local address. It has no
destination zone, so it does not affect forwarded services. LAN management,
Pi-hole forwarding, DHCP, ICMPv6, and other gateway services are unchanged.
This is a port-specific restriction, not default-deny IoT input; established
connections may survive until closed. Guest and AP administration are outside
this batch.

Desired gateway CronJob is suspended for controlled application/testing.
Publication and application are pending. Argo CD sync applies suspension,
not router UCI: verify suspension and no active gateway Jobs before creating
one manual gateway reconcile. Keep wired LAN recovery access, then test new
IoT IPv4/IPv6-link-local administration connections fail while LAN management,
DHCP renewal, Pi-hole TCP/UDP/system DNS, and required IPv6 neighbor discovery
still work. Record results before restoring `suspend: false` through GitOps.
Other AP schedules remain enabled.

Rollback: remove only the administration rule through Git, publish, and run
a manual gateway reconcile while suspended. Keep the Pi-hole exception and
IPv6 ownership unchanged; restore the schedule separately after validation.

2026-10-11 17:03-17:05 CDT: applied revision
`4e51d9b25d539bd42cc6b5f6e55267f613fc1fd3` with manual gateway Job
`iot-admin-gateway-20261011-1703`. Firewall check passed, LAN SSH/HTTPS
remained accessible, and new IoT IPv4/IPv6-link-local TCP 22/80/443 connections
failed while IPv6 ping/neighbor reachability passed. IoT-only DHCP, system
resolver configuration, explicit UDP/TCP DNS, and blocked Vault probes passed.
One UDP DNS response was stale (TTL zero / EDNS code 3); TCP returned fresh
answers, and a subsequent UDP recheck also returned fresh answers.
Desired schedule restoration (`suspend: false`) is now prepared;
live gateway scheduling remains suspended until publication and Argo CD sync.

2026-10-11 read-only audit, approximately 16:57-16:59 CDT:

- Gateway has a delegated WAN `/64`, assigned to LAN; IoT has only a
  link-local gateway address, with no gateway-owned prefix or RA/DHCPv6
  server configured. Do not reuse the LAN `/64` on another VLAN.
- All four APs retain LAN `ip6assign` allocations from their own ULA prefixes
  and RA/DHCPv6 server settings despite IPv4 DHCP `ignore=1`. Gemini logs
  report zero RA default-router lifetime. These settings do not establish
  gateway-only IPv6 ownership.
- Passive IoT capture observed Kitchen HomePod and another unidentified
  router advertising the same on-link ULA and a route under Hades' ULA.
  Both RAs had default-router lifetime zero. Preserve and investigate these
  likely border-router paths before changing prefix delegation or IPv6.
- IoT gateway SSH and HTTPS TCP ports are reachable over IPv4; SSH is also
  reachable at the gateway's IPv6 link-local address. HTTP returned 403,
  which is an application response, not firewall isolation.
- Broad IoT/guest LAN DROP rules are IPv4-only, but inspected IPv6 forwarding
  falls through to the default reject for LAN destinations: intra-zone
  ACCEPT does not authorize forwarding to LAN. Actual IPv6 client-to-LAN
  negative tests remain pending.
- All reconcile schedules remain enabled. Gemini's scheduled Job at :51
  confirms DHCP service restarts and Wi-Fi reload even with conservative
  AP network/firewall runtime settings. Establish a managed maintenance
  window before further changes.

No configuration or schedule was changed for the audit. The passive capture
was stopped explicitly. Harden gateway administration in a separate staged
change, retaining trusted-LAN access, DHCP, and required ICMPv6. Then resolve
IPv6 ownership, available upstream prefix size, DNS advertisements, and
Matter/Thread requirements before enabling gateway IoT RA or removing AP RA.

17:09 CDT follow-up: owner confirmed upstream AT&T BGW320 and identified
IoT `basement` (`10.1.1.233`) as an Apple TV. Gateway requests automatic
delegation (`odhcp6c -P0`) and still receives one LAN `/64`; larger-prefix
availability is unverified. Hades actively delegates ULA
`fd6f:ffb:7de6:4::/62` to the DUID also used by its `Living-Room` lease.
This overlaps the route advertised on IoT by Kitchen HomePod and basement
Apple TV. The test Mac also has addresses from multiple AP ULA prefixes.
Preserve these active allocations until a staged prefix-ownership migration
is designed; immediate AP RA/DHCPv6 removal is not a safe cleanup.
See the [IPv6 follow-up](../IOT.md) for the evidence and proposed direction.

### Staged IoT Local IPv6

Owner approved local-only IPv6 first and accepts IoT interruptions. Desired
gateway IoT now requests a local ULA `/64` with hexadecimal hint `10`
(expected `fd47:eab4:aa15:10::/64`), excluding WAN-delegated prefixes.
LAN's existing `/60` local allocation and global `/64` are unchanged.
IoT RA advertises SLAAC, zero default-router lifetime, no managed/other
configuration flags, and no IPv6 DNS. DHCPv6 is disabled for this interface;
IPv4 DHCP continues to advertise Pi-hole only. This is local IPv6 enablement,
not completed routed IPv6 or Matter/Thread support.

Gateway scheduling is staged suspended for the apply/test window. After
publication, sync suspension and check for active Jobs before one manual
gateway reconcile. Verify the actual ULA allocation and RA prefix, zero
router lifetime, and absence of RDNSS; inspect renewed client addresses and
routes, preserving IPv4 DNS/Internet, LAN management, and blocked IoT
administration/Vault paths. Existing Apple RAs and all AP IPv6 settings remain
unchanged. Do not remove their allocations in this batch.

Rollback: remove only the new IoT IPv6 network/DHCP options through GitOps,
reconcile while suspended, and reconnect clients. SLAAC addresses can linger
until their valid lifetimes expire; verify withdrawal rather than assuming
instant removal. Restore scheduling separately after acceptance tests.
Publication/application and live RA/client validation are pending.

2026-10-11 acceptance: revision `887a16d25aba525fea063499a80a9c51071731d5`
was synced and applied by manual Job `iot-ula-gateway-20261011-1719`.
The gateway allocated `fd47:eab4:aa15:10::/64`; a captured gateway RA
contained that on-link/SLAAC prefix, router lifetime zero, flags none, and
no RDNSS. It also advertised a route to gateway ULA `/48` (not a default
route or firewall permission). The IoT-only Mac received a SLAAC address
and could ping the ULA gateway; new ULA TCP 22/80/443 connections were refused.
Pi-hole remained the sole effective resolver, UDP/TCP DNS passed (22/34 ms),
IPv4 HTTPS returned 200, and Vault remained blocked. Existing Apple-derived
routes persisted; the prior on-link Apple ULA address was deprecated.
After reconnecting Ethernet, LAN retained its ULA/global prefixes and IPv6
HTTPS returned 200. Full client-to-LAN IPv6 isolation remains untested.

Desired schedule restoration is now `suspend: false`; live gateway scheduling
remains suspended until publication and Argo CD sync. No additional manual
router reconcile is required solely to restore scheduling.

Current intent:

- `smz_homex` maps to `lan` and is allowed to reach IoT/guest devices.
- `OpenWrt` maps to `iot` and should not initiate access to `lan`.
- `smz_guest` maps to `smz_guest` and should not initiate access to `lan`.
- All three networks should have internet egress.

Gateway firewall policy enforces this model with:

- `iot_zone -> wan` forwarding
- `guest -> wan` forwarding
- `lan -> iot_zone` forwarding
- `lan -> guest` forwarding
- explicit `DROP` rules for `iot_zone -> lan` and `guest -> lan`

### Prior Limitation (Resolved By Phase 2)

Previously, `hades` and `gemini` also owned L3 interfaces for `iot` (`10.1.1.0/24`) and
`smz_guest` (`10.2.2.0/24`) while gateway owned the same subnets. That overlap could cause
inconsistent internet reachability from AP-hosted SSIDs.

Phase 2 moves APs to bridge-only segmentation for IoT/guest and keeps gateway as the single L3
owner for those subnets.

### Phase 2 (Bridge-VLAN Ownership Model)

Target model:

- Gateway is the only L3 owner for:
	- `lan` on `br-lan.1` (`192.168.4.1/24`)
	- `iot` on `br-lan.10` (`10.1.1.1/24`)
	- `smz_guest` on `br-lan.20` (`10.2.2.1/24`)
- Hades and Gemini carry VLANs 10/20 as bridge transport only:
	- `iot` -> `br-lan.10` with `proto none`
	- `smz_guest` -> `br-lan.20` with `proto none`
	- management remains on `lan` (`br-lan.1`)

This removes overlapping subnet ownership and restores deterministic routing for internet egress
and cross-zone policy enforcement.

#### Staged Rollout (Required)

1. Keep all OpenWrt reconcile CronJobs suspended.
2. Apply gateway first and validate:
	 - clients on `OpenWrt` and `smz_guest` get DHCP from gateway
	 - internet egress works from both SSIDs
	 - `iot -> lan` and `guest -> lan` initiations are blocked
	 - `lan -> iot` and `lan -> guest` initiations work
3. Apply Gemini only, validate management IP and SSID internet access.
4. Apply Hades only, validate the same checks.
5. Resume scheduled reconciles one device at a time.

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
