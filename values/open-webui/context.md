# Open WebUI Context

Use this file to preserve the durable outcome of Copilot chats about building and troubleshooting Open WebUI. Record conclusions and validated fixes here; do not paste raw chat transcripts.

## When To Update This File
- Update it after a session produces a durable conclusion worth carrying forward.
- Prefer updates only after you validate a fix, confirm a root cause, or eliminate a costly false lead.
- Keep entries short and capture conclusions, not raw chat history.

## Repo Anchors
- Values file: [values.yaml](values.yaml)
- Argo CD application: [../../apps/argocd/open-webui-application.yaml](../../apps/argocd/open-webui-application.yaml)
- Related scripts: [../../scripts/check-openwebui-gpu-post-update.sh](../../scripts/check-openwebui-gpu-post-update.sh), [../../scripts/check-openwebui-runtime-health.sh](../../scripts/check-openwebui-runtime-health.sh)
- Status: Managed through Argo CD with dedicated runtime and post-update validation scripts.

## Current Deployment Shape
- Deploys to namespace `open-webui` from the upstream `open-webui` chart at target revision `14.8.0`.
- Exposes the UI at `ai.dklair.io` through Traefik with TLS secret `open-webui-tls` and ClusterIssuer `letsencrypt-prod`.
- Runs a single Open WebUI replica and a single embedded Ollama replica on node `eldragon` with `amd64` pinning.
- The Ollama workload uses `runtimeClassName: nvidia`, requests one NVIDIA GPU, mounts a `40Gi` Longhorn volume, and caps CPU at `950m` to limit sustained thermals.
- Open WebUI itself stores app data on a separate `10Gi` Longhorn volume.
- Websocket support is intentionally disabled and kept in memory to avoid Redis dependency failures on a single-replica deployment.
- Application state uses the shared PostgreSQL cluster at `postgresql-rw.postgresql.svc.cluster.local` with credentials from Secret `open-webui-db`.
- Web search is enabled through Tavily-backed secrets in `open-webui-search`, with sequential request limits to reduce provider bursts.

## Known Good State
- Argo CD reports the `open-webui` application as `Synced` and `Healthy`.
- `deployment/open-webui-ollama` in namespace `open-webui` completes rollout and its service has at least one endpoint.
- The deployed Ollama pod keeps `runtimeClassName: nvidia`, GPU limit `1`, CPU limit `950m`, `OLLAMA_NUM_PARALLEL=1`, and `OLLAMA_MAX_LOADED_MODELS=1`.
- NVIDIA device nodes are visible in the Ollama container and a short `ollama run granite4.1:8b` test shows GPU usage in `ollama ps`.

## Recurring Problems
- Capture repeated failures, GPU visibility issues, backend reachability problems, and upgrade regressions.

## Troubleshooting History
- Date:
- Issue:
- Root cause:
- Fix:
- Validation:

## Working Fixes
- After chart or values changes, run [../../scripts/check-openwebui-gpu-post-update.sh](../../scripts/check-openwebui-gpu-post-update.sh) before treating the rollout as complete.
- If web search starts failing, preserve `ENABLE_SEARCH_QUERY_GENERATION=True`; the current values note that disabling it breaks the middleware path.
- Keep websocket/Redis disabled unless the deployment model changes beyond the current single-replica topology.

## Dependencies And Secrets
- Secret `open-webui-db` provides PostgreSQL username and password.
- Secret `open-webui-search` provides `tavily_api_key` and `brave_search_api_key`.
- Depends on Longhorn for both the app PVC and the Ollama model PVC.
- Depends on NVIDIA runtime support on node `eldragon`.

## Important Files
- [../../apps/argocd/open-webui-application.yaml](../../apps/argocd/open-webui-application.yaml)
- [values.yaml](values.yaml)
- [../../scripts/check-openwebui-gpu-post-update.sh](../../scripts/check-openwebui-gpu-post-update.sh)
- [../../scripts/check-openwebui-runtime-health.sh](../../scripts/check-openwebui-runtime-health.sh)

## Open Questions
- If GPU contention or thermals change, reevaluate the current single-model and single-parallelism throttles before increasing concurrency.