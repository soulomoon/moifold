#!/usr/bin/env bash

load_watcher_env() {
  local env_file="${1:?missing watcher env file}"
  set -a
  source "$env_file"
  set +a
  export PATH="$HOME/.ghcup/bin:$HOME/.cabal/bin:$PATH"
}

require_env() {
  local name
  for name in "$@"; do
    if [[ -z "${!name:-}" ]]; then
      printf 'missing required env var: %s\n' "$name" >&2
      exit 2
    fi
  done
}

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'missing required tool: %s\n' "$tool" >&2
    exit 127
  fi
}

watcher_repo_slug() {
  local repo="$1"
  LC_ALL=C sed 's/[^[:alnum:]]/_/g' <<<"$repo"
}

write_event_if_missing() {
  local events_path="$1"
  local event_json="$2"
  if [[ ! -e "$events_path" ]]; then
    printf '%s\n' "$event_json" > "$events_path"
  fi
}

write_command_script() {
  local script_path="$1"
  shift

  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf 'exec'
    local arg
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
  } > "$script_path"
  chmod +x "$script_path"
}
