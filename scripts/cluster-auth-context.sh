#!/usr/bin/env bash
set -euo pipefail

# Multi-cluster auth/session helper for kubectl, Vault, and Argo CD.
#
# K3S profile is preconfigured for this repository.
# Configure cluster2 (or additional profiles) via environment variables:
#   CLUSTER2_KUBE_CONTEXT
#   CLUSTER2_VAULT_ADDR
#   CLUSTER2_ARGOCD_MODE=direct|port-forward
#   CLUSTER2_ARGOCD_SERVER
#   CLUSTER2_ARGOCD_CONTEXT
#   CLUSTER2_ARGOCD_NAMESPACE (port-forward mode)
#   CLUSTER2_ARGOCD_RESOURCE  (port-forward mode)
#   CLUSTER2_ARGOCD_LOCAL_PORT (port-forward mode)
#   CLUSTER2_ARGOCD_REMOTE_PORT (port-forward mode)

SCRIPT_NAME="$(basename "$0")"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/homelab_dklair"
mkdir -p "$CACHE_DIR"

pass() {
  echo "[PASS] $*"
}

info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*"
}

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME up <profile>
  $SCRIPT_NAME down <profile>
  $SCRIPT_NAME status <profile>
  $SCRIPT_NAME argocd-login <profile>
  $SCRIPT_NAME vault-login <profile>
  $SCRIPT_NAME profiles

Profiles:
  k3s      Preconfigured for this repository
  cluster2 User-configured via environment variables

Examples:
  $SCRIPT_NAME up k3s
  $SCRIPT_NAME argocd-login k3s
  $SCRIPT_NAME vault-login k3s

Notes:
  - In port-forward mode, this script manages a background kubectl port-forward.
  - For Vault CLI use outside this script, run: export VAULT_ADDR=<printed value>
EOF
}

profile_upper() {
  echo "$1" | tr '[:lower:]-' '[:upper:]_'
}

config_from_env_or_default() {
  local profile="$1"
  local key="$2"
  local default_value="$3"
  local prefix
  prefix="$(profile_upper "$profile")"
  local var_name="${prefix}_${key}"
  local value="${!var_name:-$default_value}"
  echo "$value"
}

load_profile() {
  PROFILE="$1"
  case "$PROFILE" in
    k3s|cluster2)
      ;;
    *)
      fail "Unknown profile '$PROFILE'. Use one of: k3s, cluster2"
      ;;
  esac

  if [[ "$PROFILE" == "k3s" ]]; then
    KUBE_CONTEXT="$(config_from_env_or_default "$PROFILE" KUBE_CONTEXT "K3S")"
    VAULT_ADDR="$(config_from_env_or_default "$PROFILE" VAULT_ADDR "http://192.168.4.103:8200")"
    ARGOCD_MODE="$(config_from_env_or_default "$PROFILE" ARGOCD_MODE "port-forward")"
    ARGOCD_SERVER="$(config_from_env_or_default "$PROFILE" ARGOCD_SERVER "127.0.0.1:18080")"
    ARGOCD_CONTEXT="$(config_from_env_or_default "$PROFILE" ARGOCD_CONTEXT "k3s-local")"
    ARGOCD_NAMESPACE="$(config_from_env_or_default "$PROFILE" ARGOCD_NAMESPACE "argocd")"
    ARGOCD_RESOURCE="$(config_from_env_or_default "$PROFILE" ARGOCD_RESOURCE "svc/argocd-server")"
    ARGOCD_LOCAL_PORT="$(config_from_env_or_default "$PROFILE" ARGOCD_LOCAL_PORT "18080")"
    ARGOCD_REMOTE_PORT="$(config_from_env_or_default "$PROFILE" ARGOCD_REMOTE_PORT "80")"
  else
    KUBE_CONTEXT="$(config_from_env_or_default "$PROFILE" KUBE_CONTEXT "")"
    VAULT_ADDR="$(config_from_env_or_default "$PROFILE" VAULT_ADDR "")"
    ARGOCD_MODE="$(config_from_env_or_default "$PROFILE" ARGOCD_MODE "direct")"
    ARGOCD_SERVER="$(config_from_env_or_default "$PROFILE" ARGOCD_SERVER "")"
    ARGOCD_CONTEXT="$(config_from_env_or_default "$PROFILE" ARGOCD_CONTEXT "cluster2")"
    ARGOCD_NAMESPACE="$(config_from_env_or_default "$PROFILE" ARGOCD_NAMESPACE "argocd")"
    ARGOCD_RESOURCE="$(config_from_env_or_default "$PROFILE" ARGOCD_RESOURCE "svc/argocd-server")"
    ARGOCD_LOCAL_PORT="$(config_from_env_or_default "$PROFILE" ARGOCD_LOCAL_PORT "18081")"
    ARGOCD_REMOTE_PORT="$(config_from_env_or_default "$PROFILE" ARGOCD_REMOTE_PORT "80")"
  fi

  [[ -n "$KUBE_CONTEXT" ]] || fail "${PROFILE}: missing KUBE_CONTEXT"
  [[ -n "$VAULT_ADDR" ]] || fail "${PROFILE}: missing VAULT_ADDR"
  [[ "$ARGOCD_MODE" == "direct" || "$ARGOCD_MODE" == "port-forward" ]] || fail "${PROFILE}: ARGOCD_MODE must be direct or port-forward"

  if [[ "$ARGOCD_MODE" == "direct" ]]; then
    [[ -n "$ARGOCD_SERVER" ]] || fail "${PROFILE}: ARGOCD_SERVER required when ARGOCD_MODE=direct"
  else
    [[ -n "$ARGOCD_NAMESPACE" && -n "$ARGOCD_RESOURCE" ]] || fail "${PROFILE}: ARGOCD_NAMESPACE and ARGOCD_RESOURCE required for port-forward mode"
    [[ -n "$ARGOCD_LOCAL_PORT" && -n "$ARGOCD_REMOTE_PORT" ]] || fail "${PROFILE}: ARGOCD_LOCAL_PORT and ARGOCD_REMOTE_PORT required for port-forward mode"
    ARGOCD_SERVER="127.0.0.1:${ARGOCD_LOCAL_PORT}"
  fi

  PF_PID_FILE="$CACHE_DIR/argocd-pf-${PROFILE}.pid"
  PF_LOG_FILE="$CACHE_DIR/argocd-pf-${PROFILE}.log"
}

