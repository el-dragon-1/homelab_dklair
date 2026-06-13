---
description: "Use when editing tutorials, runbooks, and documentation files under tutorials/."
applyTo: ["tutorials/**"]
---

# Tutorials and Runbooks

- Keep tutorials procedural: prerequisites, steps, verification, and rollback or cleanup when relevant.
- Treat files under `tutorials/` as operator guidance, not a second source of truth for cluster or OpenWRT config.
- Link back to the owning manifest or README instead of repeating large config blocks.
- Prefer one focused document per workflow or device instead of combining unrelated procedures.
- Keep examples current with the repo's actual paths, namespaces, and command patterns.
- When a tutorial changes behavior, update the nearest tutorial first and only then cross-link from broader docs if needed.