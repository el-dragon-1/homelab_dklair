# Pi-hole Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Pi-hole. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/pihole-application.yaml](../../apps/argocd/pihole-application.yaml)
- Status: Managed through Argo CD with the sibling values file.

## Current Deployment Shape
- Namespace: `pihole`.
- LAN DNS is exposed at the kube-vip LoadBalancer address `192.168.4.102` on TCP and UDP port 53.
- Pi-hole v6 forwards to the OpenWRT router resolver at `192.168.4.1` through `FTLCONF_dns_upstreams`.
- Configuration and one replica are managed by the Helm chart through the `pihole` Argo CD application.

## Known Good State
- 2026-08-28: `dig @192.168.4.102 google.com A` returned `NOERROR` in 2 ms after the active Pi-hole upstream was set to `192.168.4.1`.

## Recurring Problems
- When Pi-hole used direct Cloudflare upstreams (`1.1.1.1`, `1.0.0.1`), pod Internet egress failed while the pod could still reach the OpenWRT router. FTL exhausted its 150 concurrent upstream query slots and LAN clients received DNS timeouts.
- Pi-hole v6 uses `FTLCONF_dns_upstreams` as its active upstream list. An existing explicit `FTLCONF_dns_upstreams` value takes precedence over `DNS1` and `DNS2`.

## Troubleshooting History
- Date: 2026-08-28
- Issue: Devices lost DNS resolution twice within two weeks while a dual-homed Mac still had Internet through a mobile hotspot.
- Root cause: The cluster pod network could reach `192.168.4.1` but not public addresses. Pi-hole's direct Cloudflare upstreams timed out, filling FTL's concurrent-query limit.
- Fix: Set `FTLCONF_dns_upstreams: 192.168.4.1` in `values.yaml`; retain `DNS1` and `DNS2` as matching legacy values.
- Validation: Pi-hole loopback and the LAN VIP both resolved `google.com` after rollout.

## Working Fixes
- Verify the outage with `dig @192.168.4.102 google.com A`.
- Confirm the active resolver with `kubectl -n pihole exec deploy/pihole -- sed -n '/^  upstreams = \[/,/^  \]/p' /etc/pihole/pihole.toml`.
- Query `dig @192.168.4.1 google.com A` from the Pi-hole pod to confirm the router resolver remains reachable.

## Dependencies And Secrets
- Pi-hole requires the OpenWRT resolver at `192.168.4.1` to be reachable from the cluster pod network.
- The pod network currently cannot reach public Internet addresses directly; do not configure Pi-hole's upstreams with public resolvers unless that egress policy is corrected.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.