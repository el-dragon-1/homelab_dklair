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
