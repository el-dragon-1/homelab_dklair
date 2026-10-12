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

### Gemini Dual-Band IoT Pilot

Desired Gemini adds `iot_5g` on radio1, mapped to the existing IoT VLAN,
with SSID `OpenWrt`, WPA2-CCMP, and the existing Vault-managed
`openwrt_ssid_key` template. No new secret is required. Client isolation
is off, matching shared automation requirements. Existing 2.4 GHz IoT,
LAN/guest SSIDs, radio channel/width and Hades wireless remain unchanged.

Gemini scheduling is staged suspended for publication and controlled apply.
After sync and checking no active Gemini Job, run one normal manual reconcile;
no network/firewall runtime override is required for this wireless-only batch.
Keep Ethernet management. Verify the new live BSS is actually on 5 GHz
and VLAN 10, and verify the test client is associated with that BSS using
AP station evidence: the shared SSID alone does not establish its band.
Check IoT DHCP, Pi-hole TCP/UDP DNS, ULA, Internet and blocked admin/Vault
paths, while retaining 2.4 GHz and LAN/guest service. Only then extend to Hades.
Rollback removes the new BSS through GitOps and wireless reconcile; restore
scheduling separately after acceptance.

Revision `18e7bee461fc2bd5fe7cf56ead9c68f3a6874094` was synced and applied
by Job `gemini-iot-5g-20261011-1808`, with no failed attempt or runtime
network/firewall override. Live `phy1-ap2` is enabled on channel 149,
5745 MHz/80 MHz, BSSID `de:0d:ab:29:ed:ab`. Netifd confirms its untagged
PVID membership in bridge VLAN 10 alongside the existing 2.4 GHz IoT BSS,
with tagged Ethernet uplink. Existing LAN/guest BSSs remain enabled;
client continuity on those BSSs is not yet certified. Wired Gemini
management, LAN Vault HTTP 200 and all five K3S nodes Ready passed.
After owner Wi-Fi reconnect, the test Mac was authenticated, authorized
and associated on `phy1-ap2` at 5745 MHz. With Ethernet unplugged,
Pi-hole/Vault/Internet routes used en0 via `10.1.1.1`. Pi-hole UDP/TCP
DNS returned NOERROR with answers; system resolver was Pi-hole-only and
ordinary hostname resolution succeeded. Gateway IoT ULA ping and IPv4
HTTPS HTTP 200 passed; gateway TCP 22/80/443 was refused and Vault
TCP 8200 timed out. After Ethernet reconnection, wired management and
LAN Vault HTTP 200 passed, all five nodes stayed Ready, and the Mac
remained on the 5 GHz BSS. Kitchen HomePod remained associated on the
existing 2.4 GHz BSS; Apple functional acceptance is still deferred.

Desired Gemini scheduling is restored to `suspend: false` after pilot
acceptance. Publish and sync this restoration only; no further manual
router Job is needed. Revision `496b4f0b14b0dbdde51acaf09d812fdf08ef6fef` restored live scheduling;
Argo was Synced/Healthy. Unsuspension automatically started catch-up Job
`openwrt-gemini-reconcile-29862681`, which completed without failure.
All five schedules were enabled with no active Jobs afterward.

### Hades Dual-Band IoT Rollout

After Gemini pilot acceptance, desired Hades adds the same `iot_5g`
BSS on radio1: SSID `OpenWrt`, network `iot`/VLAN 10, WPA2-CCMP,
existing Vault-managed `openwrt_ssid_key`, DTIM 1, client isolation off.
Existing 2.4 GHz IoT, LAN/guest BSSs, radio channels/widths and other
devices are unchanged. Hades supports the additional AP interface.

Only Hades scheduling is staged suspended for controlled application.
Publication and live application are pending. After sync and verifying
no active Hades Job, run one normal manual reconcile, without network
or firewall runtime overrides. Preserve wired management. Verify live
5 GHz BSS and VLAN 10 membership, then actual client association on
Hades (not Gemini) and IoT-only DHCP, Pi-hole UDP/TCP DNS, ULA,
IPv4 Internet and blocked gateway administration/Vault paths.
Check existing BSSs and infrastructure before restoring scheduling
in a separate publication. Rollback removes only Hades `iot_5g` and
reconciles wireless through the same workflow.

