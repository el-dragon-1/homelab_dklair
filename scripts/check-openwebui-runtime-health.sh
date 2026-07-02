#!/usr/bin/env bash
set -euo pipefail

NS_OPENWEBUI="open-webui"
NS_ARGOCD="argocd"
APP_NAME="open-webui"
EXPECTED_DB_HOST="postgresql-rw.postgresql.svc.cluster.local"

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
need_cmd awk
need_cmd grep

if [[ -z "${KUBECONFIG:-}" && -f "$HOME/kube/k3s.yaml" ]]; then
  export KUBECONFIG="$HOME/kube/k3s.yaml"
fi

info "Checking Argo CD application sync and health"
status_line="$(kubectl get application -n "$NS_ARGOCD" "$APP_NAME" -o jsonpath='{.status.sync.status} {.status.health.status}')"
sync_status="$(echo "$status_line" | awk '{print $1}')"
health_status="$(echo "$status_line" | awk '{print $2}')"

[[ "$sync_status" == "Synced" ]] || fail "Argo app is not Synced (got: $sync_status)"
[[ "$health_status" == "Healthy" ]] || fail "Argo app is not Healthy (got: $health_status)"
pass "Argo app is Synced and Healthy"

info "Checking Open WebUI StatefulSet rollout"
kubectl rollout status statefulset/open-webui -n "$NS_OPENWEBUI" --timeout=180s >/dev/null
pass "Open WebUI StatefulSet is rolled out"

info "Selecting running Open WebUI pod"
owui_pod="$(kubectl get pods -n "$NS_OPENWEBUI" -l app.kubernetes.io/component=open-webui -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' | awk '$2=="Running"{print $1; exit}')"
[[ -n "$owui_pod" ]] || fail "No running Open WebUI pod found"
pass "Running pod: $owui_pod"

info "Validating Open WebUI database environment"
db_type="$(kubectl get sts -n "$NS_OPENWEBUI" open-webui -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DATABASE_TYPE")].value}')"
db_host="$(kubectl get sts -n "$NS_OPENWEBUI" open-webui -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DATABASE_HOST")].value}')"

[[ "$db_type" == "postgresql" ]] || fail "DATABASE_TYPE is not postgresql (got: $db_type)"
[[ "$db_host" == "$EXPECTED_DB_HOST" ]] || fail "DATABASE_HOST is not expected shared service (got: $db_host)"
pass "Open WebUI env targets shared PostgreSQL ($db_host)"

info "Checking PostgreSQL reachability from Open WebUI pod"
kubectl exec -n "$NS_OPENWEBUI" "$owui_pod" -- /bin/sh -lc "python - <<'PY'
import socket
host = '$EXPECTED_DB_HOST'
port = 5432
s = socket.socket()
s.settimeout(2)
s.connect((host, port))
s.close()
print('ok')
PY" >/dev/null
pass "Open WebUI pod can reach shared PostgreSQL"

info "Checking Ollama deployment and endpoint availability"
ollama_replicas="$(kubectl get deploy -n "$NS_OPENWEBUI" open-webui-ollama -o jsonpath='{.spec.replicas}')"
[[ "${ollama_replicas:-0}" -ge 1 ]] || fail "open-webui-ollama replicas is < 1 (got: ${ollama_replicas:-unset})"

ollama_endpoint_count="$(kubectl get endpoints -n "$NS_OPENWEBUI" open-webui-ollama -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w | tr -d ' ')"
[[ "${ollama_endpoint_count:-0}" -ge 1 ]] || fail "Ollama service has no endpoints"
pass "Ollama is available (replicas=${ollama_replicas}, endpoints=${ollama_endpoint_count})"

info "Checking websocket/redis alignment"
ws_enabled="$(kubectl get sts -n "$NS_OPENWEBUI" open-webui -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="ENABLE_WEBSOCKET_SUPPORT")].value}')"
ws_manager="$(kubectl get sts -n "$NS_OPENWEBUI" open-webui -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="WEBSOCKET_MANAGER")].value}')"

if [[ "$ws_enabled" == "True" && "$ws_manager" == "redis" ]]; then
  redis_replicas="$(kubectl get deploy -n "$NS_OPENWEBUI" open-webui-redis -o jsonpath='{.spec.replicas}')"
  [[ "${redis_replicas:-0}" -ge 1 ]] || fail "websocket manager is redis but open-webui-redis replicas is < 1 (got: ${redis_replicas:-unset})"

  redis_endpoint_count="$(kubectl get endpoints -n "$NS_OPENWEBUI" open-webui-redis -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w | tr -d ' ')"
  [[ "${redis_endpoint_count:-0}" -ge 1 ]] || fail "websocket manager is redis but open-webui-redis has no endpoints"

  pass "Websocket redis manager is healthy (replicas=${redis_replicas}, endpoints=${redis_endpoint_count})"
else
  pass "Websocket redis dependency not active (ENABLE_WEBSOCKET_SUPPORT=${ws_enabled:-unset}, WEBSOCKET_MANAGER=${ws_manager:-unset})"
fi

info "Scanning recent logs for Redis connection-refused errors"
if kubectl logs -n "$NS_OPENWEBUI" "$owui_pod" --since=5m | grep -q "open-webui-redis.*Connection refused"; then
  fail "Detected recent Redis connection refused errors in Open WebUI logs"
fi
pass "No Redis connection refused errors in last 5 minutes"

echo ""
echo "All Open WebUI runtime health checks passed."
