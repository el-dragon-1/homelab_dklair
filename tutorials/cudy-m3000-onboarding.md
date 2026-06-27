# Cudy M3000 v1 — New Device Onboarding Guide

Three new devices are being added to the network:

| Device  | Role              | Connection           | IP (suggested) |
|---------|-------------------|----------------------|----------------|
| Hades   | Wired AP          | Ethernet → Gateway   | 192.168.4.3    |
| Gemini  | Wired AP          | Ethernet → Mesh AP   | 192.168.4.4    |
| Orchid  | Mesh router/switch | 5 GHz mesh backhaul | 192.168.4.5    |

Adjust IPs to match your subnet. These are what you will write into Vault.

---

## Step 1 — First Boot: Configure as Dumb AP

Do this for each Cudy M3000 **before** plugging it into your network.

These devices are **dumb access points** — they bridge only, with no routing.

1. Connect your laptop to the device's default LAN port (or default Wi-Fi `Cudy-XXXX`).
2. Browse to `http://192.168.10.1` (Cudy default) or `http://192.168.1.1`.
3. **Configure LAN static IP** (do NOT save yet):
   - Go to **Network → Interfaces → LAN → Edit**.
   - Change **Protocol** to `Static`, set:
     - **IP address**: e.g. `192.168.4.3` (Hades), `192.168.4.4` (Gemini), `192.168.4.5` (Orchid)
     - **Netmask**: `255.255.255.0`
     - **Leave Gateway and DNS empty** (dumb AP needs no routing)
   - Click **Save** (not Save & Apply — just Save).
4. **Disable WAN interface** (do NOT save yet):
   - Go to **Network → Interfaces → WAN → Edit**.
   - Set **Protocol** to `Disabled`.
   - Click **Save**.
5. **Disable DHCP** (do NOT save yet):
   - Go to **Network → DHCP and DNS**.
   - Set **DHCP Server** to `Disabled` on the **LAN** interface.
   - Verify **Ignore interface** is checked (`✓`) for LAN.
   - Click **Save**.
6. **Apply all changes at once**:
   - Click **Save & Apply** at the top/bottom of the page.
   - Your laptop will lose the connection. That is expected.
7. Plug the device into your network on any LAN port (they all bridge) and verify it responds at its new IP:
   ```sh
   ping 192.168.4.3  # Hades
   ping 192.168.4.4  # Gemini
   ping 192.168.4.5  # Orchid
   ```
8. Confirm DHCP is off by checking the device does not hand out an IP to a connected client:
   - If you connect another device to it via Ethernet or Wi-Fi, it should NOT receive a DHCP lease.
   - If it does, go back to step 5 and verify **DHCP Server** is disabled.

---

## Step 2 — Enable SSH and Install Your Public Key

SSH must be accessible and passwordless login must work before Ansible can manage the device.

### 2a — Generate an SSH key (if you don't have one)

On your laptop (not on the router), run:

```sh
ssh-keygen -t ed25519 -C "your_email@example.com"
```

- Press Enter to accept the default file location (`~/.ssh/id_ed25519`).
- Set a passphrase if you want (recommended), or press Enter for none.

Your public key will be in `~/.ssh/id_ed25519.pub` and private key in `~/.ssh/id_ed25519`.

### 2b — Confirm SSH access with password login

Do this for each Cudy M3000 (Hades: `.3`, Gemini: `.4`, Orchid: `.5`):

```sh
# First login uses password auth
ssh root@192.168.4.3
```

If SSH does not respond:
- Verify the device is reachable: `ping 192.168.4.3`
- Check verbose SSH output: `ssh -v root@192.168.4.3`
- If needed, enable SSH from LuCI: **System → System → Enable SSH**

### 2c — Install your SSH public key from your laptop (recommended)

Run these on your laptop (not on the router). This appends your key remotely and sets permissions:

```sh
cat ~/.ssh/id_ed25519_hades.pub | ssh root@192.168.4.3 "mkdir -p /etc/dropbear && cat >> /etc/dropbear/authorized_keys && chmod 600 /etc/dropbear/authorized_keys"
cat ~/.ssh/id_ed25519_hades.pub | ssh root@192.168.4.4 "mkdir -p /etc/dropbear && cat >> /etc/dropbear/authorized_keys && chmod 600 /etc/dropbear/authorized_keys"
cat ~/.ssh/id_ed25519_hades.pub | ssh root@192.168.4.5 "mkdir -p /etc/dropbear && cat >> /etc/dropbear/authorized_keys && chmod 600 /etc/dropbear/authorized_keys"
```

If you are using your default key instead, replace `id_ed25519_hades.pub` with `id_ed25519.pub`.

### 2d — Disable password authentication (optional but recommended)

```sh
uci set dropbear.@dropbear[0].PasswordAuth='off'
uci set dropbear.@dropbear[0].RootPasswordAuth='off'
uci commit dropbear
/etc/init.d/dropbear restart
```

### 2e — Verify passwordless login works

From your laptop, verify key-based SSH to each device:

```sh
ssh -i ~/.ssh/id_ed25519_hades root@192.168.4.3 'echo Hades SSH working'
ssh -i ~/.ssh/id_ed25519_hades root@192.168.4.4 'echo Gemini SSH working'
ssh -i ~/.ssh/id_ed25519_hades root@192.168.4.5 'echo Orchid SSH working'
```

If any host prompts for a password, rerun step 2c for that host.

---

## Step 3 — Verify Radio Hardware Paths

