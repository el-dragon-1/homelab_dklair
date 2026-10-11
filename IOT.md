# IoT Network Layout, Trust, and Troubleshooting

## Purpose and Status

Maintain an inventory of household devices, their trust assessment, network placement,
communication dependencies, and functional validation. Separate observed facts from
recommendations so an untested layout is never mistaken for a known-good configuration.

Last read-only inventory: **2026-10-11, approximately 10:55 a.m. America/Chicago**.
Earlier diagnostics on the same date supply the incident evidence below.
This document does not authorize or apply network changes.

Selected target (2026-10-11): Apple Home hubs, Hue, and household automation devices
on IoT VLAN 10 using 2.4 GHz, 5 GHz, or wired access as appropriate; owner endpoints
remain on trusted LAN. Pi-hole remains on LAN with a DNS-only exception.
This supersedes the earlier simplest-recovery recommendation to place hubs on LAN.

- **Observed**: supported by live configuration, a lease, a service response, or user confirmation.
- **Reported**: supplied by the owner; not independently function-tested.
- **Provisional**: identification or trust assessment needs owner confirmation.
- **Proposed**: placement or policy not yet applied.
- **Validated stable**: all applicable acceptance tests pass and the observation period completes.

A DHCP lease is not proof a device is online. A hostname or MAC vendor is not proof of
identity or trust. Leased addresses below are snapshots, not reservations.
The inventory is not complete until offline, static-address, wired, and non-IP devices
have been accounted for.

## Configuration Sources

- [OpenWRT operating model](openwrt/README.md)
- [Gateway network/VLANs](openwrt/desired/gateway/network.uci)
- [Gateway firewall](openwrt/desired/gateway/firewall.uci)
- [Gateway DHCP/DNS](openwrt/desired/gateway/dhcp.uci)
- [Hades Wi-Fi](openwrt/desired/hades/wireless.uci) and [Gemini Wi-Fi](openwrt/desired/gemini/wireless.uci)
- [Hades bridging](openwrt/desired/hades/network.uci) and [Gemini bridging](openwrt/desired/gemini/network.uci)
- [Reconcile runtime actions](apps/openwrt-ops/configmap-ansible-automation.yaml)
- [Hardware inventory](HARDWARE.md)
- [Pi-hole operational context](values/pihole/context.md)

`openwrt/desired` is the enforced configuration; `openwrt/baseline` is read-only evidence.
Live state must be checked independently because configuration and runtime can differ.

## Observed Logical Topology

```text
Internet / upstream router
  |
OpenWRT gateway 192.168.4.1
  |-- VLAN 1 / lan / 192.168.4.0/24
  |     |-- smz_homex (Hades and Gemini, 5 GHz)
  |     |-- owner phones, tablets, computers, Watch
  |     |-- Hue bridge 192.168.4.168
  |     |-- Living Room Apple TV 192.168.4.220
  |     `-- router management, compute nodes, DNS service
  |
  |-- VLAN 10 / iot / 10.1.1.0/24
  |     |-- OpenWrt (Hades and Gemini, 2.4 GHz)
  |     |-- Kitchen Speaker HomePod 10.1.1.148
  |     `-- plugs, sensors/controllers, unidentified devices
  |
  `-- VLAN 20 / smz_guest / 10.2.2.0/24
        |-- smz_guest (Hades and Gemini, 5 GHz, client isolation)
        `-- SonosZP lease 10.2.2.126
```

This is a logical diagram, not a verified cable/room map. Gateway, AP, and Orchid
provide 5 GHz mesh transport; AP and Orchid had no client AP SSIDs in the inspected
runtime configuration. Hades and Gemini transport VLANs 10/20 without owning their
subnets. Do not assume every mesh path carries every VLAN; verify the actual path
before attaching a segmented client or changing an uplink.

### Networks and Wi-Fi

| VLAN / interface | Gateway / subnet | SSID | Current Wi-Fi policy | Intended role |
|---|---|---|---|---|
| 1 / `lan` | `192.168.4.1/24` | `smz_homex` | 5 GHz, WPA2/WPA3 mixed, 802.11r enabled, client isolation off | Owner endpoints and currently shared infrastructure |
| 10 / `iot` | `10.1.1.1/24` | `OpenWrt` | 2.4 GHz, WPA2-CCMP, DTIM 1 | Constrained household IoT |
| 20 / `smz_guest` | `10.2.2.1/24` | `smz_guest` | 5 GHz, WPA2/WPA3 mixed, client isolation on | Visitors; not a general-purpose automation network |

Both client APs use 5 GHz channel 149 / HE80. Desired 2.4 GHz channels are Hades 1
and Gemini 6; earlier live inspection found Hades 6 and Gemini 1. Record that drift,
but do not infer it caused the incident. Same-channel AP contention and roaming
compatibility remain measurements to make, not established causes.

Gateway wired bridge ports `lan1` through `lan4` and `sfp2` carry VLAN 1 untagged/PVID
and VLANs 10/20 tagged. Hades/Gemini `eth1` follows the same logical tagging pattern.
Physical switch port assignments and wired accessory placement still need confirmation.

### DHCP, DNS, and IPv6

| Network | DHCP pool / lease duration | Advertised DNS |
|---|---|---|
| LAN | `.50` through `.249` / 12 hours | `192.168.4.102` (Pi-hole) |
| IoT | `.100` through `.249` / 12 hours | `192.168.4.102` (Pi-hole only; verified 2026-10-11) |
| Guest | `.100` through `.249` / 2 hours | `192.168.4.102`, `1.1.1.1` |

Gateway is the intended IPv4 DHCP/L3 owner. Hades/Gemini have `dhcp.lan.ignore=1`,
but also retain DHCPv6/RA server settings. Their IPv6 ownership/advertisements require
separate validation; do not treat IPv4 DHCP suppression as proof IPv6 is correct.

Pi-hole resolved `apple.com` from the gateway during diagnostics. That does **not**
prove an IoT/guest client can use it: its LAN address conflicts with the current
IoT/guest-to-LAN restrictions unless a suitable exception exists. Test TCP and UDP
DNS from each client network. Multiple advertised resolvers do not guarantee ordered
fallback or consistent filtering. IPv6 routing, firewall behavior, DNS, and Matter
reachability have not been certified.

### Traffic and Discovery Policy

| Initiator -> destination | Current intent/evidence |
|---|---|
| LAN -> Internet | Allowed |
| IoT / guest -> Internet | Allowed by forwarding policy; individual devices still need tests |
| LAN -> IoT / guest | Allowed; return traffic for established flows is distinct from new reverse connections |
| IoT / guest -> LAN | Explicit IPv4 DROP rules; no general reverse access |
| IoT -> IoT | Not per-device isolated by the documented layout; verify peer reachability |
| Guest Wi-Fi client -> guest Wi-Fi client | AP client isolation enabled; not proof of isolation across all wired/AP paths |
| IoT <-> guest | No explicit inter-zone forwarding in the inspected desired policy |
| IoT / guest -> gateway services | Zone input is ACCEPT; these networks are not isolated from all router services |

The existing "Allow mDNS" rule is **LAN -> LAN**, IPv4 `224.0.0.251`, UDP source
and destination port 5353. It is not a multicast reflector or a cross-VLAN permission.
Its zero counter does not mean bridged mDNS is broken.

No Avahi/umdns reflector was found on the five inspected routers. LAN mDNS packets
were captured, and LAN AirPlay/Hue advertisements were visible. Bridge multicast
snooping was off on gateway/Hades/Gemini; `smz_homex` client isolation was off.
Discovery and application access are separate requirements: reflecting advertisements
does not permit the advertised service through the firewall.

## Trust Assessment and Placement Rules

Use qualitative tiers, not a numeric score that suggests unsupported precision.
Trust means accepted access for a defined role, not that a vendor/device is inherently safe.
Functionality requirements do not automatically justify unrestricted access.

| Tier | Criteria / evidence required | Placement recommendation |
|---|---|---|
| T0: infrastructure | Owner-administered routing, DNS, compute; verified management and updates | Current LAN; a dedicated management/server segment is a future design, not an existing network |
| T1: owner endpoint | Known owner, supported OS, current patches, protected accounts | `smz_homex` / LAN |
| T2: local automation dependency | Known device, supported firmware, documented local hub/bridge/media role | Co-locate hubs, bridges, and accessories on IoT VLAN 10; provide scoped discovery and trusted-controller access, not general IoT-to-LAN access |
| T3: constrained IoT | Known purpose and owner; does not need unrestricted trusted-network access | `OpenWrt` / IoT; scoped exceptions only for verified dependencies |
| T4: guest or unidentified | Visitor, unsupported device, or identity/ownership not yet established | Guest for visitors; unidentified resident devices get no promotion and need identification before any move |

