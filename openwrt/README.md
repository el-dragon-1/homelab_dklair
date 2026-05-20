# OpenWRT Desired State

This directory holds sanitized OpenWRT configuration snapshots and the desired state used by the GitOps workflow.

## Layout

- `baseline/`: sanitized snapshot of current router configuration
- `desired/`: sanitized configuration that GitOps should enforce

## Device Folders

- `gateway/`: Bananapi R3 gateway
- `ap/`: Bananapi R3 access point with mesh backhaul

## File Convention

Keep one UCI file per configuration area:

- `system.uci`
- `network.uci`
- `dhcp.uci`
- `firewall.uci`
- `wireless.uci`

Do not commit raw exports or secrets.

## Vault Mapping

Keep all secrets for each device in a single root path so the current ExternalSecrets can pull them together:

- `homelab/openwrt/gateway`
- `homelab/openwrt/ap`

For each device path, store:

- `host`
- `port`
- `username`
- `ssh_private_key`
- `mesh_key`
- `ssid keys`
