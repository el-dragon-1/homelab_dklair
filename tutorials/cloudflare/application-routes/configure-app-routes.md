# Configuring Published Application Routes

When you have an application running in the cluster along with an ingress resource you have to configure the hostname routes in order for web traffic to be routed to the appropriate ingress.

In Cloudflare, first go to Zero Trust in the side. (The location changes from time to time)

![Alt text](/tutorials/cloudflare/application-routes/zero-trust-loc.png)

Click Networks > Connectors. For the tunnel you want to edit select the menu dots and click Configure.

![Alt text](/tutorials/cloudflare/application-routes/network-connectors.png)

## Protecting Alertmanager with Zero Trust Access (MFA)

Use this workflow to protect `alertmanager.dklair.io` behind Cloudflare Access so users must authenticate with MFA before they can reach the UI.

### Prerequisites

1. Alertmanager ingress exists in the cluster and resolves externally at `alertmanager.dklair.io`.
2. A Cloudflare Tunnel is already publishing the hostname route.
3. At least one Identity Provider is configured in Zero Trust (Google, GitHub, Okta, Azure AD, etc.).
4. MFA is enforced at the Identity Provider level for the users/groups that will access Alertmanager.

### Step 1: Verify the Tunnel Public Hostname Route

In Cloudflare Zero Trust:

1. Go to Networks > Tunnels.
2. Select your tunnel and open Public Hostnames.
3. Confirm a hostname route exists for `alertmanager.dklair.io`.
4. Ensure it forwards to the correct origin service (your cluster ingress endpoint).

### Step 2: Create the Access Application

In Cloudflare Zero Trust:

1. Go to Access > Applications.
2. Click Add an application.
3. Choose Self-hosted.
4. Set:
	- Application name: Alertmanager
	- Domain: `alertmanager.dklair.io`
	- Session duration: short (for example 8h or less)
5. Save and continue to policies.

### Step 3: Add Access Policies

Create at least one Allow policy and keep it narrow.

Recommended baseline:

1. Action: Allow
2. Include:
	- Email or Email domain for your admin users
	- Or Group from your configured IdP
3. Require (optional but recommended):
	- Device posture check (if you use WARP)
4. Identity provider:
	- Use an IdP where MFA is already enforced

Important:

1. Do not add broad bypass rules for this app.
2. Do not expose Alertmanager without Access policies.

### Step 4: Test Access Flow

1. Open `https://alertmanager.dklair.io` in a private/incognito browser window.
2. Confirm you are redirected to Cloudflare Access login.
3. Sign in with an allowed identity.
4. Confirm your IdP enforces MFA during sign-in.
5. Confirm Alertmanager UI loads only after successful authentication.

### Step 5: Verify Block Behavior

1. Try an account that is not in the Allow policy.
2. Confirm access is denied.

### Rollback / Break-Glass

If you accidentally lock everyone out:

1. In Zero Trust, edit the Access application policy.
2. Temporarily add your admin email as Include.
3. Re-test access.
4. Remove temporary broad entries once normal access is restored.

### Notes

1. This repository does not currently manage Cloudflare Access policies via GitOps, so the Access application and policy changes are made in Cloudflare UI.
2. Cluster-side ingress for Alertmanager is managed in [values/prometheus-stack/values.yaml](values/prometheus-stack/values.yaml).