Before approving T0-T3, record exact model, owner, support/update status, credentials
and account protection status (never the credentials themselves), local/cloud
dependencies, sensitivity, and required initiators/destinations. Unsupported or
unidentifiable devices remain constrained regardless of brand.
An unidentified device already on LAN is an inventory gap, not an approved trusted endpoint.

## Device Inventory and Proposed Placement

Validation profiles are defined below. Every row requires its assigned profile before
placement is considered successful. Tier recommendations remain provisional until
ownership, model, and firmware are confirmed.

### Household and Automation Devices

| Device / identity evidence | Observed address / network | Tier / proposed placement | Evidence and validation remaining |
|---|---|---|---|
| Kitchen Speaker; `HomePod`, `a4:cf:99:ab:5e:91` | `10.1.1.148` / IoT | T2 / retain IoT; 5 GHz if supported and signal adequate | Owner re-added it and confirmed active home hub; ping passed. A profile required; new layout not validated |
| Living Room Apple TV; AirPlay model `AppleTV14,1`, `c4:f7:c1:5a:a1:2f` | `192.168.4.220` / LAN | T2 / proposed IoT | AirPlay discovery and ping passed. A profile and hub failover untested |
| Main Bedroom; AirPlay service name only | Address/physical device unconfirmed | T2 candidate / IoT if Apple Home/media hub confirmed | Identify device/model; A profile |
| Hue bridge; Signify BSB002, `ec:b5:fa:99:ce:e4` | `192.168.4.168` / LAN | T2 / proposed wired IoT with Apple Home hubs | HTTP identification, public API, and `_hue._tcp` passed; owner reports Hue app works, Apple Home does not. H profile |
| Hue lights/accessories behind bridge | Count, rooms, models, and Zigbee membership unknown | T3 accessories behind T2 bridge; no direct IP placement unless separately verified | Inventory each light/sensor/switch; H profile per accessory |
| SonosZP, `74:ca:60:a8:ac:ce` | `10.2.2.126` / guest lease | T2/T3 candidate / placement pending media dependencies | Guest isolation may conflict with discovery/grouping; identity and S profile required |
| EP25, `30:68:93:36:c2:62` | `10.1.1.103` / IoT | T3 / retain IoT if identity confirmed | Lease model label only; P profile |
| Unnamed, `30:68:93:36:f8:99` | `10.1.1.104` / IoT | T4 pending identity / no promotion | Similar MAC prefix is not device identification; U then appropriate profile |
| Unnamed, `74:fe:ce:fd:89:f5` (earlier lease label EP25) | `10.1.1.130` / IoT | T3 candidate / retain IoT pending identity | P profile after owner mapping |
| `flo-64694e321baf`, `64:69:4e:32:1b:af` | `10.1.1.115` / IoT | T3 candidate / IoT | Name suggests a controller but exact purpose unconfirmed; U then C if water controller |
| `sv3-90380C86F4C0`, `90:38:0c:86:f4:c0` | `10.1.1.120` / IoT | T3 candidate / IoT | U; confirm whether camera before selecting C |
| `basement`, `1c:b3:c9:03:1c:9a` | `10.1.1.233` / IoT | T4 pending identity / no promotion | Room label alone does not identify hardware; U |
| `MyQ-C91`, `24:18:c6:fb:ba:58` | `10.1.1.191` / IoT | T3 candidate / retain IoT | Confirm garage controller; C profile, supervised physical tests only |
| Unnamed, `00:c5:26:16:bf:eb` | `10.1.1.185` / IoT | T4 / no promotion | U |
| Unnamed, `00:c5:26:16:d2:71` | `10.1.1.244` / IoT | T4 / no promotion | U |
| Unnamed, `9a:f0:a4:a4:34:67` | `10.1.1.119` / IoT lease | T4 / no promotion | U; earlier neighbor entry was incomplete, not confirmed online |
| Unnamed, `74:ca:60:a8:a9:32` | `192.168.4.73` / LAN | T4 / review existing LAN access | Do not identify by vendor prefix; U |
| Unnamed, `7c:c2:55:e8:51:02` | `192.168.4.68` / LAN lease | T4 / review existing LAN access | U; no functional evidence |
| Homebridge TPLink Smarthome E85F; Homebridge 4CE9 0ED3 | LAN `_hap._tcp` services; hosts unconfirmed | T0/T2 candidate / placement pending hosting identity | Map services to host/process and integrations; H/P profiles; not necessarily two physical devices |

Matter browsing found two operational service instances on the LAN, but they were
not resolved to device identities. Do not claim either belongs to Hue or that native
HomeKit is in use. Confirm Hue's Apple Home integration method before defining ports.

### Owner Endpoints

| Lease label / MAC | Observed LAN address | Provisional tier / placement | Validation |
|---|---|---|---|
| Davids-Air / `34:36:3b:62:61:b4` | `192.168.4.198` | T1 / retain LAN after owner confirmation | E |
| Mac / `66:0e:68:8f:20:b0` | `192.168.4.137` | T1 / retain LAN after owner confirmation | E |
| MacBookPro / `6a:99:c2:c8:d1:32` | `192.168.4.240` | T1 / retain LAN after owner confirmation | E |
| iPad / `12:a4:18:fa:81:b9` | `192.168.4.182` | T1 / retain LAN after owner confirmation | E |
| Watch / `0e:ce:8b:e1:b6:b3` | `192.168.4.125` | T1 / retain LAN after owner confirmation | E |
| iPhone / `be:82:17:dc:10:54` | `192.168.4.175` | T1 / retain LAN after owner confirmation | E |
| Unnamed / `0e:8b:eb:1a:b7:1d`; earlier iPhone label | `192.168.4.117` | T1 candidate / confirm owner | U then E |
| Kristen's MacBook Air; AirPlay name only | Address unconfirmed | T1 candidate / confirm owner | U then E |

Private/rotating MACs can make one endpoint appear under multiple records. Match
against owner device settings; do not merge rows or create reservations on guesses.

### Infrastructure and Supporting Services

| Device/service | Address | Tier / placement | Evidence / validation |
|---|---|---|---|
| Gateway, Banana Pi R3 | `192.168.4.1` | T0 / LAN management | Live SSH inspected; N |
| AP, Banana Pi R3 | `192.168.4.2` | T0 / LAN management | Live SSH inspected, mesh-only radio; N |
| Hades, Cudy M3000 | `192.168.4.3` | T0 / LAN management | Live SSH inspected, client SSIDs; N |
| Gemini, Cudy M3000 | `192.168.4.4` | T0 / LAN management | Live SSH inspected, client SSIDs; N |
| Orchid, Cudy M3000 | `192.168.4.5` | T0 / LAN management | Live SSH inspected, mesh-only radio; N |
| node1 / node2 / node3 | `192.168.4.110` / `.115` / `.116` | T0 / retain LAN pending any separate server design | Hardware records + leases; N per node |
| orangepi5 / el_dragon | `192.168.4.84` / `.213` | T0 / retain LAN | Hardware records + leases; N per node |
| lb-2, `dc:a6:32:c3:21:35` | `192.168.4.177` | T0 candidate / confirm role | Reservation + lease, actual workloads unverified; U then N |
| Pi-hole service (not a separate physical device) | `192.168.4.102` | T0 / LAN-hosted DNS | DNS response observed; N/D from each VLAN |
| Netgear GS108PE switch | Management address/ports unconfirmed | T0 / management placement pending | Hardware record only; U/N and port map |
| APC Back-UPS Pro 1500VA | Network interface unconfirmed | No IP tier unless networked | Hardware record only; inventory monitoring connection |

## Layout Candidates and Stability Record

| Layout | Benefit / tradeoff | Status |
|---|---|---|
| Current split: Kitchen hub on IoT, Hue/Apple TV on LAN | Limits IoT initiation but prevents needed hub-to-LAN IPv4 connections and cross-VLAN discovery | **Not validated stable**; Apple Home/Hue failure reported |
| Selected target: owner endpoints on LAN; Apple Home hubs, Hue bridge, and automation on VLAN 10; visitors on VLAN 20 | Co-locates hubs/accessories while separating automation from trusted endpoints; requires LAN/IoT discovery, IPv6, and DNS-only LAN access | **Owner-selected candidate, not applied or validated** |
| Earlier recovery option: hubs and Hue on LAN | Simplest local discovery but exposes trusted LAN to automation devices | **Superseded recommendation** |
| Future dedicated automation segment with controllers and their accessories together | Limits exposure to management/compute; owner control still needs scoped inter-segment policy and discovery | **Design option only**; no such VLAN currently exists |
| Keep hubs/accessories split with scoped cross-VLAN discovery and access | Preserves separation; more complex IPv4/IPv6, Matter/HomeKit, media, and hub-failover requirements | **Design option only**; no approved service matrix or reflector |