pf_running() {
  [[ -f "$PF_PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PF_PID_FILE" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

wait_for_local_port() {
  local host="$1"
  local port="$2"
  local retries=30
  local i

  for i in $(seq 1 "$retries"); do
    if curl -sS "http://${host}:${port}/" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  return 1
}

start_port_forward() {
  [[ "$ARGOCD_MODE" == "port-forward" ]] || return 0

  if pf_running; then
    pass "Argo CD port-forward already running for ${PROFILE} (pid $(cat "$PF_PID_FILE"))"
    return 0
  fi

  info "Starting Argo CD port-forward for ${PROFILE} (${ARGOCD_SERVER})"
  nohup kubectl --context "$KUBE_CONTEXT" -n "$ARGOCD_NAMESPACE" \
    port-forward "$ARGOCD_RESOURCE" "${ARGOCD_LOCAL_PORT}:${ARGOCD_REMOTE_PORT}" \
    >"$PF_LOG_FILE" 2>&1 &

  local pid=$!
  echo "$pid" >"$PF_PID_FILE"

  if wait_for_local_port "127.0.0.1" "$ARGOCD_LOCAL_PORT"; then
    pass "Argo CD port-forward is ready (pid $pid)"
  else
    warn "Argo CD port-forward did not become ready in time"
    warn "Check logs: $PF_LOG_FILE"
    return 1
  fi
}

stop_port_forward() {
  [[ "$ARGOCD_MODE" == "port-forward" ]] || return 0

  if ! pf_running; then
    info "No running Argo CD port-forward for ${PROFILE}"
    rm -f "$PF_PID_FILE"
    return 0
  fi

  local pid
  pid="$(cat "$PF_PID_FILE")"
  info "Stopping Argo CD port-forward for ${PROFILE} (pid $pid)"
  kill "$pid" 2>/dev/null || true
  rm -f "$PF_PID_FILE"
  pass "Argo CD port-forward stopped"
}

switch_kube_context() {
  info "Switching kubectl context to ${KUBE_CONTEXT}"
  kubectl config use-context "$KUBE_CONTEXT" >/dev/null
  pass "kubectl current context: $(kubectl config current-context)"
}

check_kube() {
  if kubectl --context "$KUBE_CONTEXT" get ns --request-timeout=10s >/dev/null 2>&1; then
    pass "Kubernetes API reachable via context ${KUBE_CONTEXT}"
    return 0
  fi
  warn "Kubernetes API check failed for context ${KUBE_CONTEXT}"
  return 1
}

check_vault() {
  if VAULT_ADDR="$VAULT_ADDR" vault status >/dev/null 2>&1; then
    pass "Vault reachable at ${VAULT_ADDR}"
    return 0
  fi
  warn "Vault check failed at ${VAULT_ADDR}"
  return 1
}

check_argocd() {
  local cmd=(argocd --server "$ARGOCD_SERVER")

  if [[ "$ARGOCD_MODE" == "port-forward" ]]; then
    cmd+=(--plaintext --grpc-web)
  else
    cmd+=(--grpc-web)
  fi

  cmd+=(account get-user-info)

  if "${cmd[@]}" >/dev/null 2>&1; then
    pass "Argo CD API reachable and authenticated at ${ARGOCD_SERVER}"
    return 0
  fi

  warn "Argo CD check failed at ${ARGOCD_SERVER} (likely needs login or transport fix)"
  return 1
}

cmd_up() {
  need_cmd kubectl
  need_cmd argocd
  need_cmd vault
  need_cmd curl

  switch_kube_context
  check_kube || true

  if [[ "$ARGOCD_MODE" == "port-forward" ]]; then
    start_port_forward || true
  fi

  check_argocd || true
  check_vault || true

  echo ""
  info "Session summary for profile ${PROFILE}:"
  echo "  kubectl context : ${KUBE_CONTEXT}"
  echo "  vault addr      : ${VAULT_ADDR}"
  echo "  argocd server   : ${ARGOCD_SERVER}"
  echo "  argocd mode     : ${ARGOCD_MODE}"
  echo ""
  echo "Run these when needed:"
  echo "  export VAULT_ADDR=${VAULT_ADDR}"
  echo "  $SCRIPT_NAME argocd-login ${PROFILE}"
  echo "  $SCRIPT_NAME vault-login ${PROFILE}"
}

cmd_down() {
  stop_port_forward
}

cmd_status() {
  need_cmd kubectl
  need_cmd argocd
  need_cmd vault

  echo "Profile: ${PROFILE}"
  echo "  kubectl context target: ${KUBE_CONTEXT}"
  echo "  vault addr: ${VAULT_ADDR}"
  echo "  argocd mode/server: ${ARGOCD_MODE} / ${ARGOCD_SERVER}"

  if [[ "$(kubectl config current-context 2>/dev/null || true)" == "$KUBE_CONTEXT" ]]; then
    pass "Current kubectl context matches ${KUBE_CONTEXT}"
  else
    warn "Current kubectl context does not match ${KUBE_CONTEXT}"
  fi

  check_kube || true

  if [[ "$ARGOCD_MODE" == "port-forward" ]]; then
    if pf_running; then
      pass "Argo CD port-forward running (pid $(cat "$PF_PID_FILE"))"
    else
      warn "Argo CD port-forward not running"
    fi
  fi

  check_argocd || true
  check_vault || true
}

cmd_argocd_login() {
  need_cmd argocd
  need_cmd kubectl
  need_cmd curl

  if [[ "$ARGOCD_MODE" == "port-forward" ]]; then
    start_port_forward
    info "Logging into Argo CD via local tunnel ${ARGOCD_SERVER}"
    argocd login "$ARGOCD_SERVER" --plaintext --grpc-web --name "$ARGOCD_CONTEXT"
  else
    info "Logging into Argo CD directly at ${ARGOCD_SERVER}"
    argocd login "$ARGOCD_SERVER" --grpc-web --name "$ARGOCD_CONTEXT"
  fi

  pass "Argo CD login complete for context ${ARGOCD_CONTEXT}"
}

cmd_vault_login() {
  need_cmd vault
  info "Logging into Vault at ${VAULT_ADDR}"
  VAULT_ADDR="$VAULT_ADDR" vault login
}

cmd_profiles() {
  cat <<EOF
k3s
cluster2
EOF
}

main() {
  local command="${1:-}"
  local profile="${2:-}"

  if [[ -z "$command" ]]; then
    usage
    exit 1
  fi

  case "$command" in
    profiles)
      cmd_profiles
      exit 0
      ;;
    up|down|status|argocd-login|vault-login)
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown command '$command'"
      ;;
  esac

  [[ -n "$profile" ]] || fail "Missing profile argument"
  load_profile "$profile"

  case "$command" in
    up)
      cmd_up
      ;;
    down)
      cmd_down
      ;;
    status)
      cmd_status
      ;;
    argocd-login)
      cmd_argocd_login
      ;;
    vault-login)
      cmd_vault_login
      ;;
  esac
}

main "$@"