Revision `ecdfb195919feaf9d9050544fd10749100a8e508` was synced and
applied by Job `hades-iot-5g-20261011-1828`, with no failed attempt.
Network/firewall runtime overrides remained off. Live `phy1-ap2` is
enabled on channel 149/5745 MHz/80 MHz, BSSID `de:0d:ab:29:d1:ef`.
Netifd confirms VLAN 10 untagged/PVID membership with tagged eth1 uplink.
Existing IoT/LAN/guest BSSs remain enabled; client continuity is not yet
certified. Wired Hades management, LAN Vault HTTP 200 and all five
K3S nodes Ready passed. No clients were on the new BSS at inspection;
actual Hades 5 GHz client-path acceptance remains pending.
Hades scheduling remains suspended.

Client-path acceptance subsequently passed at 19:11 CDT. After a full
Wi-Fi toggle near Hades, the Mac was authenticated, authorized and
associated on `phy1-ap2`; association was confirmed again after testing.
With Ethernet unplugged, Pi-hole/Vault/Internet routes used en0 via
`10.1.1.1`; DHCP retained `10.1.1.105` and Pi-hole-only DNS. UDP/TCP
DNS returned NOERROR with answers. Initial UDP had TTL 0/EDNS stale-answer
code 3; repeat UDP returned fresh TTL 132 without that code. System
resolution succeeded, IoT gateway ULA ping passed, and IPv4 HTTPS
returned HTTP 200. Gateway TCP 22/80/443 was refused and Vault TCP 8200
timed out. Ethernet reconnection restored wired Hades management and
LAN Vault HTTP 200; all five K3S nodes remained Ready. Basement Apple TV
remained authorized on the existing 2.4 GHz BSS.

Desired Hades scheduling is restored to `suspend: false`; publish and
sync this restoration without another manual router Job. Live scheduling
remains suspended until sync. Unsuspension can automatically run a missed
scheduled reconciliation. Apple functionality and LAN/guest client
continuity remain outside these completed network-path tests.

### Managed Gateway mDNS Reflection

The gateway reconcile now requires `desired/gateway/avahi-daemon.conf`
in addition to the five UCI packages. In enforce mode on the gateway only,
it installs the supported `avahi-nodbus-daemon` APK when absent, enforces
the configuration, enables the service for boot and restarts it after
interface refresh. Package/config/service failures fail the Job; a bounded
daemon check verifies startup. Remote APs and non-enforce runs skip these
tasks. No new secret or firewall forwarding exception is needed.

Avahi uses IPv4 and IPv6 mDNS only on `br-lan.1` (LAN) and `br-lan.10`
(IoT); the allowlist excludes guest, WAN and all other interfaces.
Reflection is bidirectional and shares service metadata across the two
trust tiers. IPv4-to-IPv6 translation is disabled, and gateway service
publishing is disabled. Existing LAN/IoT input policies permit mDNS;
the old LAN-to-LAN `Allow mDNS` rule is not the reflector.
Discovery does not grant application access, route link-local addresses,
or prove HomeKit/Matter/Thread function. No second reflector should serve
the same pair of networks.

Gateway scheduling is staged suspended for publication and controlled
apply. After sync and no active gateway Job, run one normal gateway
reconcile with wired recovery available. Verify daemon enabled/running,
interface membership and config, LAN-to-IoT and IoT-to-LAN DNS-SD
discovery using known device identities and resolved targets. Use bounded
captures or a controlled test advertisement to verify reflection and
absence on guest/WAN; do not count cached results as fresh proof.
Recheck DHCP/Pi-hole DNS, Internet, administration/Vault isolation,
wired management and cluster health. Restore scheduling separately.
Revision `b7c84e8ac60e76edbeb21d665c9273ec17286a8c` was synced and
applied by Job `gateway-mdns-20261011-1918` without failed attempts.
Avahi 0.9-rc5 is installed, running and boot-enabled; configuration
matches desired. Logs show multicast membership only on LAN/IoT for
both IP families. `fw4 check` passed.

At 19:21 CDT, unique interface-scoped native DNS-SD queries were captured
entering LAN and being re-emitted by the gateway on IoT, and vice versa,
for IPv4 and IPv6. Concurrent 15-second guest/WAN captures had zero
mDNS packets and no kernel drops. This is bounded exclusion evidence,
not a comprehensive guest/WAN audit. Early probes were inconclusive:
the gateway tcpdump build does not decode DNS payload names; use per-interface
ASCII captures or a capable external decoder instead of name matching
against its default output. All capture processes ended and temporary
remote capture files were removed.