The manifests assume `platform/soc/18000000.wifi` (2.4 GHz) and
`platform/soc/18000000.wifi+1` (5 GHz) — standard for MediaTek Filogic.

Confirm on each Cudy M3000:
```sh
uci show wireless | grep path
```

Expected output:
```
wireless.radio0.path='platform/soc/18000000.wifi'
wireless.radio1.path='platform/soc/18000000.wifi+1'
```

If the paths differ, update the `option path` values in
`apps/openwrt-ops/configmap-ansible-automation.yaml` for the affected device.

---

## Step 4 — Load Vault Secrets

For each new device, create a Vault secret at `homelab/openwrt/<device>`.

Important for `ssh_private_key`:
- Use the real private key text, or a base64-encoded version of the private key.
- Do not store a SHA-256 hash. A hash is one-way and cannot be used for SSH auth.

If using the Vault web UI, generate base64 from your laptop first and paste that value:

```sh
base64 < ~/.ssh/id_ed25519_hades | tr -d '\n'
base64 < ~/.ssh/id_ed25519_gemini | tr -d '\n'
base64 < ~/.ssh/id_ed25519_orchid | tr -d '\n'
```

### Hades and Gemini (wired APs — no mesh key)

```sh
vault kv put homelab/openwrt/hades \
  host="192.168.4.3" \
  port="22" \
  username="root" \
  ssh_private_key="$(base64 < ~/.ssh/id_ed25519_hades | tr -d '\n')" \
  openwrt_ssid_key="<IoT network password>" \
  smz_homex_ssid_key="<smz_homex password>" \
  smz_guest_ssid_key="<smz_guest password>"

vault kv put homelab/openwrt/gemini \
  host="192.168.4.4" \
  port="22" \
  username="root" \
  ssh_private_key="$(base64 < ~/.ssh/id_ed25519_gemini | tr -d '\n')" \
  openwrt_ssid_key="<IoT network password>" \
  smz_homex_ssid_key="<smz_homex password>" \
  smz_guest_ssid_key="<smz_guest password>"
```

### Orchid (mesh router — only needs mesh key)

```sh
vault kv put homelab/openwrt/orchid \
  host="192.168.4.5" \
  port="22" \
  username="root" \
  ssh_private_key="$(base64 < ~/.ssh/id_ed25519_orchid | tr -d '\n')" \
  mesh_key="<your existing smz5mesh SAE key>"
```

### Update existing Gateway and AP secrets (remove SSID keys)

The Gateway and AP Vault secrets still have `openwrt_ssid_key`, `smz_guest_ssid_key`,
and `smz_homex_ssid_key`. The ExternalSecrets no longer request those keys, so they
become inert. You can optionally clean them up:

```sh
# Remove unused keys (vault kv patch removes individual fields)
vault kv patch homelab/openwrt/gateway -delete-fields=openwrt_ssid_key,smz_guest_ssid_key
vault kv patch homelab/openwrt/ap -delete-fields=smz_homex_ssid_key
```

---

## Step 5 — Push to Git and Sync ArgoCD

```sh
git add apps/openwrt-ops/
git commit -m "feat(openwrt-ops): add Hades, Gemini, Orchid; move client SSIDs; enable 802.11k/v/r"
git push
```

Then sync the ArgoCD application (or let it auto-sync). The ExternalSecrets
will create the Kubernetes secrets, and the CronJobs will start on their
schedules:

| CronJob                    | Schedule   | Notes                        |
|----------------------------|------------|------------------------------|
| openwrt-gateway-reconcile  | `*/30`     | 5 GHz mesh backhaul only     |
| openwrt-ap-reconcile       | `7,37`     | 5 GHz mesh backhaul only     |
| openwrt-hades-reconcile    | `14,44`    | 2.4 GHz IoT + 5 GHz clients |
| openwrt-gemini-reconcile   | `21,51`    | 2.4 GHz IoT + 5 GHz clients |
| openwrt-orchid-reconcile   | `28,58`    | 5 GHz mesh backhaul only     |

To trigger immediately (after secrets are ready):
```sh
kubectl create job --from=cronjob/openwrt-hades-reconcile hades-manual-$(date +%s) -n openwrt-ops
kubectl create job --from=cronjob/openwrt-gemini-reconcile gemini-manual-$(date +%s) -n openwrt-ops
kubectl create job --from=cronjob/openwrt-orchid-reconcile orchid-manual-$(date +%s) -n openwrt-ops
```

---

## Fast Roaming (802.11k/v/r) Notes

- `smz_homex` and `smz_guest` are currently configured as WPA2-only (`psk2+ccmp`)
  on Hades and Gemini to keep older devices associating reliably.
- If you want to re-enable WPA3 or 802.11r/k/v later, do it as a separate rollout
  after confirming client support.
- Both Hades and Gemini stay on different 5 GHz channels to reduce
  co-channel interference.

---

## Wireless Layout After Rollout

| Device  | 2.4 GHz (radio0)          | 5 GHz (radio1)                            |
|---------|---------------------------|-------------------------------------------|
| Gateway | **Disabled**              | `smz5mesh` (802.11s mesh backhaul)        |
| AP      | **Disabled**              | `smz5mesh` (802.11s mesh backhaul)        |
| Hades   | `OpenWrt` IoT (psk2+ccmp) | `smz_homex` + `smz_guest` (WPA2-only)    |
| Gemini  | `OpenWrt` IoT (psk2+ccmp) | `smz_homex` + `smz_guest` (WPA2-only)    |
| Orchid  | **Disabled**              | `smz5mesh` (802.11s mesh backhaul)        |
