#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: check-project-setup.sh /path/to/watcher.env [--install]

Checks watcher prerequisites and target-project dependency entrypoints.
Default mode reports missing tools and suggested install/setup commands only.
Use --install only after the operator has decided dependency installation is allowed.
EOF
}

env_file="${1:-}"
if [[ -z "$env_file" || "$env_file" == "-h" || "$env_file" == "--help" ]]; then
  usage
  exit 0
fi
shift || true

install=false
case "${1:-}" in
  "")
    ;;
  --install)
    install=true
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

set -a
source "$env_file"
set +a

export PATH="$HOME/.ghcup/bin:$HOME/.cabal/bin:$PATH"

: "${WATCHER_REPO:?}"
: "${REPO_FULL_NAME:?}"
: "${TARGET_WORKDIR:?}"
: "${STATE_ROOT:=/workspace/artifacts}"
: "${APP_SERVER_HOST:?}"
: "${APP_SERVER_PORT:?}"
: "${APP_SERVER_PATH:=/}"
: "${ALLOW_DEPENDENCY_INSTALL:=false}"

missing_tools=()
setup_commands=()
service_problems=()
state_problems=()

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  local tool="$1"
  if have_cmd "$tool"; then
    printf 'ok tool: %s -> %s\n' "$tool" "$(command -v "$tool")"
  else
    printf 'missing tool: %s\n' "$tool"
    missing_tools+=("$tool")
  fi
}

add_setup_command() {
  local command_text="$1"
  local existing
  for existing in "${setup_commands[@]}"; do
    [[ "$existing" == "$command_text" ]] && return 0
  done
  setup_commands+=("$command_text")
}

print_section() {
  printf '\n== %s ==\n' "$1"
}

print_section "base tools"
require_cmd git
require_cmd gh
require_cmd ghcup
require_cmd ghc
require_cmd cabal
require_cmd bash
require_cmd timeout

print_section "haskell toolchain"
if have_cmd ghcup; then
  printf 'ok ghcup: %s\n' "$(command -v ghcup)"
else
  add_setup_command "curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh"
fi

if have_cmd ghc; then
  ghc --numeric-version | sed 's/^/ghc version: /'
  case "$(command -v ghc)" in
    *ghcup*) printf 'ok ghc managed by ghcup: %s\n' "$(command -v ghc)" ;;
    *) printf 'warning: ghc is not on a ghcup path: %s\n' "$(command -v ghc)" ;;
  esac
else
  add_setup_command "ghcup install ghc recommended && ghcup set ghc recommended"
fi

if have_cmd cabal; then
  cabal --numeric-version | sed 's/^/cabal version: /'
  case "$(command -v cabal)" in
    *ghcup*) printf 'ok cabal managed by ghcup: %s\n' "$(command -v cabal)" ;;
    *) printf 'warning: cabal is not on a ghcup path: %s\n' "$(command -v cabal)" ;;
  esac
else
  add_setup_command "ghcup install cabal recommended && ghcup set cabal recommended"
fi

print_section "required services"
printf 'app-server: %s:%s%s\n' "$APP_SERVER_HOST" "$APP_SERVER_PORT" "$APP_SERVER_PATH"
printf 'required protocol: Codex app-server thread/read, thread/start, turn/start, structured turn outputs\n'

print_section "watcher repo"
if [[ ! -d "$WATCHER_REPO" ]]; then
  printf 'missing watcher repo: %s\n' "$WATCHER_REPO"
else
  git -C "$WATCHER_REPO" status --short || true
  add_setup_command "cd '$WATCHER_REPO' && cabal build all"
fi

if [[ -n "${WATCHER_BIN:-}" && -x "${WATCHER_BIN:-}" ]]; then
  printf 'ok watcher bin: %s\n' "$WATCHER_BIN"
else
  printf 'watcher bin not executable yet; build and resolve with cabal list-bin moifold\n'
fi

print_section "github"
gh auth status || true

print_section "target project"
if [[ ! -d "$TARGET_WORKDIR" ]]; then
  printf 'missing target workdir: %s\n' "$TARGET_WORKDIR"
else
  git -C "$TARGET_WORKDIR" status --short || true
  if [[ -w "$TARGET_WORKDIR" ]]; then
    printf 'ok target workdir writable: %s\n' "$TARGET_WORKDIR"
  else
    printf 'target workdir is not writable: %s\n' "$TARGET_WORKDIR"
    state_problems+=("target workdir not writable: $TARGET_WORKDIR")
  fi
fi

print_section "state root"
mkdir -p "$STATE_ROOT"
if [[ -w "$STATE_ROOT" ]]; then
  printf 'ok state root writable: %s\n' "$STATE_ROOT"
else
  printf 'state root is not writable: %s\n' "$STATE_ROOT"
  state_problems+=("state root not writable: $STATE_ROOT")
fi

print_section "app server"
if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$APP_SERVER_HOST/$APP_SERVER_PORT" 2>/dev/null; then
  printf 'ok app-server tcp: %s:%s%s\n' "$APP_SERVER_HOST" "$APP_SERVER_PORT" "$APP_SERVER_PATH"
