# Homelab DKLair High-Level Copilot Instructions

This file is the organized home for high-level repository guidance.

## Compatibility

- Keep .github/copilot-instructions.md as the entrypoint for instruction auto-loading.
- Keep this file aligned with that entrypoint so both remain consistent.

## Working Principle

- Start from the nearest owning file and the smallest relevant document set.
- Do not widen scope until the local change is understood.

## Application Context Discipline

- For application troubleshooting, read values/<application>/context.md early.
- Reuse validated fixes from that file before broad exploration.
- After a productive session, update only the corresponding values/<application>/context.md.
- Do not place one application's incident notes in another application's context file.

## Validation

- Always select the `K3S` Kubernetes context for this repository. Verify it before cluster operations and use `kubectl --context K3S` explicitly. If K3S authentication or connectivity fails, report the blocker; never fall back to another cluster.
- Use the narrowest useful validation command for touched files.
- Prefer focused checks over broad repository-wide runs.
- Report assumptions and unresolved gaps explicitly.