LAN-scoped browsing/resolution found Kitchen Speaker and basement at
IoT IPv4/ULA addresses on TCP 7000. With Wi-Fi off and Ethernet routes
confirmed via the gateway, TCP connections to both passed over IPv4
and IPv6: actual LAN-to-IoT forwarding/replies, not same-host traffic.
IoT-scoped discovery resolved Hue Bridge at `192.168.4.168:443` and
Homebridge at `192.168.4.84:51495`. Browse/resolve output alone can be
cached; unique packet probes supply fresh reflection evidence.
Homebridge also advertised old AP-derived ULAs and container addresses;
address-advertisement cleanup remains follow-up, not reflector failure.

At 19:25 CDT with Ethernet unplugged, IoT DHCP/Pi-hole-only DNS, UDP/TCP
DNS, gateway ULA ping and IPv4 HTTPS passed. Initial UDP DNS was stale
(TTL 0/EDNS code 3); repeat returned fresh TTL 215. Gateway TCP 22/80/443
was refused; Vault TCP 8200 and Hue TCP 443 timed out. After Ethernet
reconnection, gateway management, LAN Vault HTTP 200 and Hue TCP 443
passed; all five K3S nodes remained Ready. No application exceptions
were added. Hue still needs planned IoT placement; Apple function remains
unverified.

Desired gateway scheduling is restored to `suspend: false` after these
checks. Publish and sync restoration only, without another manual router
Job. Live scheduling remains suspended until sync; automatic catch-up
reconciliation may run on unsuspension.

Rollback sets `enable-reflector=no` in the desired config and reconciles
the gateway, then verifies cross-VLAN reflection stops. The managed
daemon/package may remain installed with reflection disabled; do not
delete the required config or manually stop a service the next Job enables.

### Wired Hue Migration: Gateway LAN4

Owner confirmed gateway LAN4 connects only to the Hue bridge, not a
downstream switch. The live bridge forwarding table independently learned
MAC `ec:b5:fa:99:ce:e4` on port 4, mapped to `lan4`.
Desired LAN4 is now an IoT-only access port: VLAN 10 untagged/PVID,
removed from VLAN 1 and VLAN 20. Other physical ports and mesh VLAN
transport remain unchanged. Do not use LAN4 for trusted management
or a trunk after this migration.

No Hue reset, pairing removal, application-port exception or DHCP
reservation is required. The bridge currently uses DHCP at LAN
`192.168.4.168`; after migration expect an address in `10.1.1.0/24`.
Verify identity by MAC and bridge ID `ECB5FAFFFE99CEE4`, not old IP.
If it retains its old lease, unplug/replug only the Hue Ethernet cable
to trigger renewal; do not reset the bridge.

Gateway scheduling is staged suspended. Publish, sync, verify no active
gateway Job, then run one normal gateway reconcile with management on
another LAN port. Check live LAN4 VLAN membership, Hue DHCP/neighbor
identity, HTTP identification and DNS-SD target resolution from LAN and
IoT. Test Hue vendor app and existing Apple Home pairing without re-pairing.
Preserve Pi-hole DNS, Internet, gateway administration/Vault isolation,
Avahi and cluster health. Restore scheduling separately after acceptance.
Publication/live migration remain pending.

Rollback restores LAN4 VLAN 1 untagged/PVID and VLANs 10/20 tagged,
then reconciles the gateway and renews only the Hue link if necessary.
Existing Hue pairings must be retained throughout.

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

### Gemini IPv6 Ownership Pilot

Desired Gemini LAN no longer allocates its own ULA prefix (`ip6assign`
removed), and LAN RA/DHCPv6 are explicitly disabled. IPv4 DHCP remains
ignored; management `192.168.4.4`, gateway, DNS, VLANs, wireless, and other
AP/gateway settings are unchanged. The stored global ULA seed is retained
for rollback, but does not allocate a prefix without `ip6assign`.