No whole-home layout is certified stable yet. Hue app operation, HomePod ping, and LAN
Bonjour are partial successes, not end-to-end automation validation. Do not use guest
isolation for permanent media equipment without testing all required functions.

For a future split layout, record source controller(s), destination device(s), protocol,
port, address family, discovery service, reason, and negative isolation test for every
exception. Include all eligible home hubs, not just the currently active one.
Do not broadly allow IoT -> LAN or guess a universal HomeKit/Matter port list.

## Ordered Rollout: GitOps Versus Manual Work

**New prerequisite: repair Gemini's IoT/guest mesh transport before DNS access.**
Owner confirmed `Gemini -> AP -> mesh -> gateway` and `Hades -> gateway`.
At approximately 15:47 on 2026-10-11, laptop MAC `aa:40:37:53:2c:09` completed
WPA2 authentication on Gemini but retained `169.254.239.194` with DHCP "no server."
Gemini runtime correctly places its IoT radio in VLAN 10; gateway runtime mesh port
was only in VLAN 1. Gateway DHCP captures during a retry showed no arriving requests.
AP uses a non-filtering Ethernet/mesh bridge. Together these identify missing
gateway mesh VLAN admission as a concrete transport defect, not a wrong-password
diagnosis. Exact end-to-end restoration remains subject to client validation.

