---
description: "Use when editing OpenWRT baseline, desired state, or openwrt-ops manifests and tutorials."
applyTo: ["openwrt/**", "apps/openwrt-ops/**", "apps/argocd/openwrt-ops-application.yaml", "tutorials/openwrt/**", "tutorials/cudy-m3000-onboarding.md"]
---

# OpenWRT Workflow

- Read `openwrt/README.md` before editing device configs.
- Keep `openwrt/baseline` sanitized and `openwrt/desired` as the enforced GitOps source of truth.
- Keep one UCI file per configuration area.
- Do not commit secrets, raw exports, or literal placeholder expansions.
- When changing Ansible or CronJob behavior, confirm the matching secret and device file names still align.
- Prefer updating the nearest device or runbook doc instead of the root README unless the change is cross-cutting.