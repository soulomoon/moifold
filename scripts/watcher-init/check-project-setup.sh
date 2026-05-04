#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: check-project-setup.sh /path/to/watcher.env [--install]

Checks watcher prerequisites and target-project dependency entrypoints.
Default mode reports missing tools and suggested install/setup commands only.
Use --install to run all detected setup commands.
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"
load_watcher_env "$env_file"

: "${WATCHER_REPO:?}"
: "${REPO_FULL_NAME:?}"
: "${TARGET_WORKDIR:?}"
: "${STATE_ROOT:=/workspace/artifacts}"
: "${APP_SERVER_HOST:?}"
: "${APP_SERVER_PORT:?}"
: "${APP_SERVER_PATH:=/}"

missing_tools=()
setup_command_labels=()
setup_command_kinds=()
setup_command_dirs=()
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

shell_quote() {
  printf '%q' "$1"
}

add_setup_command() {
  local label="$1"
  local kind="$2"
  local dir="$3"
  local existing
  for existing in "${setup_command_labels[@]}"; do
    [[ "$existing" == "$label" ]] && return 0
  done
  setup_command_labels+=("$label")
  setup_command_kinds+=("$kind")
  setup_command_dirs+=("$dir")
}

setup_command_text() {
  local kind="$1"
  case "$kind" in
    pnpm-install) printf 'pnpm install --frozen-lockfile' ;;
    yarn-install) printf 'yarn install --frozen-lockfile' ;;
    npm-ci) printf 'npm ci' ;;
    npm-install) printf 'npm install' ;;
    cabal-build) printf 'cabal build all' ;;
    stack-deps) printf 'stack build --only-dependencies' ;;
    cargo-fetch) printf 'cargo fetch' ;;
    go-download) printf 'go mod download' ;;
    uv-sync) printf 'uv sync' ;;
    poetry-install) printf 'poetry install' ;;
    python-editable) printf 'python3 -m pip install -e .' ;;
    python-requirements) printf 'python3 -m pip install -r requirements.txt' ;;
    nix-develop) printf 'nix develop --command true' ;;
    *)
      printf 'unknown setup command kind: %s\n' "$kind" >&2
      exit 2
      ;;
  esac
}

add_project_setup_command() {
  local dir="$1"
  local kind="$2"
  add_setup_command "cd $(shell_quote "$dir") && $(setup_command_text "$kind")" "$kind" "$dir"
}

add_ghcup_ghc_setup_command() {
  local version="$1"
  add_setup_command "ghcup install ghc $(shell_quote "$version")" "ghcup-ghc" "$version"
}

run_setup_command() {
  local kind="$1"
  local dir="$2"
  case "$kind" in
    ghcup-ghc)
      ghcup install ghc "$dir"
      ;;
    pnpm-install)
      (cd "$dir" && pnpm install --frozen-lockfile)
      ;;
    yarn-install)
      (cd "$dir" && yarn install --frozen-lockfile)
      ;;
    npm-ci)
      (cd "$dir" && npm ci)
      ;;
    npm-install)
      (cd "$dir" && npm install)
      ;;
    cabal-build)
      (cd "$dir" && cabal build all)
      ;;
    stack-deps)
      (cd "$dir" && stack build --only-dependencies)
      ;;
    cargo-fetch)
      (cd "$dir" && cargo fetch)
      ;;
    go-download)
      (cd "$dir" && go mod download)
      ;;
    uv-sync)
      (cd "$dir" && uv sync)
      ;;
    poetry-install)
      (cd "$dir" && poetry install)
      ;;
    python-editable)
      (cd "$dir" && python3 -m pip install -e .)
      ;;
    python-requirements)
      (cd "$dir" && python3 -m pip install -r requirements.txt)
      ;;
    nix-develop)
      (cd "$dir" && nix develop --command true)
      ;;
    *)
      printf 'unknown setup command kind: %s\n' "$kind" >&2
      exit 2
      ;;
  esac
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
require_cmd python3

print_section "haskell toolchain"
if have_cmd ghcup; then
  printf 'ok ghcup: %s\n' "$(command -v ghcup)"
else
  printf 'missing ghcup: complete moifold setup before project watcher setup\n'
fi

if have_cmd ghc; then
  ghc --numeric-version | sed 's/^/ghc version: /'
  case "$(command -v ghc)" in
    *ghcup*) printf 'ok ghc managed by ghcup: %s\n' "$(command -v ghc)" ;;
    *) printf 'warning: ghc is not on a ghcup path: %s\n' "$(command -v ghc)" ;;
  esac
else
  printf 'missing ghc: install through ghcup during moifold setup\n'
fi

if have_cmd cabal; then
  cabal --numeric-version | sed 's/^/cabal version: /'
  case "$(command -v cabal)" in
    *ghcup*) printf 'ok cabal managed by ghcup: %s\n' "$(command -v cabal)" ;;
    *) printf 'warning: cabal is not on a ghcup path: %s\n' "$(command -v cabal)" ;;
  esac
else
  printf 'missing cabal: install through ghcup during moifold setup\n'
fi

print_section "required services"
printf 'app-server: %s:%s%s\n' "$APP_SERVER_HOST" "$APP_SERVER_PORT" "$APP_SERVER_PATH"
printf 'required protocol: Codex app-server thread/read, thread/start, turn/start, structured turn outputs\n'

