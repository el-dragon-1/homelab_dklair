# LAN/VPN Upload Pattern for Ingress-Backed Services

Use this pattern when you want large browser uploads to work from your home LAN or over WireGuard without exposing a separate public upload hostname.

## Prerequisites

1. The service already publishes a normal public hostname through Traefik.
2. Your WireGuard clients can use an internal DNS resolver, such as Pi-hole or your router DNS.
3. You know the private IP of the Traefik load balancer on your LAN. In this repo, that is typically `192.168.4.100`.

## Recommended Pattern

Keep one hostname for the service, for example `audiobookshelf.dklair.io`, and make it resolve differently depending on where the client is:

1. Public internet clients continue to resolve the hostname through Cloudflare.
2. LAN and VPN clients resolve the same hostname directly to the internal Traefik IP.
3. Large uploads then bypass Cloudflare automatically when the client is on LAN or VPN.

This avoids creating a second public upload hostname.

## Step 1: Add Internal DNS

Create a local DNS override on your internal resolver:

1. Record name: `audiobookshelf.dklair.io`
2. Record target: `192.168.4.100`
3. Scope: your LAN DNS and the DNS server handed out to WireGuard clients

If you prefer a different service hostname, use the same pattern for that host instead.

## Step 2: Push Internal DNS to WireGuard Clients

Make sure VPN clients use the same internal resolver you use on LAN:

1. Set the WireGuard peer DNS server to your internal resolver.
2. Route the LAN subnet through the tunnel, or at least the Traefik IP and any supporting internal services.
3. Confirm the VPN client can reach `192.168.4.100`.

For this homelab, a route for `192.168.4.0/24` is usually the simplest choice.

## Step 3: Verify Split DNS

From a LAN or VPN client:

1. Run `dig audiobookshelf.dklair.io` or `nslookup audiobookshelf.dklair.io`.
2. Confirm the answer is the internal Traefik IP, not Cloudflare.
3. Open `https://audiobookshelf.dklair.io`.
4. Confirm the browser reaches the service without Cloudflare headers.

## Step 4: Test a Large Upload

1. Connect to LAN or WireGuard.
2. Open the normal service URL.
3. Upload a file larger than the Cloudflare body limit that previously failed.
4. Confirm the upload completes and the library scan sees the file.

## Optional Hardening

If you want the service reachable only from LAN or VPN, add a Traefik IP allowlist or enforce the restriction at the firewall.

Recommended baseline:

1. Allow LAN subnet `192.168.4.0/24`.
2. Allow the WireGuard tunnel subnet you assign to clients.
3. Deny direct WAN access to the origin where practical.

This is stronger than relying on split DNS alone.

## Rollback

1. Remove the internal DNS override.
2. Revert any WireGuard DNS or route changes.
3. Remove any optional allowlist middleware or firewall rule if you added one.

## Notes

1. This pattern works for Audiobookshelf and any other ingress-backed service that needs large browser uploads.
2. For Audiobookshelf specifically, the repo anchor is [../../values/audiobookshelf/values.yaml](../../values/audiobookshelf/values.yaml).