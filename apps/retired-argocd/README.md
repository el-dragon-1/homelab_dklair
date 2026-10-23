# Retired test applications

Nextcloud, Homepage, Mailu, Uptime Kuma, Wger, Aliasvault, and Vaultwarden were retired on 2026-10-23
with owner authorization to destroy their test PVC data and release Longhorn
replica allocations.

Their Application manifests are archived here, outside the root Application's
watched `apps/argocd/` directory. Helm values, supplementary manifests, and
Vault/ExternalSecret configuration remain in their original locations.
Shared PostgreSQL databases are not removed by this retirement.

Subsequent owner-approved database cleanup on 2026-10-23 removed the shared
databases `aliasvault`, `nextcloud`, `mailu`, and `wger`, their dedicated roles,
and Wger's inactive replication slot. The shared `dpolizzi` role was preserved
because Authentik still uses it. Vault/ExternalSecret configuration remains.
Re-provision the required database and role before restoring any of these apps.

Aliasvault and Vaultwarden retirement includes permanent deletion of their
six PVCs (39 GiB logical), including local databases, attachments, certificates,
logs, and generated application secrets. Retained Vault credentials and any shared
database alone do not constitute a recoverable backup of these applications.

## Re-enable an application

1. Review its retained `values/<app>/` configuration, chart version, secrets,
   database state, and available Longhorn capacity.
2. Move its Application manifest back into `apps/argocd/`, commit, and push.
3. Refresh and sync the root Application for that application only, then sync
   the restored Application if needed.

Re-enabling provisions new empty PVCs; it does not restore deleted files,
mail, Redis state, or other PVC contents. Retained shared databases may still
contain old application data and may need reconciliation with the empty storage.
