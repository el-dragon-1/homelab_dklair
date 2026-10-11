# Vault Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Vault. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/vault-application.yaml](../../apps/argocd/vault-application.yaml)
- Status: Managed through Argo CD with the sibling values file.

## Current Deployment Shape
- K3S namespace `vault`, chart 0.32.0, one standalone Raft-backed pod with a 10Gi Longhorn volume. TLS is disabled in the current listener; this migration does not change transport or storage.
- Internal consumers use `http://vault.vault.svc.cluster.local:8200`. The `vault-ui` LoadBalancer now uses dedicated `192.168.4.103:8200`; Pi-hole remains `192.168.4.102:53`.

## Known Good State
- 2026-10-11 before migration: `vault-0` and StatefulSet were 1/1 ready, pod had zero restarts, and the public health endpoint reported initialized/unsealed. `vault-backend` ClusterSecretStore was Ready and all 26 ExternalSecrets had no non-Ready condition.
- 2026-10-11 approximately 15:06: Vault revision `743aaa33cc1c92397f6a4b6d8a852a384dd51119` was Synced/Healthy; requested, annotated, and advertised UI VIP all matched `.103`. Three consecutive health requests succeeded (initialized, unsealed, active); Vault pod was unchanged with zero restarts. `.102:8200` no longer accepted connections. Pi-hole UDP/TCP queries returned NOERROR (5/16 ms). A forced `aliasvault-db` ExternalSecret refresh succeeded at `20:06:14Z` without reading secret values.

## Dedicated VIP Migration

Address separation and immediate health checks completed. Owner confirmed successful
Vault login at 15:20 local time on 2026-10-11; longer-term stability remains to be
validated. Argo CD initially applied `.103` request/annotation,
but kube-vip v1.0.0 retained `.102` status and logged cancellation/waiting for the
old load balancer. With owner approval, only the active node2 kube-vip pod was
restarted; `.103` advertisement then converged without restarting Vault.

Post-restart checks: Kubernetes API ready; kube-vip DaemonSet ready; all LoadBalancer
addresses matched intended assignments; Traefik HTTP responded. Alpine `.104` had
no backend endpoints and did not accept HTTP. Mail `.105` had a ready endpoint but
workstation TCP probes to 25/587/993 timed out; no before-restart connectivity baseline
establishes causation. WireGuard had a ready UDP endpoint but no client handshake test.
These checks do not certify all service VIPs as functionally healthy; mail reachability
needs separate investigation. No unrelated service changes were made.

Owner approved `192.168.4.103` and preparation through Git before live sync.
Read-only checks found no Service allocation, gateway lease/reservation/hosts entry,
or ARP response at `.103`. An offline/static device cannot be excluded by these checks.
The address is inside kube-vip's `.100-.110` pool and the gateway DHCP pool, so
DHCP protection must precede the Service migration.

1. Commit/push only the gateway reservation and accompanying documentation first.
   Desired [gateway DHCP](../../openwrt/desired/gateway/dhcp.uci) defines the reserved
   hostname `reserved-vault-vip` at `.103`, without binding the VIP to a node MAC.
   OpenWRT's DHCP renderer supports this hostname-only reservation; dnsmasq syntax
   validation of `--dhcp-host=reserved-vault-vip,192.168.4.103` passed.
2. In a controlled gateway apply window, confirm no active reconcile Job and apply
   the committed desired configuration. The current gateway reconcile refreshes
   interfaces/firewall/DHCP/Wi-Fi; expect possible brief interruptions. Inspect
   generated dnsmasq configuration for the reservation and recheck leases/ARP
   for conflicts. Do not proceed if `.103` is already assigned to a client.
   Completed 2026-10-11 at approximately 14:23: OpenWRT Argo CD sync succeeded at
   `5b883014fd215a8e1096f4919419e6bdbc45bc69`; manual gateway Job
   `vault-vip-reservation-20261011-1423` completed. Live UCI and generated dnsmasq
   configuration contain `dhcp-host=reserved-vault-vip,192.168.4.103`.
   No `.103` lease or ARP responder was found after application. Vault remained
   initialized/unsealed at `.102`, and Pi-hole DNS still resolved `apple.com`.
3. Only after reservation verification, prepare `ui.loadBalancerIP: 192.168.4.103`
   and `ui.annotations.kube-vip.io/loadbalancerIPs: 192.168.4.103` in Vault values.
   Both fields must agree so the existing `.102` annotation does not override intent.
   Render chart 0.32.0; ensure only the UI Service address/annotation changes, not
   StatefulSet, PVC, listener, or internal Services.
   Both `.103` fields were published in `743aaa33cc1c92397f6a4b6d8a852a384dd51119`;
   rendering confirmed only the UI Service annotation/request fields changed.
4. Commit/push the separate Vault change, refresh/sync Argo CD, and verify the
   requested/annotation/advertised IP is `.103`, with the existing Vault pod still
   ready and unsealed. Automatic sync is enabled, so publication itself may apply it.
5. Test `.103:8200/v1/sys/health`, Vault login via the owner's client, internal
   ClusterSecretStore readiness and ExternalSecret refresh, and Pi-hole TCP/UDP
   DNS at `.102`. Check `.102:8200` no longer exposes Vault. Update any external
   bookmarks or direct-IP consumers; no repository consumer of `.102:8200` was found.

Rollback: restore both UI Service address fields to `.102` in Git and sync; preserve
the `.103` DHCP reservation while troubleshooting. Do not delete/recreate the
StatefulSet/PVC or restart/unseal Vault merely to move its Service VIP.
Migration is not complete until live address separation and consumer checks pass.

## Recurring Problems
- Capture repeated failures, init or unseal confusion, storage issues, and auth-policy regressions.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- Keep short, validated repair steps worth reusing.

## Dependencies And Secrets
- External Secrets' `vault-backend` uses the internal Service, not the UI VIP; its endpoint should not change in this migration.
- Owner-held login/unseal credentials must never be printed or committed. The VIP change does not validate an authenticated login by itself.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.