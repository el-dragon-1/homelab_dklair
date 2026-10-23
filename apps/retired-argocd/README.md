# Retired test applications

Nextcloud, Homepage, Mailu, Uptime Kuma, and Wger were retired on 2026-10-23
with owner authorization to destroy their test PVC data and release Longhorn
replica allocations.

Their Application manifests are archived here, outside the root Application's
watched `apps/argocd/` directory. Helm values, supplementary manifests, and
Vault/ExternalSecret configuration remain in their original locations.
Shared PostgreSQL databases are not removed by this retirement.

## Re-enable an application

1. Review its retained `values/<app>/` configuration, chart version, secrets,
   database state, and available Longhorn capacity.
2. Move its Application manifest back into `apps/argocd/`, commit, and push.
3. Refresh and sync the root Application for that application only, then sync
   the restored Application if needed.

Re-enabling provisions new empty PVCs; it does not restore deleted files,
mail, Redis state, or other PVC contents. Retained shared databases may still
contain old application data and may need reconciliation with the empty storage.
