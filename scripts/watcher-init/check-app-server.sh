#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: check-app-server.sh /path/to/watcher.env [--tcp-only] [--create-smoke-thread] [--start-smoke-turn]

Checks Codex app-server reachability. Default mode verifies the WebSocket
JSON-RPC initialize handshake through the Haskell watcher client. Optional flags
can also verify thread/start and turn/start.
EOF
}

env_file="${1:-}"
if [[ -z "$env_file" || "$env_file" == "-h" || "$env_file" == "--help" ]]; then
  usage
  exit 0
fi
shift || true

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"
load_watcher_env "$env_file"

: "${APP_SERVER_HOST:?}"
: "${APP_SERVER_PORT:?}"
: "${APP_SERVER_PATH:=/}"
: "${APP_SERVER_CHECK_MODE:=protocol}"
: "${APP_SERVER_CREATE_SMOKE_THREAD:=false}"
: "${APP_SERVER_START_SMOKE_TURN:=false}"

tcp_only=false
create_smoke_thread="$APP_SERVER_CREATE_SMOKE_THREAD"
start_smoke_turn="$APP_SERVER_START_SMOKE_TURN"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tcp-only)
      tcp_only=true
      ;;
    --create-smoke-thread)
      create_smoke_thread=true
      ;;
    --start-smoke-turn)
      start_smoke_turn=true
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "$APP_SERVER_CHECK_MODE" == "tcp" ]]; then
  tcp_only=true
fi

case "$APP_SERVER_CHECK_MODE" in
  protocol|tcp)
    ;;
  *)
    printf 'invalid APP_SERVER_CHECK_MODE: %s (expected protocol or tcp)\n' "$APP_SERVER_CHECK_MODE" >&2
    exit 2
    ;;
esac

case "$create_smoke_thread" in
  true|false)
    ;;
  *)
    printf 'invalid APP_SERVER_CREATE_SMOKE_THREAD: %s (expected true or false)\n' "$create_smoke_thread" >&2
    exit 2
    ;;
esac

case "$start_smoke_turn" in
  true|false)
    ;;
  *)
    printf 'invalid APP_SERVER_START_SMOKE_TURN: %s (expected true or false)\n' "$start_smoke_turn" >&2
    exit 2
    ;;
esac

printf 'app-server endpoint: %s:%s%s\n' "$APP_SERVER_HOST" "$APP_SERVER_PORT" "$APP_SERVER_PATH"

if APP_SERVER_TCP_HOST="$APP_SERVER_HOST" APP_SERVER_TCP_PORT="$APP_SERVER_PORT" \
  timeout 2 bash -c 'cat < /dev/null > "/dev/tcp/$APP_SERVER_TCP_HOST/$APP_SERVER_TCP_PORT"' 2>/dev/null; then
  printf 'ok app-server tcp\n'
else
  printf 'could not connect to app-server tcp\n' >&2
  exit 1
fi

if [[ "$tcp_only" == true ]]; then
  printf 'app-server protocol probe skipped: tcp-only mode\n'
  exit 0
fi

: "${WATCHER_BIN:?}"
if [[ ! -x "$WATCHER_BIN" ]]; then
  printf 'watcher bin not executable: %s\n' "$WATCHER_BIN" >&2
  exit 1
fi

probe_args=(
  probe-app-server
  --app-server-host "$APP_SERVER_HOST"
  --app-server-port "$APP_SERVER_PORT"
  --app-server-path "$APP_SERVER_PATH"
  --workdir "${TARGET_WORKDIR:-${WATCHER_REPO:-.}}"
)

if [[ -n "${APP_SERVER_PROBE_THREAD_ID:-}" ]]; then
  probe_args+=(--thread-id "$APP_SERVER_PROBE_THREAD_ID")
fi

if [[ "$create_smoke_thread" == true ]]; then
  probe_args+=(--create-smoke-thread)
fi

if [[ "$start_smoke_turn" == true ]]; then
  probe_args+=(--start-smoke-turn)
fi

"$WATCHER_BIN" "${probe_args[@]}"