print_section "watcher repo"
if [[ ! -d "$WATCHER_REPO" ]]; then
  printf 'missing watcher repo: %s\n' "$WATCHER_REPO"
else
  git -C "$WATCHER_REPO" status --short || true
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
if "$script_dir/check-app-server.sh" "$env_file"; then
  printf 'ok app-server check\n'
else
  printf 'app-server check failed\n'
  service_problems+=("start or fix app-server at $APP_SERVER_HOST:$APP_SERVER_PORT$APP_SERVER_PATH")
fi

detect_cabal_declared_compiler() {
  [[ -f cabal.project ]] || return 0

  local compiler
  compiler="$(
    awk '
      /^[[:space:]]*with-compiler[[:space:]]*:/ {
        sub(/^[^:]*:[[:space:]]*/, "", $0)
        sub(/[[:space:]]*(--|#).*$/, "", $0)
        print $1
      }
    ' cabal.project | tail -n 1
  )"

  [[ -n "$compiler" ]] || return 0

  if [[ "$compiler" == ghc-[0-9]* ]]; then
    local version="${compiler#ghc-}"
    if have_cmd "$compiler"; then
      printf 'ok target compiler: %s -> %s\n' "$compiler" "$(command -v "$compiler")"
    else
      printf 'missing target compiler: %s declared by cabal.project with-compiler\n' "$compiler"
      missing_tools+=("$compiler")
      if have_cmd ghcup; then
        add_ghcup_ghc_setup_command "$version"
      fi
    fi
  elif [[ -x "$compiler" ]]; then
    printf 'ok target compiler: %s\n' "$compiler"
  elif have_cmd "$compiler"; then
    printf 'ok target compiler: %s -> %s\n' "$compiler" "$(command -v "$compiler")"
  else
    printf 'missing target compiler: %s declared by cabal.project with-compiler\n' "$compiler"
    missing_tools+=("$compiler")
  fi
}

detect_target_project() {
  [[ -d "$TARGET_WORKDIR" ]] || return 0
  cd "$TARGET_WORKDIR"

  print_section "target dependency probes"

  if [[ -f package.json ]]; then
    if [[ -f pnpm-lock.yaml ]]; then
      require_cmd pnpm
      add_project_setup_command "$TARGET_WORKDIR" pnpm-install
    elif [[ -f yarn.lock ]]; then
      require_cmd yarn
      add_project_setup_command "$TARGET_WORKDIR" yarn-install
    elif [[ -f package-lock.json || -f npm-shrinkwrap.json ]]; then
      require_cmd npm
      add_project_setup_command "$TARGET_WORKDIR" npm-ci
    else
      require_cmd npm
      add_project_setup_command "$TARGET_WORKDIR" npm-install
    fi
  fi

  if compgen -G "*.cabal" >/dev/null || [[ -f cabal.project ]]; then
    require_cmd cabal
    detect_cabal_declared_compiler
    add_project_setup_command "$TARGET_WORKDIR" cabal-build
  fi

  if [[ -f stack.yaml ]]; then
    require_cmd stack
    add_project_setup_command "$TARGET_WORKDIR" stack-deps
  fi

  if [[ -f Cargo.toml ]]; then
    require_cmd cargo
    add_project_setup_command "$TARGET_WORKDIR" cargo-fetch
  fi

  if [[ -f go.mod ]]; then
    require_cmd go
    add_project_setup_command "$TARGET_WORKDIR" go-download
  fi

  if [[ -f pyproject.toml ]]; then
    if [[ -f uv.lock ]]; then
      require_cmd uv
      add_project_setup_command "$TARGET_WORKDIR" uv-sync
    elif [[ -f poetry.lock ]]; then
      require_cmd poetry
      add_project_setup_command "$TARGET_WORKDIR" poetry-install
    else
      require_cmd python3
      add_project_setup_command "$TARGET_WORKDIR" python-editable
    fi
  elif [[ -f requirements.txt ]]; then
    require_cmd python3
    add_project_setup_command "$TARGET_WORKDIR" python-requirements
  fi

  if [[ -f flake.nix ]]; then
    require_cmd nix
    add_project_setup_command "$TARGET_WORKDIR" nix-develop
  fi

  if [[ -f Makefile || -f makefile ]]; then
    require_cmd make
  fi
}

detect_target_project

print_section "suggested setup commands"
if [[ ${#setup_command_labels[@]} -eq 0 ]]; then
  printf 'no project dependency setup command detected\n'
else
  printf '%s\n' "${setup_command_labels[@]}"
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
  printf 'ready: base tools, writable paths, and app-server check passed\n'
else
  printf 'ready: no\n'
fi
printf 'missing_tools_count: %s\n' "${#missing_tools[@]}"
printf 'services_to_start_count: %s\n' "${#service_problems[@]}"
printf 'state_problem_count: %s\n' "${#state_problems[@]}"
printf 'suggested_setup_command_count: %s\n' "${#setup_command_labels[@]}"

if [[ "$install" == true ]]; then
  print_section "running setup commands"
  for index in "${!setup_command_labels[@]}"; do
    printf '+ %s\n' "${setup_command_labels[$index]}"
    run_setup_command "${setup_command_kinds[$index]}" "${setup_command_dirs[$index]}"
  done
else
  print_section "decision gate"
  printf 'Default mode did not install dependencies.\n'
  printf 'Rerun with --install to install missing system tools and run detected setup commands.\n'
fi