Gemini's CronJob is staged suspended for the pilot. Publish/sync, verify
suspension and no active Gemini Job, then run one controlled reconcile with
`openwrt_apply_remote_network_runtime=true`. Normal AP reconciliation skips
network runtime apply, so it alone cannot verify prefix removal. Firewall
runtime override is not required. Retain Ethernet gateway/AP management.
Verify live Gemini has no ULA assignment or delegated-prefix routes and
RA/DHCPv6 are disabled; use a bounded observation to check for unexpected
advertisements. Absence in a short capture alone is not proof.

Reconnect/renew a LAN client and test gateway IPv6 Internet, IPv4 DNS, Gemini
management, and IoT ULA/DNS/isolation. Existing client addresses and routes
may linger until their advertised lifetimes expire; reconnect is not a
guaranteed purge. Do not mark migration complete while stale Gemini-derived
state remains unaccounted for. Other APs, especially Hades' Apple-related
delegation, remain unchanged. Publication/application and validation are pending.

Rollback: restore Gemini's prior `ip6assign=60` and RA/DHCPv6 server options
through GitOps, run a manual reconcile with the same network runtime override,
and renew clients. Restore Gemini scheduling separately after acceptance.

2026-10-11 pilot applied at approximately 17:29 CDT from revision
`d1f5c31cf3519e2457cc3603225ee521bbda34a2`, manual Job
`gemini-ipv6-pilot-20261011-1730`, with the network runtime override.
Gemini retains IPv4/link-local management but no ULA assignment, active
DHCPv6 leases, or delegated-prefix routes. The stored ULA's unreachable
aggregate route remains. RA/DHCPv6 are disabled. A first observation was
interrupted by scheduled gateway interface refresh; replacement observation
found no Gemini RAs and was stopped explicitly.

The test Mac initially retained old Gemini addresses/routes, but these were
absent after a later Ethernet reconnection. LAN IPv6 Internet remained
functional; IoT DHCP/ULA/DNS/Internet and tested administration/Vault blocks
passed. Former clients beyond this Mac remain unverified. Desired Gemini
schedule restoration is prepared; live scheduling remains suspended until
publication/sync. Do not create another manual Job just to resume scheduling.

### Orchid IPv6 Ownership Cleanup

Following the Gemini pilot, desired Orchid removes LAN `ip6assign=60`
and explicitly disables LAN RA/DHCPv6. Management `192.168.4.5`, IPv4
DHCP ignore, mesh/bridge transport, wireless, and other devices are unchanged.
The global ULA seed remains for rollback. Pre-change inspection found an
empty DHCPv6 lease file but active `fd9c:94b:faa4` delegated-prefix routes;
do not equate an empty lease file with no runtime dependencies.

Orchid scheduling is staged suspended. Publication/application are pending.
After sync and verification of suspension/no active Orchid Jobs, run one
manual reconcile with `openwrt_apply_remote_network_runtime=true`, retaining
Ethernet recovery and leaving firewall runtime override disabled. Verify
management, absence of ULA assignment/delegated routes and disabled RA/DHCPv6,
then LAN IPv6 Internet/DNS and IoT ULA/DNS/isolation. Account for lingering
client addresses/routes; bounded capture silence alone is not certification.
Other AP cleanup and Apple/Thread functional validation remain separate.

Rollback: restore Orchid's prior LAN prefix and RA/DHCPv6 server options
through GitOps, reconcile with the same network override, and renew clients.
Restore scheduling separately after acceptance, without an extra manual
reconcile solely for scheduling.

2026-10-11 Orchid acceptance: revision
`08fc220cc4a0118e5450b6493e63e210992800cd`, Job
`orchid-ipv6-cleanup-20261011-1738`, applied with network override.
First attempt lost SSH after network refresh; automatic retry succeeded.
RA/DHCPv6, active ULA assignment and delegated routes are removed; link-local
and IPv4 management remain. A stale-prefix RA send failed during refresh;
after client reconnection, the test Mac had no Orchid-derived addresses/routes.
LAN IPv6 Internet and IoT ULA/DNS/Internet/tested isolation passed.
No packet observation or all-client validation was performed in this batch.
Desired Orchid schedule restoration is prepared, but live scheduling remains
suspended until publication/sync; no extra manual reconcile is needed.

### Intermediate AP IPv6 Ownership Cleanup