else
  printf 'could not connect to app-server tcp: %s:%s%s\n' "$APP_SERVER_HOST" "$APP_SERVER_PORT" "$APP_SERVER_PATH"
  service_problems+=("start or fix app-server at $APP_SERVER_HOST:$APP_SERVER_PORT$APP_SERVER_PATH")
fi

detect_target_project() {
  [[ -d "$TARGET_WORKDIR" ]] || return 0
  cd "$TARGET_WORKDIR"

  print_section "target dependency probes"

  if [[ -f package.json ]]; then
    if [[ -f pnpm-lock.yaml ]]; then
      require_cmd pnpm
      add_setup_command "cd '$TARGET_WORKDIR' && pnpm install --frozen-lockfile"
    elif [[ -f yarn.lock ]]; then
      require_cmd yarn
      add_setup_command "cd '$TARGET_WORKDIR' && yarn install --frozen-lockfile"
    elif [[ -f package-lock.json || -f npm-shrinkwrap.json ]]; then
      require_cmd npm
      add_setup_command "cd '$TARGET_WORKDIR' && npm ci"
    else
      require_cmd npm
      add_setup_command "cd '$TARGET_WORKDIR' && npm install"
    fi
  fi

  if compgen -G "*.cabal" >/dev/null || [[ -f cabal.project ]]; then
    require_cmd cabal
    add_setup_command "cd '$TARGET_WORKDIR' && cabal build all"
  fi

  if [[ -f stack.yaml ]]; then
    require_cmd stack
    add_setup_command "cd '$TARGET_WORKDIR' && stack build --only-dependencies"
  fi

  if [[ -f Cargo.toml ]]; then
    require_cmd cargo
    add_setup_command "cd '$TARGET_WORKDIR' && cargo fetch"
  fi

  if [[ -f go.mod ]]; then
    require_cmd go
    add_setup_command "cd '$TARGET_WORKDIR' && go mod download"
  fi

  if [[ -f pyproject.toml ]]; then
    if [[ -f uv.lock ]]; then
      require_cmd uv
      add_setup_command "cd '$TARGET_WORKDIR' && uv sync"
    elif [[ -f poetry.lock ]]; then
      require_cmd poetry
      add_setup_command "cd '$TARGET_WORKDIR' && poetry install"
    else
      require_cmd python3
      add_setup_command "cd '$TARGET_WORKDIR' && python3 -m pip install -e ."
    fi
  elif [[ -f requirements.txt ]]; then
    require_cmd python3
    add_setup_command "cd '$TARGET_WORKDIR' && python3 -m pip install -r requirements.txt"
  fi

  if [[ -f flake.nix ]]; then
    require_cmd nix
    add_setup_command "cd '$TARGET_WORKDIR' && nix develop --command true"
  fi

  if [[ -f Makefile || -f makefile ]]; then
    require_cmd make
  fi
}

detect_target_project

print_section "suggested setup commands"
if [[ ${#setup_commands[@]} -eq 0 ]]; then
  printf 'no project dependency setup command detected\n'
else
  printf '%s\n' "${setup_commands[@]}"
fi

if [[ ${#missing_tools[@]} -gt 0 ]]; then
  print_section "missing tools"
  printf '%s\n' "${missing_tools[@]}"
fi

if [[ ${#service_problems[@]} -gt 0 ]]; then
  print_section "services to start or fix"
  printf '%s\n' "${service_problems[@]}"
fi

if [[ ${#state_problems[@]} -gt 0 ]]; then
  print_section "state or workdir problems"
  printf '%s\n' "${state_problems[@]}"
fi

print_section "agent report summary"
if [[ ${#missing_tools[@]} -eq 0 && ${#service_problems[@]} -eq 0 && ${#state_problems[@]} -eq 0 ]]; then
  printf 'ready: base tools, writable paths, and app-server TCP check passed\n'
else
  printf 'ready: no\n'
fi
printf 'missing_tools_count: %s\n' "${#missing_tools[@]}"
printf 'services_to_start_count: %s\n' "${#service_problems[@]}"
printf 'state_problem_count: %s\n' "${#state_problems[@]}"
printf 'suggested_setup_command_count: %s\n' "${#setup_commands[@]}"

if [[ "$install" == true ]]; then
  if [[ "$ALLOW_DEPENDENCY_INSTALL" != "true" ]]; then
    print_section "install refused"
    printf 'Set ALLOW_DEPENDENCY_INSTALL=true in the env file before rerunning with --install.\n' >&2
    exit 3
  fi
  print_section "running setup commands"
  for command_text in "${setup_commands[@]}"; do
    printf '+ %s\n' "$command_text"
    bash -lc "$command_text"
  done
else
  print_section "decision gate"
  printf 'Default mode did not install dependencies.\n'
  printf 'Review the suggested commands, install missing system tools if needed, then rerun with --install only if installation is allowed.\n'
fi
