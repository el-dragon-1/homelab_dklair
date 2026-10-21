# Baserow Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Baserow. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/baserow-application.yaml](../../apps/argocd/baserow-application.yaml)
- Companion doc: [vault-secrets.md](vault-secrets.md)
- Status: Managed through Argo CD with the sibling values file and a colocated Vault-secrets note.

## Current Deployment Shape
- Reuses the shared PostgreSQL cluster instead of a chart-managed database.
- TLS ingress is handled outside the chart; keep that separation in mind during future troubleshooting.

## Known Good State
- Describe the last healthy rollout and the checks that proved it.

## Recurring Problems
- Capture repeated failures, migration issues, ingress quirks, and dependency ordering problems.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes

### User-level API authentication for schema operations

- Database tokens and the current MCP tools are not sufficient for creating databases, tables, and fields. Use a Baserow user's JWT with the required workspace permissions.
- The schema migration authenticated against `https://baserow.dklair.io/api/user/token-auth/` and used `Authorization: JWT <access_token>` for API calls.
- Baserow 2.2.2 documents access tokens lasting 10 minutes and refresh tokens lasting 168 hours. Save both for long-running work; the earlier access-token-only login expired during migration.
- Keep credentials outside the repository in `~/.config/baserow/schema-clone-auth.json`. Never print, paste into chat, or commit passwords, tokens, or login responses. Do not enable shell tracing (`set -x`).

#### Log in and save access and refresh tokens

Run this entire block in a local terminal. Requires Bash, `curl`, and `jq`. Password entry is hidden; the password is sent on standard input rather than as a command-line argument. A failed login leaves any previous credential file unchanged.

```bash
bash <<'BASH'
set -euo pipefail
umask 077

mkdir -p "$HOME/.config/baserow"
chmod 700 "$HOME/.config/baserow"
read -r -p "Baserow email: " email </dev/tty
read -r -s -p "Baserow password: " password </dev/tty
printf '\n' >/dev/tty

auth_file=$(mktemp "$HOME/.config/baserow/schema-clone-auth.json.XXXXXX")
trap 'rm -f "$auth_file"' EXIT
printf '%s\n' "$email" "$password" \
  | jq -Rn '[inputs] | {username: .[0], password: .[1]}' \
  | curl --fail --silent --show-error \
      'https://baserow.dklair.io/api/user/token-auth/' \
      -H 'Content-Type: application/json' --data-binary @- \
  | jq -e '{access_token: (.access_token // .token), refresh_token}
      | select((.access_token | type == "string" and length > 0)
        and (.refresh_token | type == "string" and length > 0))' \
  > "$auth_file"
unset password
mv "$auth_file" "$HOME/.config/baserow/schema-clone-auth.json"
printf 'Login successful. Migration credentials saved privately.\n'
BASH
```

The directory is restricted to mode `700`, and the credential file to mode `600`. Verify its presence without displaying its contents:

```bash
test -s "$HOME/.config/baserow/schema-clone-auth.json" \
  && echo "Refresh credentials ready"
```

#### Refresh an access token

Requires Node.js 18 or newer. Run before the access token expires, or when an API call reports an expired access token. This updates the private credential file without printing tokens. If refresh fails, stop the API operation and log in again; do not blindly retry schema-creation requests.

```bash
node <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

(async () => {
  const filename = path.join(process.env.HOME, '.config/baserow/schema-clone-auth.json');
  const auth = JSON.parse(fs.readFileSync(filename, 'utf8'));
  if (typeof auth.refresh_token !== 'string' || !auth.refresh_token) {
    throw new Error('No refresh token saved; run the login block again.');
  }
  const response = await fetch('https://baserow.dklair.io/api/user/token-refresh/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token: auth.refresh_token }),
    signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) {
    throw new Error(`Token refresh failed: HTTP ${response.status}. Log in again.`);
  }
  const data = await response.json();
  const accessToken = data.access_token || data.access || data.token;
  if (typeof accessToken !== 'string' || !accessToken) {
    throw new Error('Refresh response did not contain an access token.');
  }
  auth.access_token = accessToken;
  if (data.refresh_token) auth.refresh_token = data.refresh_token;
  fs.chmodSync(filename, 0o600);
  fs.writeFileSync(filename, JSON.stringify(auth), { mode: 0o600 });
  console.log('Access token refreshed and saved privately.');
})().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
NODE
```

For long-running clients, refresh shortly before expiry (the migration used a two-minute margin), then read the saved `access_token` into the HTTP authorization header in memory. Avoid putting tokens in command-line arguments, logs, or scripts. These snippets only authenticate; they do not change database schemas or records.

## Dependencies And Secrets
- Review [vault-secrets.md](vault-secrets.md) for the current Vault path and Secret mapping details.

## Important Files
- Add the highest-signal manifests, scripts, or tutorials to inspect first.

## Open Questions
- Track unresolved risks, TODOs, or follow-up checks.

## CryoSRV Migration Decisions

- On 2026-10-21, the user selected preservation first: retain source values, then rebuild business-critical behavior. This approves a planning policy, not individual field decisions or a data import.
- The read-only audit observed 46 tables, 2,228 fields and 123,327 records in Airtable; `CryoSRV Database2` (Baserow database `22`, workspace `11`) still had zero records. The source was live, so these counts are not an atomic snapshot.
- The field-decision matrix covers every field, including 402 placeholders and 94 configured lookups that depend on placeholders. Private reports and scripts remain outside Git in the originating session's `files/` directory, under the `cryosrv-field-decision-` prefix.
- Use source table, field and record IDs as migration keys. Four duplicate-name pairs require a field-ID-based re-export; name-keyed audit profiles cannot distinguish those fields.
- Preserve original typed values and missing/null/empty/error distinctions in a protected snapshot. Proposed JSON placeholders preserve evidence, not working calculations or useful primary displays. Generated history fields and read-only computed fields need separately approved writable companions when historical values must be available in Baserow.
- Do not collapse directional self-links, discard extra links, regenerate AI output, execute buttons, or grant access while importing identities. Additional schema, identity mappings and operational behavior require explicit approval.
- Next gates: identify business-critical workflows, approve field-level preservation/display choices, obtain missing critical rollup/button definitions, then design a field-ID-based snapshot and separately authorize a staging rehearsal. No data import has been authorized or performed.