Desired AP removes LAN `ip6assign=60` and disables LAN RA/DHCPv6.
IPv4 management `192.168.4.2`, default gateway, DNS forwarding, bridge/mesh,
wireless, and other devices remain unchanged. Global ULA seed is retained.
Pre-change AP leases include node2/node3 and the test Mac; node3 has an
AP-derived delegated `/62`. Owner explicitly approved this infrastructure
scope with before/after checks; it is not limited to noncritical IoT clients.

AP CronJob is staged suspended. Publication/application are pending.
Before apply, record K3S node health/addressing, DNS/Vault health, and LAN
IPv6 Internet; confirm no unexpected dependency on `fd08:2419:f30::/48`.
Sync suspension, verify no active AP Job, and apply one manual reconcile
with `openwrt_apply_remote_network_runtime=true`, firewall override disabled.
The intermediate bridge refresh may interrupt downstream/mesh connectivity;
retain wired gateway recovery and verify AP/downstream management afterward.

Check removal of ULA allocation/leases/delegated routes and disabled RA/DHCPv6.
Repeat infrastructure and client checks; account for lingering node/client
addresses/routes before certifying migration. An unreachable ULA aggregate
may remain without assigning addresses. Hades' delegation is unchanged.
Rollback restores the AP prefix/server settings via GitOps and the same
network runtime override, then renews clients. Resume AP scheduling separately
only after acceptance. Do not broaden to Hades in this batch.

2026-10-11 acceptance: revision
`3c4c7e63c396383b3414b2618e6889aaeab03b9f`, manual Job
`ap-ipv6-cleanup-20261011-1746`, succeeded with network runtime override.
AP ULA allocation/leases/delegated routes are removed and RA/DHCPv6 disabled.
AP/downstream SSH management, all five K3S nodes, Vault, LAN IPv6 Internet,
and tested IoT ULA/DNS/Internet/isolation paths remained functional.
The renewed Mac has no AP-derived addresses/routes. Node2/node3 host-level
stale IPv6 state and other client dependencies remain unverified.
Desired AP schedule restoration is prepared; live scheduling remains
suspended until publication/sync. Hades is unchanged.

### Hades IPv6 Ownership Cleanup

Desired Hades removes LAN `ip6assign=60` and disables RA/DHCPv6, preserving
IPv4 management `192.168.4.3`, VLAN/Wi-Fi transport and gateway settings.
Hades scheduling is staged suspended. At 17:51 CDT its lease file was empty
but delegated ULA routes remained with changed next-hop mappings. Earlier
Apple RAs advertised subprefixes from this pool; this is an active prefix
migration, not proof that the pool is unused.

Publish/sync suspension, check active Jobs and current border-router routes,
and apply one manual reconcile with the network runtime override enabled.
Keep wired recovery and firewall override disabled. Verify prefix/route
removal, management, K3S/Vault/DNS, LAN IPv6 Internet, and IoT ULA/DNS/isolation.
Reconnect clients and account for stale prefixes; observe Apple RAs and
test Home/Siri/Thread where available. Gateway SLAAC is not replacement
Thread prefix delegation. Do not reset accessories or assume old delegated
prefix identifiers remain unchanged.

Rollback restores Hades' prior prefix/server settings through GitOps with
the same network override and renewed clients. Restore scheduling separately
after scoped acceptance. Publication/application and validation are pending.

2026-10-11 Hades acceptance: revision
`042be17dc76744f7457d2c64266a7d80055f1801`, manual Job
`hades-ipv6-cleanup-20261011-1753`, succeeded with network runtime override.
Live RA/DHCPv6, ULA assignment and delegated routes are removed; IPv4 and
link-local management remain. K3S/Vault, LAN IPv6 Internet, and tested IoT
ULA/DNS/Internet/isolation paths passed. The renewed Mac has no Hades-derived
LAN addresses/routes, but Apple routers still advertise an old Hades route
alongside gateway-derived `fd47:eab4:aa15:c::/64`.
Gateway lease/route evidence confirms a new `/62` delegation to the DUID
previously associated with `Living-Room`. Thread/Matter/Home functionality
and withdrawal of the old advertisements remain unverified.
Desired Hades scheduling restoration is prepared; live scheduling remains
suspended until publication/sync. All AP cleanup settings are now deployed,
not a certification of complete IPv6 isolation or all-client stability.

### Gateway IoT IPv6 Settings

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