Desired gateway network configuration now explicitly includes `phy1-mesh0` in its
bridge: VLAN 1 untagged/PVID, VLANs 10/20 tagged. Desired wireless pins that existing
interface name. AP/Gemini configurations, credentials, firewall policy, and DHCP
ownership are unchanged. Publish and apply gateway only in a controlled window,
then verify runtime VLAN membership, Gemini client DHCP, and guest transport.
Retest after wireless reload/reconcile to prove persistence. Do not proceed to the
DNS-only milestone until client VLAN transport works and isolation is preserved.
See [mesh transport notes](openwrt/README.md#gemini-mesh-vlan-transport).

At approximately 16:03 local time, gateway Job `mesh-vlan-gateway-20261011-1602`
completed after publication of revision `4377f97a63efa0c441cedc284522c98424839cd4`.
Runtime VLANs 10/20 include tagged `phy1-mesh0`; LAN management remains untagged.
The Gemini-connected laptop automatically obtained `10.1.1.105`, with DHCP server
and router `10.1.1.1`; gateway logs show DISCOVER/OFFER/REQUEST/ACK.
An HTTP probe explicitly bound to Wi-Fi `en0` reached the IoT gateway.
Gemini association and gateway mesh peers remain established. Vault remained
unsealed at `.103`, workstation Pi-hole DNS resolved, and K3S API readiness passed.
These confirm IoT DHCP transport restoration after the reconcile's wireless reload.
Guest client DHCP, later scheduled-reconcile persistence, and client-side negative
isolation tests remain pending. Existing IoT/guest-to-LAN DROP rules are still loaded;
their presence alone is not a completed isolation test. No DNS exception was added.

**Vault VIP separation and owner login are confirmed; long-term observation remains.**
Vault now uses `.103`, protected by its gateway DHCP reservation; Pi-hole remains
`.102`. See the
[two-phase migration and rollback plan](values/vault/context.md).
On 2026-10-11 approximately 15:06, all Vault VIP fields matched `.103`, repeated
health checks and a fresh ExternalSecret refresh passed, and Pi-hole TCP/UDP DNS
remained functional. kube-vip required an owner-approved active-pod restart to
complete advertisement. Mail VIP workstation reachability remains an unresolved
post-restart check; this is not proof of a migration-caused regression.
Owner confirmed successful Vault login at 15:20 local time on 2026-10-11.

All Kubernetes operations for this repository must use **K3S**. Select it with
`kubectl config use-context K3S`, verify `kubectl config current-context`, and use
`kubectl --context K3S` explicitly for subsequent commands. Never substitute Talos
or another cluster when authentication fails.

On 2026-10-11 at approximately 13:39 local time, the K3S kubeconfig retry succeeded.
The earlier 13:22 authentication failure is resolved. Read-only verification found:

- `pihole-dns` exposes TCP/UDP 53 at **192.168.4.102**; `pihole-web` is ClusterIP.
- Pi-hole and OpenWRT Argo CD Applications report Synced/Healthy.
- All five OpenWRT CronJobs are unsuspended, with no active Jobs at the observation
  time. Retained gateway/AP Jobs each report one successful completion.
- Gateway runs every half hour; AP at :07/:37, Hades :14/:44, Gemini :21/:51,
  and Orchid :28/:58. These are live schedules, not just repository intent.
- Pi-hole uses chart 2.36.0 with this repository's values at `HEAD`. Local desired
  values previously specified `192.168.4.200`, unlike the advertised `.102` Service.
  At approximately 13:58, after the owner pushed the `.102` change, a requested
  Argo CD sync succeeded at revision `e6f4d4606dd771fb06a1bd60564dd80ed7322dfd`.
  Pi-hole is Synced/Healthy; Service request, kube-vip annotation, and advertised
  address now all equal `.102`. Explicit workstation UDP/TCP DNS tests passed.
  See [Pi-hole validation history](values/pihole/context.md). Vault shares `.102`
  on TCP 8200; DNS-only exceptions remain essential.

Argo CD deploys Kubernetes resources, including the OpenWRT automation. Router
reconcile Jobs separately clone `main` and apply desired UCI state over SSH.
Local edits, an unmerged branch, or an Argo CD sync alone do not apply router UCI.
The current playbook only manages `system`, `network`, `dhcp`, `firewall`, and
`wireless`; an mDNS reflector requires an explicit automation extension.

| Order | GitOps / desired configuration work | Manual work and validation gate |
|---|---|---|
| 1. Prepare maintenance and recovery | Declaratively suspend relevant reconcile CronJobs through Argo CD; inspect recurring runtime refresh behavior before resuming schedules | K3S access is verified. Map Hue switch port, VLAN uplinks, management path, all Apple hubs, and Hue integration method. Recheck active Jobs at the maintenance window; suspension does not stop active Jobs. Preserve trusted-LAN access and record rollback state |
| 2. Confirm durable DNS endpoint (address alignment complete) | Pi-hole desired request, kube-vip annotation, and advertised address now match `192.168.4.102` after a successful sync | Workstation UDP/TCP DNS passed; preserve `.102` and account for Vault sharing this VIP. DHCP pool overlap remains a separate allocation review |
| 3. Prove scoped DNS access | Add IoT-to-`192.168.4.102` TCP/UDP destination port 53 exception before broad LAN DROP rules once step 2 confirms address continuity. Keep general IoT-to-LAN blocks. Guest DNS is a separately approved exception | Run UDP/TCP DNS tests from a real IoT client; confirm Pi-hole receives queries and administration/unrelated LAN services stay blocked |
| 4. Align DHCP DNS | Retain the confirmed Pi-hole address in desired IoT DHCP configuration; remove public secondary DNS if consistent Pi-hole use is approved. Keep Pi-hole service changes out of this batch unless separately validated | Renew a test client's lease and verify actual resolver use. Keep a working DNS path throughout; DHCP advertisement alone does not enforce resolver use |
| 5. Establish IPv6 and gateway isolation | Define gateway-owned IoT IPv6 addressing/RA and routing; review AP DHCPv6/RA settings; preserve required ICMPv6. Verify equivalent IPv4/IPv6 isolation and limit IoT access to router administration | Test IPv6 routes, DNS, and negative isolation checks. Matter/Thread paths require specific validation; an mDNS reflector does not route link-local addresses |
| 6. Add 5 GHz IoT Wi-Fi | Add a 5 GHz IoT AP interface on Hades/Gemini mapped to VLAN 10, retaining 2.4 GHz IoT and existing LAN/guest SSIDs. Keep automation client isolation off | Approve SSID/credential policy; apply one AP at a time and test VLAN/DNS/reconnection. Existing conservative AP network/firewall runtime defaults require an explicit staged apply if those settings change |
| 7. Deploy discovery | Extend automation to install/configure/start a supported gateway mDNS reflector, limited to LAN and IoT. Persist package/config/service lifecycle; exclude guest/WAN | Verify service discovery and actual application reachability from trusted LAN; document any scoped additional protocol exceptions |
| 8. Pilot wired Hue and Apple hubs | Add verified reservations if useful; preserve LAN-to-IoT initiation and established replies while blocking unrelated IoT-to-LAN initiation | Configure Hue's switch port as untagged VLAN 10/PVID 10; ensure uplinks carry VLAN 10 and management remains reachable. Move one additional Apple hub to IoT Wi-Fi, keep Kitchen on IoT, and test from a trusted-LAN phone without resetting pairings |
| 9. Complete migration and certify | Resume reconcile schedules gradually only after their runtime behavior is verified. Record approved settings and results in this document | Move remaining identified automation devices in batches; test Home/Hue, Siri, AirPlay, remote cellular control, automations, and hub failover. Observe at least 48 hours before marking stable |

The first implementation batch is steps 1-4 only, with separate apply/test gates:
establish maintenance ownership, confirm the durable DNS endpoint, prove the DNS-only
exception, then update DHCP. K3S authentication is no longer a pending step.
Do not combine this batch with Wi-Fi, switch, or accessory migration.
Each later batch needs a known rollback path before it starts; device placement and
switch port rollback are manual, while desired router/automation rollback is through Git.

## Per-Device Acceptance Tests

For **every inventoried device**, record identity, proposed/actual network, test date,
tester, firmware, and result for each applicable test. Record failures explicitly.
Device actions below are acceptance criteria for an approved future test session,
not actions performed during this read-only inventory.

### Common Baseline (B): All IP Devices

1. Confirm device identity against owner settings, physical label, or authenticated UI.
2. Verify association/link, expected VLAN, gateway, DHCP/reservation, and no address conflict.
3. Test actual DNS use (TCP/UDP where applicable), time synchronization, required Internet
   access, and update availability from that device's network. Router-origin tests are insufficient.
4. Test required local discovery and application connections from the real controller.
5. Verify unwanted cross-network initiation is blocked, including IPv6 if enabled.
6. Check reconnection after an approved restart/lease renewal and normal roaming where relevant.
7. Observe at least 48 hours, including scheduled reconcile cycles and an overnight period.
   Log interruption times; a layout with recurring disruption does not pass.

### Functional Profiles (Each Includes B)

| Profile | Required functional evidence |
|---|---|
| A: Apple Home hub/media | Home app control from owner phone; Siri response; AirPlay discovery/playback; automations; remote control over cellular; active hub identification; approved hub failover with Hue still responding |
| H: Hue/Homebridge lighting | Hue app and Apple Home agree; each mapped light responds and reports state; sensors/switches trigger expected actions; scenes/automations work; native HomeKit versus Matter path documented |
| S: Sonos/media | Vendor app discovery/control, playback, grouping and synchronization; AirPlay if supported; discovery across intended controller path |
| P: plugs/switches | Vendor and intended local integration control/status; timers and automations; recovery after reconnect; test loads safely without interrupting essential equipment |
| C: camera/water/garage controller | Confirm subtype; required monitoring, alerts, local/cloud access, and recovery; physical actuation only with owner supervision and safety clearance |
| E: owner endpoint | Normal DNS/Internet; Home/Hue/media control where applicable; Wi-Fi roaming; required access without guest/IoT privileges leaking |
| N: infrastructure | Management access, correct VLAN transport, DNS/DHCP ownership, relevant service health, and no unnecessary reconcile-triggered outages |
| D: DNS service path | Real clients on LAN/IoT/guest can resolve through their advertised resolver; UDP/TCP and IPv6 where used; expected filtering and upstream behavior verified |
| U: unidentified | Identify owner/model/function before selecting a tier or approving placement; then run B and the relevant profile |

### Validation Ledger

Add one result row per device/profile, retaining failures and linking any corrective change.

2026-10-11 approximately 16:10-16:11, owner-run IPv4 isolation baseline:
Vault `.103:8200` returned healthy/unsealed JSON with Ethernet connected. With
Ethernet unplugged, Wi-Fi was `10.1.1.105` and the route to Vault used `en0` via
`10.1.1.1`; the same Vault request timed out. Explicit UDP and TCP DNS queries to
Pi-hole `.102:53` also timed out before any DNS exception was added.
These are expected results for the tested IoT-to-LAN paths, not a full IPv6 or
all-services isolation certification. Firewall counters were not correlated.
After adding the scoped DNS exception, repeat both DNS tests and the blocked
Vault probe from the same verified IoT-only path.

Desired gateway firewall now includes `Allow IoT to Pi-hole DNS` before the broad
IoT-to-LAN DROP rules: IPv4 source `iot_zone`, destination `lan`, address `.102`,
TCP/UDP destination port 53 only. Revision
`4019ea122271ca9bbf4a51c0e95e35d99a9ba006` was synced through Argo CD
(Synced/Healthy/Succeeded), then applied by gateway Job
`iot-dns-gateway-20261011-1614` on 2026-10-11 at approximately 16:14 CDT.
Live nftables has separate TCP/UDP 53 accepts to `.102` before the IoT-to-LAN
drop; `fw4 check` passed, and mesh VLANs 10/20 remain tagged. LAN workstation
DNS returned NOERROR over UDP/TCP (2/48 ms); Vault remained initialized,
unsealed, active, and ready with zero pod restarts. These probes used Ethernet
`en9`, not IoT Wi-Fi.

At 16:15 CDT, after the owner unplugged Ethernet, the laptop retained
`10.1.1.105`; routes to both `.102` and `.103` used Wi-Fi `en0` via
`10.1.1.1`. Explicit Pi-hole queries for `apple.com` returned NOERROR with
an A answer over UDP (80 ms) and TCP (57 ms). Vault `.103:8200` timed out
after 3 seconds, as intended. Live DNS allow counters increased from zero
to TCP 1 / UDP 3 packets; the aggregate DROP counter increased, but does
not specifically attribute drops to the Vault probe. The DNS-only IPv4
exception passed this client acceptance test; comprehensive isolation,
IPv6, guest access, and long-term stability remain unverified. Guest policy
and DHCP DNS advertisements are unchanged.

Following that successful test, desired IoT DHCP option 6 was changed to
`6,192.168.4.102`, removing the advertised `1.1.1.1` fallback. This change is
applied at approximately 16:25 CDT through revision
`75d04b012c0095e96c458cf896e85019e65a5fb5` and gateway Job
`iot-dhcp-gateway-20261011-1625` (no failures; Argo CD Synced/Healthy/Succeeded).
Live UCI and generated dnsmasq configuration advertise only `.102` for IoT;
guest retains `.102,1.1.1.1`. After the owner unplugged Ethernet and renewed
Wi-Fi DHCP, client `10.1.1.105` received only `.102`, with gateway/server
`10.1.1.1` and routes to Pi-hole/Vault through `en0`. Explicit UDP/TCP
`example.com` queries returned NOERROR (16 ms each); Vault timed out as intended.

The Mac had a manual Wi-Fi DNS override of `1.1.1.1`, despite correct DHCP.
With owner approval, `networksetup -setdnsservers Wi-Fi Empty` cleared it;
`scutil --dns` then showed `.102` as the effective resolver. An ordinary macOS
lookup of `www.icann.org` returned addresses. A bounded two-packet metadata
capture on gateway `br-lan.10` observed a UDP DNS request from this client to
Pi-hole and its reply during the lookup; DNS allow counters also increased.
The capture ended automatically, and no raw packet file was saved. This
validates the renewed client's DHCP and ordinary resolver path, not all devices
or long-term stability. Local override rollback is to restore Wi-Fi DNS
`1.1.1.1` if explicitly desired. Other clients may retain the old
DNS list until renewal (IoT leases are 12 hours); cached answers alone do not
prove use of Pi-hole. Removing an advertised fallback is not enforcement
against manually configured public DNS or encrypted DNS. If Pi-hole is
unavailable, DHCP-managed IoT clients will have no advertised alternate resolver.
Rollback is to restore the prior IoT option 6 through GitOps and renew clients.

16:54 CDT recheck: client remained `10.1.1.105`, with both Pi-hole and Vault
routes through `en0` via `10.1.1.1`. DHCP and the effective system resolver
still list only `.102`; no manual Wi-Fi DNS override is set. Ordinary lookups
succeeded; a targeted two-packet capture confirmed the `www.rfc-editor.org`
AAAA request and matching reply between the client and Pi-hole over IPv4.
Explicit `apple.com` UDP/TCP queries returned NOERROR with an A answer
(14/20 ms). Vault `.103:8200` again timed out after approximately 3 seconds.
Both bounded captures ended; no configuration was changed for this recheck.
These results do not establish IPv6 isolation or long-term stability.

### 2026-10-11 16:57-16:59 CDT: IPv6 and Gateway Access Audit

Read-only inspection covered gateway and all four APs; no router configuration,
service, or reconcile schedule was changed.

- **Gateway administration is reachable from IoT.** Routes to `10.1.1.1`
  used Wi-Fi `en0` even while Ethernet was connected. TCP 22 and 443
  connections succeeded; HTTP returned 403 (application-level response).
  TCP 22 also succeeded at gateway link-local
  `fe80::b45a:2dff:fef8:a2b0%en0`. IoT/guest input policies accept traffic
  except the IPv4 LAN-subnet destination drop. Administration is not
  isolated by the tested policy.
- **Gateway-owned IoT IPv6 is absent.** WAN6 currently delegates only
  `2600:1700:2930:4baf::/64`, assigned to LAN. IoT has no assigned prefix,
  and no RA/DHCPv6 server settings. Client Wi-Fi nevertheless has ULA
  `fd49:3d20:650f:4a6d::/64`, not a gateway-assigned prefix. A single
  delegated `/64` cannot supply distinct conventional SLAAC `/64`s to
  LAN and IoT; upstream larger-prefix availability remains unknown.
- **AP IPv6 ownership needs deliberate cleanup.** AP, Hades, Gemini, and
  Orchid have independent LAN ULA allocations plus configured RA/DHCPv6
  servers despite IPv4 `ignore=1`. Gemini logs report no default route and
  RA lifetime zero. Client LAN routes include AP ULA prefixes, but this
  audit did not capture each AP's LAN advertisements.
- **Existing border-router advertisements must be preserved until understood.**
  A passive IoT capture observed Kitchen HomePod MAC `a4:cf:99:ab:5e:91`
  and unidentified router MAC `1c:b3:c9:03:1c:9a` advertising on-link
  `fd49:3d20:650f:4a6d::/64` and route `fd6f:ffb:7de6:4::/64`
  (under Hades' ULA). Both RAs had default-router lifetime zero. This is
  consistent with border-router/Thread paths, not proof of Internet IPv6
  access or completed Matter validation. The capture was stopped by
  signaling its exact process; no raw packet file was saved.
- **IPv4-only drops do not by themselves prove an IPv6 bypass.** Inspection
  of nftables shows IoT forwarding accepts WAN and same-zone destinations;
  LAN-bound IPv6 falls through to default rejection. Required negative
  client IPv6 tests remain pending. Gateway input exposure is separately
  confirmed above.
- **Maintenance schedules remain active.** All five CronJobs are enabled.
  Gemini's :51 Job completed with DHCP restarts and Wi-Fi reload; AP
  conservative settings skip network/firewall runtime apply, not those
  restarts. No active Jobs were present at the initial audit check; Orchid
  subsequently completed its :58 scheduled Job.

Recommended next batch: establish controlled maintenance, then restrict IoT
gateway administration with trusted-LAN recovery, DHCP, and necessary ICMPv6
preserved. Separately design gateway/AP IPv6 ownership and prefix delegation
around observed border-router paths before any RA changes, 5 GHz expansion,
or discovery deployment. Gateway input restrictions require owner-approved
apply and positive/negative IPv4/IPv6 tests.

Owner approved a port-specific restriction rather than default-deny gateway
input. Desired firewall now has input-only `Reject IoT gateway administration`:
source `iot_zone`, TCP destination ports 22/80/443, IPv4 and IPv6, target REJECT.
No destination zone/address is specified: it covers gateway-local addresses,
not forwarded services. Other gateway input, DHCP, ICMPv6, Pi-hole forwarding,
LAN management, AP/guest policy, and IPv6 ownership remain unchanged.
Existing established connections may survive; acceptance tests must open
new connections. This is not a complete gateway service allowlist.

Desired gateway CronJob is now `suspend: true` for controlled maintenance;
other AP schedules are unchanged. Neither edit is applied live yet. Publish,
sync Argo CD, verify gateway suspension/no active gateway Jobs, and create
one manual gateway reconcile while retaining Ethernet LAN management.
Verify LAN SSH/HTTPS remains reachable and new IoT TCP 22/80/443 connections
fail over IPv4 and IPv6 link-local. Renew DHCP and recheck effective Pi-hole
DNS, explicit UDP/TCP queries, Vault blocking, and IPv6 neighbor discovery.
Restore `suspend: false` through GitOps only after recording successful tests.
If validation fails, remove only the new firewall rule through GitOps and
run a manual reconcile while suspended; restore scheduling separately.

Applied revision `4e51d9b25d539bd42cc6b5f6e55267f613fc1fd3` through
Argo CD and manual gateway Job `iot-admin-gateway-20261011-1703` at
approximately 17:03 CDT. Job completed without failures; `fw4 check` passed.
Argo CD reports Synced/Succeeded and health Suspended due to the intentionally
suspended CronJob. Live input rule rejects TCP 22/80/443 without an IP-family
restriction. Wired LAN SSH/HTTPS succeeded. New IoT IPv4 connections to all
three ports were refused; IPv6 link-local connections timed out. IPv6 ping
succeeded and the gateway neighbor table showed the client REACHABLE;
the combined administration-rule counter increased to 16 packets.

After owner unplugged Ethernet and renewed Wi-Fi DHCP at approximately
17:05 CDT, client `.105` retained only Pi-hole DNS and routed Pi-hole/Vault
via `en0`. Ordinary system lookup succeeded (no fresh-query capture in this
batch). Explicit DNS returned NOERROR and A answers over UDP/TCP (12/38 ms);
UDP had TTL zero and EDNS stale-answer code 3, whereas TCP returned a fresh
198-second TTL. Thus transport passed, but one UDP answer was stale.
UDP recheck at 17:05:22 returned fresh NOERROR answers (TTL 173, 17 ms).
Vault remained blocked with a 3-second timeout. IPv6 ping again passed
without packet loss. LAN Vault health was initialized/unsealed/active before
unplugging Ethernet. Full IPv6 isolation and Matter/Thread remain untested.

After these scoped acceptance checks, desired gateway `suspend: false` is
prepared for publication; live scheduling remains suspended until synced.
Do not run another manual router reconcile solely to restore the schedule.

### 2026-10-11 17:09 CDT: IPv6 Ownership Follow-Up

Schedule restoration revision `19f928030486cde7c50890626c71c28bcd2b640d`
is Synced/Healthy/Succeeded; gateway reconciliation is enabled again.
The following investigation made no router changes:

- Owner identified the upstream device as **AT&T BGW320**. Gateway WAN6
  has no explicit `reqprefix` setting. The installed netifd script maps
  the default `auto` to `-P0`; the running odhcp6c command confirms that
  automatic request. The actual delegated prefix remains one `/64`,
  assigned to LAN. A route covering a larger upstream prefix is not a
  delegation to OpenWRT. Larger-prefix support on this BGW320 remains
  unverified; no DHCPv6 renewal or request experiment was performed.
- Owner identified IoT lease `basement`, MAC `1c:b3:c9:03:1c:9a`,
  address `10.1.1.233`, as an **Apple TV**. Its model and hub role remain
  unconfirmed. Earlier passive capture identified it and Kitchen HomePod
  as advertisers of the same IoT on-link ULA and Hades-derived route.
- Hades' live DHCPv6 lease file contains a `Living-Room` address lease
  and a delegated `fd6f:ffb:7de6:4::/62` with the same DUID. Its live
  route points that delegation to a LAN link-local next hop. This is
  evidence that Hades' DHCPv6 server is actively used, not just configured.
  The precise physical client/DUID relationship to the inventoried Living
  Room Apple TV still needs confirmation.
- The tested Mac's Ethernet interface has SLAAC addresses from gateway
  and all four AP ULA prefixes, plus an AP-derived dynamic DHCPv6 address.
  Its Wi-Fi routes include Hades-derived subprefixes through Kitchen
  HomePod. Removing AP IPv6 allocation/RA/DHCPv6 immediately could therefore
  invalidate existing addresses and border-router routes.

Recommended design direction: retain LAN Internet IPv6 and existing
border-router paths while planning a distinct gateway-owned IoT ULA `/64`.
IoT Internet access can remain IPv4 until additional global delegation is
proven. Do not bridge LAN and IoT, reuse the LAN global `/64`, introduce
NAT66, or assume a larger prefix will be granted. Before implementation,
approve IPv6 DNS/RA policy and test equivalent new-flow isolation; then
migrate prefix ownership and AP services in separate controlled batches.
AP cleanup must account for active delegated-prefix clients and route
lifetimes rather than merely deleting `ip6assign` or disabling odhcpd.

### Prepared Batch: Gateway Local-Only IoT IPv6

Owner accepts IoT interruptions and approved local-only IPv6 before routed
IPv6 design. Desired gateway IoT adds `ip6assign=64`, hexadecimal
`ip6hint=10`, and `ip6class=local`, expecting `fd47:eab4:aa15:10::/64`.
The hint avoids LAN's existing local `/60`; WAN prefixes are excluded.
Actual allocation must be verified after apply, not assumed from the hint.
IoT RA uses SLAAC, flags `none`, router lifetime zero, and no DNS
advertisement (`ra_dns=0`, `dns_service=0`); DHCPv6 is explicitly disabled.
IPv4 DHCP, Pi-hole, LAN Internet IPv6, firewall restrictions, guest policy,
AP allocations, and existing Apple border-router advertisements are unchanged.
No NAT66, bridging, or BGW320 prefix-request changes are included.

Desired gateway CronJob is suspended again for controlled maintenance;
these edits are not yet applied. Publish and sync, verify suspension/no
active gateway Jobs, then run one manual gateway reconcile with Ethernet
recovery available. Inspect live allocation and capture gateway-originated
RA: expected `/64`, SLAAC on-link prefix, zero default lifetime, no RDNSS.
Reconnect the IoT client and inspect IPv6 addresses/routes and Pi-hole DNS;
validate IPv4 Internet, UDP/TCP DNS, and continued gateway-admin/Vault
blocking. Existing border-router RAs can still add their own addresses/routes.
Local-only IPv6 does not yet establish cross-VLAN IPv6 application access or
full isolation; those need a separately designed routed prefix/service policy.

After acceptance, restore gateway scheduling separately. Roll back only the
new IoT IPv6 options through GitOps and reconnect clients; verify RA prefix
withdrawal and client address lifetimes. AP RA/DHCPv6 ownership migration
remains a later controlled batch, even though temporary IoT disruption is
acceptable, because AP prefixes also affect LAN clients.

### 2026-10-11 17:19-17:25 CDT: Local IoT IPv6 Acceptance

Published revision `887a16d25aba525fea063499a80a9c51071731d5` was not
initially reflected in Argo CD; a hard refresh/sync applied the gateway
CronJob suspension before manual Job `iot-ula-gateway-20261011-1719`.
The Job completed successfully; Argo CD is Synced/Succeeded and intentionally
Suspended. `fw4 check` passed.

- Live IoT allocation is exactly `fd47:eab4:aa15:10::/64`, gateway `::1`.
  One gateway-originated RA was captured: on-link/SLAAC prefix, flags none,
  router lifetime zero, no RDNSS; valid/preferred prefix lifetimes 5400/2700
  seconds. The RA also includes a route to `fd47:eab4:aa15::/48`.
  That route supplies ULA reachability information, not an Internet default
  or authorization through the firewall. Capture ended after one packet.
- After owner unplugged Ethernet/reconnected Wi-Fi, client `10.1.1.105`
  had a SLAAC address in the new prefix and a ULA `/48` route via gateway
  link-local on `en0`, without an `en0` IPv6 default. Existing Apple-derived
  Hades subprefix routes remained; its prior `fd49` address was deprecated.
- ULA gateway ping passed with zero packet loss. New TCP 22/80/443
  connections to the IoT ULA gateway were refused; a probe to LAN gateway
  ULA `fd47:eab4:aa15::1:22` was also refused. These are gateway-input
  checks, not evidence of full IPv6 forwarding isolation.
- DHCP/effective resolver remained Pi-hole-only. Explicit `apple.com`
  UDP/TCP DNS returned NOERROR and an A answer (22/34 ms).
  IPv4 HTTPS to `www.iana.org` returned 200. Vault `.103:8200` timed out
  after 3 seconds; Pi-hole/Vault IPv4 routes used `en0`.
- After Ethernet recovery, LAN retained gateway ULA `/60` and global `/64`,
  SSH management worked, and IPv6 HTTPS returned 200. Live administration
  rejection and DNS allow counters increased. AP configuration was not
  changed, and Matter/Thread functional tests remain pending.

Desired gateway schedule restoration (`suspend: false`) is prepared;
publish/sync it separately. Live gateway scheduling remains suspended.
Next implementation remains AP IPv6 ownership cleanup with attention to
active delegated-prefix clients and LAN recovery; it has not been prepared.

### Prepared Batch: Gemini IPv6 Ownership Pilot

Gemini is the first AP pilot; Hades' confirmed Apple-related delegation is
left untouched. Live Gemini inspection found address leases (including the
test Mac) and routes for delegated `fd10:1d51:bae0` subprefixes. This is an
active-service migration, not merely removing unused settings.

Desired Gemini removes LAN `ip6assign=60` and disables LAN RA/DHCPv6.
IPv4 DHCP ignore, management `.4`, IPv4 routing/DNS, VLANs, Wi-Fi, and
gateway/other AP configurations remain unchanged. Global ULA seed is retained
for rollback. Gemini's CronJob is staged suspended; nothing is applied yet.

After publication/sync, verify suspension/no active Gemini Jobs. Run a
manual reconcile with `openwrt_apply_remote_network_runtime=true`, since
normal AP safety defaults skip `ifup lan`. Keep firewall runtime override
disabled and preserve wired management. Verify actual ULA/prefix-route removal,
disabled RA/DHCPv6, management reachability, and lack of new Gemini-originated
advertisements using bounded observation plus runtime/config evidence.
Renew/reconnect a LAN client, accounting for lingering RA/DHCPv6 addresses,
and test LAN IPv6 Internet, DNS, and IoT ULA/DNS/isolation. Old delegated
routes must be inspected explicitly; short capture silence or a successful
IPv4 ping alone cannot certify IPv6 cleanup. Hades/border-router migration
and all-AP ownership certification remain pending.

Rollback is to restore Gemini's prior prefix/server options through GitOps
and apply with the same network runtime override, then renew clients.
Restore Gemini scheduling in a separate publication after validation.

### 2026-10-11 17:29-17:33 CDT: Gemini Pilot Acceptance

Revision `d1f5c31cf3519e2457cc3603225ee521bbda34a2` synced through
Argo CD; Gemini schedule suspension was verified before manual Job
`gemini-ipv6-pilot-20261011-1730`. The generated Job added Ansible extra-var
`openwrt_apply_remote_network_runtime=true`; logs confirmed the network
refresh executed and firewall runtime refresh remained skipped. Job completed
without failures. Argo CD is Synced/Succeeded, intentionally Suspended.

- Gemini management `.4` remained reachable via SSH. LAN has only a
  link-local IPv6 address and no prefix assignment. Live DHCPv6/RA are
  disabled, the lease file is empty, and delegated-prefix routes are gone.
  An unreachable route for the stored global ULA `/48` remains; it is not
  an active allocation or advertisement.
- The first gateway LAN RA capture was interrupted when the scheduled
  17:30 gateway reconcile recreated the interface. A replacement bounded
  observation captured no Gemini-originated RAs and was explicitly stopped.
  Capture silence is supporting evidence only; runtime/configuration
  checks above establish service/allocation removal.
- Initially, macOS retained Gemini SLAAC/DHCPv6 addresses and `/48` route
  even after Ethernet reconnection/renewal. After the subsequent Ethernet
  reconnection at approximately 17:33, no `fd10:1d51:bae0` addresses or
  routes remained on the test Mac. This validates this client, not every
  former DHCPv6 or delegated-prefix client.
- LAN IPv6 HTTPS returned 200 before and after reconnection; LAN Pi-hole
  DNS returned NOERROR. IoT-only client `.105` retained gateway-issued
  IPv4 DHCP, Pi-hole-only DNS, and its gateway ULA SLAAC address.
  ULA ping passed, UDP/TCP DNS returned NOERROR (8/31 ms), IPv4 HTTPS
  returned 200, and tested IPv4 SSH/IPv6 HTTPS gateway ports were refused.
  Vault timed out after 3 seconds; routes used Wi-Fi `en0`.

Gemini schedule restoration (`suspend: false`) is prepared but not synced;
live Gemini remains suspended. Restore it through publication/Argo CD sync
only, without another manual reconcile. Other AP cleanup remains separate;
Hades' Apple-related delegation and comprehensive IPv6 isolation are unresolved.

### Prepared Batch: Orchid IPv6 Ownership Cleanup

Gemini schedule restoration revision
`95a1a3ed6c1ba1bfaf76ba37f2c69edf4da89e45` is Synced/Healthy/Succeeded.
Orchid is the next AP; intermediate AP and Hades remain unchanged.
Read-only inspection found an empty Orchid DHCPv6 lease file but live
`fd9c:94b:faa4` delegated-prefix routes. Ethernet reaches management `.5`.

Desired Orchid removes LAN `ip6assign=60` and disables LAN RA/DHCPv6.
Global ULA seed, IPv4 DHCP ignore, management, mesh/bridge, Wi-Fi, and
WAN6 configuration remain unchanged. Orchid CronJob is staged suspended;
publication/application and acceptance tests are pending.

After publication/sync, verify Orchid suspension/no active Jobs, then run
one manual reconcile with `openwrt_apply_remote_network_runtime=true`.
Keep firewall runtime override disabled and retain Ethernet recovery.
Verify no ULA assignment or active delegated-prefix routes, disabled
RA/DHCPv6, and management reachability. Inspect client stale-prefix lifetimes,
and validate LAN IPv6 Internet/DNS and IoT ULA/DNS/admin/Vault isolation.
An unreachable global ULA aggregate may remain without allocating a prefix.
Short RA capture silence alone is insufficient; correlate runtime/config
evidence. Other former clients and Matter/Thread need separate validation.

Rollback restores only Orchid's prior prefix/server options through GitOps
with the same network runtime override and renewed clients. Restore Orchid
scheduling separately after acceptance; no extra manual reconcile for that.

### 2026-10-11 17:38-17:41 CDT: Orchid Cleanup Acceptance

Revision `08fc220cc4a0118e5450b6493e63e210992800cd` synced; Orchid
suspension and no active Orchid Job were verified before manual Job
`orchid-ipv6-cleanup-20261011-1738`, with the network runtime override.
First attempt lost SSH after `ifup lan`, before DHCP service refresh.
The Job's automatic retry completed with `unreachable=0`, `failed=0`;
both attempt logs were inspected. This was not an interruption-free apply.

Live Orchid RA/DHCPv6 are disabled, LAN retains IPv4/link-local management
only, prefix assignment is empty, leases are empty, and delegated routes
are removed. The stored ULA's unreachable aggregate remains. Orchid logged
a failed stale-prefix RA send during interface refresh; successful prefix
withdrawal was not assumed from that log. No RA capture was performed for
this batch; removal is supported by runtime/config and renewed-client state.

After owner reconnected Ethernet, the test Mac no longer had Orchid
`fd9c:94b:faa4` addresses or routes. LAN IPv6 HTTPS returned 200 and Orchid
SSH worked. Former clients beyond this Mac remain unverified.
IoT-only `.105` retained Pi-hole-only DHCP DNS and gateway ULA; IPv6 ping
passed, explicit UDP/TCP DNS returned NOERROR (10/26 ms), and IPv4 HTTPS
returned 200. Tested IPv4 SSH/IPv6 HTTPS gateway connections were refused;
Vault timed out after 3 seconds. Pi-hole/Vault routes used `en0`.

Argo CD is Synced/Succeeded and intentionally Suspended. Desired Orchid
schedule restoration (`suspend: false`) is prepared for publication;
live Orchid remains suspended. Restore via Argo CD sync only. Intermediate
AP and Hades cleanup, full IPv6 isolation, and Apple/Thread validation remain
separate pending work.

### Prepared Batch: Intermediate AP IPv6 Ownership Cleanup

Orchid schedule restoration revision
`5c3b5cbc4ab53d39c5983eb3dd19e16b7b0ddc54` is Synced/Healthy/Succeeded.
The next cleanup targets intermediate AP `.2`; Hades remains unchanged.
Live AP leases include node2/node3 and the Mac, with node3 delegated
`fd08:2419:f30:4::/62`; owner explicitly approved this scope with
infrastructure checks. IPv4 and gateway IPv6 must remain functional.

Desired AP removes LAN `ip6assign=60`, disables RA/DHCPv6, and suspends
its CronJob for controlled application. IPv4 DHCP ignore, management/gateway,
DNS forwarding, bridge/mesh, Wi-Fi, and global ULA seed remain unchanged.
Publication/application and acceptance tests are pending.

Before applying, record K3S node health and addresses, DNS/Vault health and
LAN IPv6 Internet, checking for AP-ULA dependencies. After sync, confirm AP
suspension/no active AP Jobs and use one manual reconcile with network
runtime override enabled, firewall override disabled. Preserve wired gateway
recovery: the intermediate bridge refresh can interrupt downstream traffic.
Verify AP/downstream management, removed allocation/leases/delegated routes,
disabled services, infrastructure health, and LAN/IoT client tests.
Inspect lingering node/client IPv6 state rather than assuming immediate
withdrawal. Rollback restores only AP prefix/server settings through GitOps
with the same network override and renewed clients. Restore scheduling in
a separate publication after acceptance; Hades migration remains separate.

### 2026-10-11 17:46-17:48 CDT: Intermediate AP Acceptance

Revision `3c4c7e63c396383b3414b2618e6889aaeab03b9f` synced and AP
suspension was verified before manual Job `ap-ipv6-cleanup-20261011-1746`
with network runtime override. It completed with no failures/unreachable
hosts. Live RA/DHCPv6 are disabled; AP LAN has only link-local IPv6,
no ULA assignment, empty DHCPv6 leases, and no delegated-prefix routes.
The unreachable stored ULA aggregate remains. AP SSH and downstream
Gemini/Orchid SSH management worked.

All five K3S nodes remained Ready before, immediately after, and following
client tests. Vault remained initialized/unsealed/active with zero pod
restarts. LAN IPv6 HTTPS returned 200 and Pi-hole DNS returned NOERROR.
After Ethernet reconnection, the Mac had no AP-derived `fd08:2419:f30`
addresses/routes. Node2/node3 retained cluster readiness, but their host-level
stale IPv6 address/delegation lifetimes were not inspected; do not equate
readiness with verification of every IPv6 dependency. No RA capture or
all-client IPv6 certification was performed.

IoT-only `.105` retained Pi-hole-only DHCP DNS and gateway ULA connectivity:
ping passed, UDP/TCP DNS returned NOERROR (31/16 ms), IPv4 HTTPS returned
200, tested IPv4 gateway SSH and IPv6 gateway HTTPS were refused, and Vault
timed out after 3 seconds. Pi-hole/Vault IPv4 routes used Wi-Fi `en0`.

Argo CD is Synced/Succeeded, intentionally Suspended. Desired AP schedule
restoration (`suspend: false`) is prepared; live AP remains suspended until
publication/sync. No manual reconcile is needed just to resume scheduling.
Hades' Apple-related prefix migration and full IPv6 isolation remain pending.

### Prepared Batch: Hades IPv6 Ownership Cleanup

Intermediate AP schedule restoration revision
`bc8ad41db80820288ca18d86d7450c55bcdb8894` is Synced/Healthy/Succeeded.
Hades is the final AP cleanup. At 17:51 CDT its DHCPv6 lease file was empty,
but active delegated routes under `fd6f:ffb:7de6::/48` remained. Their
next-hop/subprefix mapping differs from the earlier snapshot: do not assume
the previously observed `Living-Room` delegation still occupies `:4::/62`.
Earlier Apple border-router advertisements used subprefixes from this pool.

Desired Hades removes LAN `ip6assign=60`, explicitly disables LAN RA/DHCPv6,
and suspends its CronJob. Management `.3`, gateway, IPv4 DHCP ignore, DNS,
VLANs/Wi-Fi, global ULA seed, and gateway/other AP settings remain unchanged.
Owner previously accepted IoT disruption; this batch can also invalidate
remaining Hades-derived LAN addresses and Apple delegated-prefix routes.
Publication/application and functional acceptance are pending.

Before apply, record current LAN/client and Apple border-router routes,
K3S node health, Vault/DNS, and LAN IPv6 Internet. Sync suspension, verify
no active Hades Jobs, then run one manual reconcile with network runtime
override enabled and firewall override disabled, retaining wired recovery.
Verify management and removal of live ULA assignment/leases/delegated routes.
Reconnect LAN/IoT clients and inspect stale Hades addresses/routes explicitly.
Observe Apple RAs after migration: gateway IoT SLAAC does not itself replace
Thread prefix delegation or certify Matter. Do not reset/re-pair accessories
or remove remaining client routes manually as a shortcut.

Validate LAN IPv6 Internet, K3S/Vault/DNS, IoT DHCP/ULA/Internet/isolation,
and owner Home/Siri/Thread behavior where available. Document any remaining
Apple advertisements/deprecated prefixes rather than calling all IPv6
ownership stable. Rollback restores only Hades prefix/server settings via
GitOps with the same network runtime override and client renewal. Restore
scheduling separately after acceptance; no extra manual Job for scheduling.

### 2026-10-11 17:53-17:55 CDT: Hades Cleanup Acceptance

Revision `042be17dc76744f7457d2c64266a7d80055f1801` synced after a
hard refresh; Hades suspension/no active Hades Jobs were verified before
manual Job `hades-ipv6-cleanup-20261011-1753` with network runtime override.
It completed without failed/unreachable hosts. Live Hades has disabled
RA/DHCPv6, empty leases, link-local-only LAN IPv6, and no delegated routes;
the stored ULA unreachable aggregate remains. SSH management worked.

All five K3S nodes remained Ready; Vault was initialized/unsealed/active,
with zero pod restarts. LAN IPv6 HTTPS returned 200 and Pi-hole DNS passed.
After Ethernet reconnection, the test Mac had no Hades-derived LAN address
or LAN aggregate route, though Apple-advertised Hades subprefix routes still
remained on Wi-Fi. Former clients and host-level node IPv6 state remain
unverified.

A bounded two-packet capture observed basement Apple TV and Kitchen HomePod
RAs advertising both `fd47:eab4:aa15:c::/64` and old
`fd6f:ffb:7de6:c::/64`, with 1800-second route lifetimes and zero default
router lifetime. Gateway DHCPv6 now delegates `fd47:eab4:aa15:c::/62`
to the DUID previously associated with Hades' `Living-Room` lease, with
a corresponding LAN next-hop route. This supports a transition to
gateway-derived delegation, not completed Thread/Matter functional recovery.
The old route is still actively advertised in this sample, not merely proven
to be a stale client cache. The capture ended automatically after two packets.

IoT-only `.105` retained Pi-hole DHCP DNS, gateway ULA ping, UDP/TCP
NOERROR DNS (8/16 ms), and IPv4 HTTPS 200. Tested IPv4 gateway SSH and
IPv6 gateway HTTPS were refused; Vault timed out after 3 seconds.
Pi-hole/Vault IPv4 routes used Wi-Fi `en0`. Home/Siri/Thread functional
results were not supplied and remain pending.

Desired Hades schedule restoration (`suspend: false`) is prepared;
live Hades remains suspended until publication/sync. All four AP cleanup
configurations are deployed, but full IPv6 isolation, old Apple-prefix
withdrawal, and all-client stability are not certified. Restore scheduling
without another manual router Job; follow up on Apple route lifetimes and
owner functional tests separately.

| Date / device | Actual network | Test / result | Remaining work / stability status |
|---|---|---|---|
| 2026-10-11 Kitchen Speaker | IoT | DHCP lease + neighbor; ping passed; owner says active home hub | A incomplete; cross-VLAN conflict unresolved |
| 2026-10-11 Hue bridge | LAN | HTTP/API + Hue Bonjour passed; Hue app works per owner; Apple Home fails per owner | H incomplete; integration method unknown |
| 2026-10-11 Living Room Apple TV | LAN | Ping + AirPlay advertisement/model passed | A incomplete; hub failover not tested |
| 2026-10-11 Pi-hole | LAN service | `apple.com` lookup from gateway passed | D incomplete from actual client VLANs |
| 2026-10-11 Pi-hole after address alignment | LAN service `.102` | Synced/Healthy, ready pod/endpoint; workstation UDP/TCP queries for `apple.com` and `example.com` all returned NOERROR | Address alignment validated; IoT/guest D profile and long-term stability remain pending |
| 2026-10-11 remaining inventory | Networks listed above | Lease/config/service evidence only unless noted | All assigned profiles pending; not certified functional |

## Troubleshooting History

### 2026-10-11: Kitchen HomePod and Apple Home/Hue

- Initial symptom: owner reported Kitchen could not connect. No lease named Kitchen
  or Kitchen AirPlay service was found.
- Important limitation: the MAC later identified as HomePod was already associated
  with the IoT SSID during early AP inspection. Absence of its friendly name did not
  prove a Wi-Fi association failure; the original failure stage remains unconfirmed.
- Owner re-added the HomePod as **Kitchen Speaker**. A later lease identified it as
  `HomePod` at `10.1.1.148`; it responded to ping. Re-adding was an owner action,
  not an assistant-applied change.
- Owner confirmed Kitchen Speaker is the active Apple Home hub. Hue works in the Hue
  app but not Apple Home. Hue's bridge was positively identified at `192.168.4.168`.
- Confirmed policy conflict: active hub on IoT cannot initiate IPv4 connections to
  the LAN bridge under the inspected DROP rule; no cross-VLAN mDNS reflector exists.
  A specific failed hub-to-Hue connection was not captured. Pairing/integration issues
  and IPv6/Matter behavior remain possible additional factors.
- Plausible transition: a hub-role change can expose this conflict without changing
  router settings. The previous active hub is unknown.
- Runtime disturbance: gateway logs showed WAN cycling at 07:30 and 08:00 local time;
  at 08:00 LAN/mesh transitions and dnsmasq restart were also recorded. This matches
  the repository's half-hour gateway reconcile and runtime actions, but the live
  initiating job was not identified. Earlier empty cluster results came from a
  non-K3S context and are not evidence about the repository's K3S deployment.
  K3S inspection initially failed authentication, but a 13:39 retry succeeded and
  confirmed enabled reconcile CronJobs, including the half-hour gateway schedule.
  Attribution of each observed runtime disturbance still requires Job log correlation.
- One Hades key-installation error matched the iPhone MAC's association, not a proven
  HomePod failure. Mesh authentication failures were observed on AP but established
  gateway peers were also present; neither observation establishes the incident cause.
- No router settings, firmware, firewall rules, or reconciliation schedules were changed.
- Outcome: HomePod IP connectivity recovered after owner re-add; Apple Home/Hue
  recovery and stable layout remain unverified.

## Read-Only Diagnostic Workflow

1. Record the exact failing function, affected app, network, and current active hub.
   Distinguish vendor/cloud control from Apple Home/local control.
2. Read gateway leases/neighbors and AP clients; confirm MAC identity, not just room name.
3. Inspect relevant UCI settings without printing Wi-Fi keys, SSH keys, or credentials.
4. Observe `_airplay._tcp`, `_hap._tcp`, `_hue._tcp`, and `_matter._tcp` as applicable
   from the actual controller network. Resolve service targets before assigning identities.
5. Compare source/destination VLANs with live firewall policy and counters. Aggregate
   DROP counters cannot attribute a failure to one device.
6. Use bounded, non-promiscuous packet observation only as needed; stop captures/browsers
   after diagnosis. Do not commit raw packets, raw exports, or personal payloads.
7. Correlate timestamp/timezone with reconcile, WAN, DHCP, wireless, and hub-role events.
8. Record evidence, confidence, and unresolved gaps before proposing a change.

Do not reset/re-pair a working bridge, reload Wi-Fi, restart services, or apply a
firewall change during read-only troubleshooting.

## Next Decisions and Inventory Gaps

- [ ] Confirm owner/model/firmware for every provisional row and merge verified duplicates.
- [ ] Enumerate every Hue light/sensor/switch and its room/bridge membership.
- [ ] Identify all HomePods/Apple TVs and eligible hub roles; identify Main Bedroom.
- [ ] Confirm native HomeKit versus Matter for Hue and resolve the two Matter service targets.
- [ ] Map Homebridge services to hosts and their accessory integrations.
- [ ] Map unnamed LAN and IoT devices; confirm Sonos, Flo, SV3, basement, and MyQ roles.
- [ ] Complete wired switch port/cable map and offline/static/non-IP device inventory.
- [ ] Review trust tradeoffs and approve staged implementation of the selected all-automation-on-IoT layout before changing placement.
- [ ] Test DNS from actual IoT/guest clients and audit IPv6/RA behavior.
- [x] Verify K3S authentication, live Pi-hole address (`192.168.4.102`), and enabled reconcile schedules.
- [x] Align Pi-hole desired/live requested address, kube-vip annotation, and advertised address to `.102`; verify workstation TCP/UDP DNS after sync.
- [ ] Correlate gateway disturbances with reconcile Job logs before changing automation.
- [ ] Execute each device's acceptance profile in an approved test session.
- [ ] Promote a layout to validated stable only after all required tests and observation pass.
