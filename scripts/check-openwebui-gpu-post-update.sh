#!/usr/bin/env bash
set -euo pipefail

NS_OPENWEBUI="open-webui"
NS_ARGOCD="argocd"
APP_NAME="open-webui"

pass() {
  echo "[PASS] $1"
}

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

info() {
  echo "[INFO] $1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

need_cmd kubectl

info "Checking Argo CD application sync and health"
status_line="$(kubectl get application -n "$NS_ARGOCD" "$APP_NAME" -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revisions}')"
sync_status="$(echo "$status_line" | awk '{print $1}')"
health_status="$(echo "$status_line" | awk '{print $2}')"

[[ "$sync_status" == "Synced" ]] || fail "Argo app is not Synced (got: $sync_status)"
[[ "$health_status" == "Healthy" ]] || fail "Argo app is not Healthy (got: $health_status)"
pass "Argo app is Synced and Healthy"

info "Checking Ollama deployment rollout"
kubectl rollout status deployment/open-webui-ollama -n "$NS_OPENWEBUI" --timeout=180s >/dev/null
pass "Ollama deployment is rolled out"

info "Checking Ollama service endpoint presence"
endpoint_count="$(kubectl get endpoints -n "$NS_OPENWEBUI" open-webui-ollama -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w | tr -d ' ')"
[[ "$endpoint_count" -ge 1 ]] || fail "Ollama service has no endpoints"
pass "Ollama service has endpoint(s)"

info "Checking runtime class and GPU resource requests"
runtime_class="$(kubectl get deploy -n "$NS_OPENWEBUI" open-webui-ollama -o jsonpath='{.spec.template.spec.runtimeClassName}')"
[[ "$runtime_class" == "nvidia" ]] || fail "Ollama runtimeClassName is not nvidia (got: $runtime_class)"

gpu_req="$(kubectl get deploy -n "$NS_OPENWEBUI" open-webui-ollama -o jsonpath='{.spec.template.spec.containers[0].resources.requests.nvidia\.com/gpu}')"
[[ "$gpu_req" == "1" ]] || fail "Ollama GPU request is not 1 (got: $gpu_req)"
pass "Ollama deployment requests GPU with nvidia runtime"

info "Selecting running Ollama pod"
ollama_pod="$(kubectl get pods -n "$NS_OPENWEBUI" -l app.kubernetes.io/component=open-webui-ollama -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' | awk '$2=="Running"{print $1; exit}')"
[[ -n "$ollama_pod" ]] || fail "No running Ollama pod found"
pass "Running pod: $ollama_pod"

info "Checking NVIDIA device visibility in container"
kubectl exec -n "$NS_OPENWEBUI" "$ollama_pod" -- /bin/sh -lc 'ls /dev/nvidia0 /dev/nvidiactl >/dev/null 2>&1' || fail "NVIDIA device nodes are not visible in Ollama container"
pass "NVIDIA device nodes are visible"

info "Running a short test inference"
kubectl exec -n "$NS_OPENWEBUI" "$ollama_pod" -- /bin/sh -lc 'ollama run granite4.1:8b "Respond with the word OK." >/dev/null 2>&1' || fail "Test inference failed"

processor_line="$(kubectl exec -n "$NS_OPENWEBUI" "$ollama_pod" -- /bin/sh -lc 'ollama ps' | sed -n '2p' || true)"
echo "[INFO] ollama ps: $processor_line"
echo "$processor_line" | grep -q "GPU" || fail "Inference runner is not using GPU"
pass "Inference runner is using GPU"

echo ""
echo "All post-update checks passed."
