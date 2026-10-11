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
| IoT | `.100` through `.249` / 12 hours | `192.168.4.102`, `1.1.1.1` |
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

**IoT access work is paused pending Vault VIP separation.** Owner approved `.103`
for Vault. First apply/verify its gateway DHCP reservation, then publish and validate
the Vault Service change; Pi-hole remains `.102`. See the
[two-phase migration and rollback plan](values/vault/context.md).
The gateway reservation is now applied and verified (2026-10-11, approximately
14:23). Vault's `.103` requested IP and annotation are prepared locally for a
separate commit/push; its live Service still uses `.102`. Do not mark separation
complete until the published Vault change is synced and validated.

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
