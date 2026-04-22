# codex-watcher-hs

Haskell-first rewrite of the Codex watcher system.

This repository starts with the correctness core instead of runtime glue:

- Type-level watcher domains and lifecycle phases.
- GADT states that prevent impossible state combinations.
- Typed effects, including mutation permissions.
- Pure transitions from typed state plus event to next typed state and effect plan.
- JSON event-log replay for watcher `events.jsonl` files.
- A small runtime boundary for `gh`, `git`, process checks, and JSON file IO.
- Pure JSON-RPC request builders for the Codex app-server thread/turn protocol.
- A pure effect interpreter that compiles typed effects into ordered runtime/app-server actions.
- QuickCheck properties for global invariants.

The Haskell runtime is the primary implementation. Legacy Node snapshot support is retained only for golden compatibility checks.

## Current Scope

The first milestone models the lifecycle shared by:

- repository issue planning
- single issue implementation
- PR review fixing and merging

The core explicitly tracks phases such as triage, plan mode, implementation, review checking, review fixing, merging, blocked, complete, and stopped.

## Build

```bash
cabal test all
```

Replay a watcher event log:

```bash
cabal run codex-watcher-hs -- replay-events /path/to/events.jsonl
```

Run the read-only Haskell healthcheck over watcher state:

```bash
bin=$(cabal list-bin codex-watcher-hs)
"$bin" healthcheck --state-root /workspace/artifacts
```

The command emits JSON and checks command availability, `gh auth`, watcher state files, workdir/git health, PR review event-log replay, duplicate ownership, and planner `maxParallel` invariants. It intentionally does not mutate GitHub, app-server threads, or local checkouts. Add `--app-server-host <host> --app-server-port <port>` to inspect configured app-server threads with read-only `thread/read` calls.

Dry-run one typed watcher observation against an event log:

```bash
bin=$(cabal list-bin codex-watcher-hs)
"$bin" observe-once \
  --events /path/to/events.jsonl \
  --state-dir /path/to/state \
  --repo owner/name \
  --domain issue-planning \
  --observation turn-started \
  --thread-id planner-thread \
  --turn-id turn-next
```

The command replays the log, applies the observation through the typed watcher policy, reports the canonical event, compatibility writes, and planned actions, and defaults to `DryRunActions`. Use `--execute --app-server-host <host> --app-server-port <port>` only after explicitly claiming the watcher state as Haskell-owned.

Run one automatic typed daemon iteration:

```bash
bin=$(cabal list-bin codex-watcher-hs)
"$bin" run-issue-implement \
  --events /path/to/events.jsonl \
  --state-dir /path/to/state \
  --repo owner/name \
  --workdir /path/to/checkout \
  --app-server-host 127.0.0.1 \
  --app-server-port 3000
```

The automatic commands are `run-pr-review`, `run-issue-implement`, and `run-issue-planning`. They replay the event log, fetch the next observation from `gh`, `git`, and/or app-server `thread/read`, classify turn output into typed watcher observations, and report the next canonical event and planned actions. They default to a dry run; add `--execute` to append the event, write Haskell-compatible state files, and run the compiled effects. Execute mode requires `runtime-owner.json` to contain `{"owner":"haskell"}`. Use `--loop --iterations N` for bounded daemon polling, or `--loop` for continuous polling. Loop mode writes the conventional watcher pid file under `--state-dir` unless `--pid-file` is supplied, and refuses to start over a running pid. `run-issue-planning` also requires `--planner-thread-id`. Add `--implementers-root <path>` to `run-issue-planning` to fan out issue implementer child state immediately after a canonical planning-completed event; in execute mode this uses the configured app-server endpoint to create real child threads. Add `--start-children` to print child daemon commands in dry-run mode or start the new child `run-issue-implement --loop --execute` processes after state is written in execute mode.

Claim Haskell execute ownership for a watcher state directory:

```bash
"$bin" claim-runtime-owner --state-dir /path/to/state
```

The marker is surfaced by healthcheck and prevents accidental writes to state that is not Haskell-owned. Use `stop-daemon --pid-file <path>` or `stop-daemon --state-dir <path> --domain <domain>` to send `TERM` to a running Haskell watcher during maintenance.

Use `render-service` with the same watcher loop flags to print a systemd unit and matching logrotate snippet. The command is render-only; it does not install or enable host services.

Prepare issue implementer child state from a planner selection:

```bash
"$bin" issue-fanout \
  --repo owner/name \
  --implementers-root /workspace/artifacts/issue-implementers \
  --workdir-root /workspace/artifacts \
  --max-parallel 3 \
  --open-issues 101,102,103 \
  --active-issues 102
```

Without `--open-issues`, fanout discovers open issues with `gh issue list`. Without `--active-issues`, it scans existing child implementer `config.json` files under `--implementers-root`. Without `--execute`, it prints the selected child implementers. With `--execute`, it creates each child state directory, writes `config.json`, initializes `events.jsonl` with `issue_implement_initialized`, writes compatibility state, and marks the child state as Haskell-owned. Existing child config/event files are never overwritten. Add `--app-server-host <host> --app-server-port <port>` during execute mode to create real app-server threads and persist their returned thread ids; otherwise deterministic thread ids are used for offline rehearsal. Add `--start-children` to print or start child daemon commands; child stdout and stderr are written to `daemon.log` and `daemon.err.log` under each child state directory when started.

The runtime event format is documented in `docs/event-log-schema.md`.

Automatic turn starts now include an output schema and prompts that ask for structured JSON. Classification first accepts outputs with an `outcome`, `status`, or `result` field such as `complete`, `incomplete`, `blocked`, `already_fixed`, `needs_implementation`, `clean`, or `problems`; older free-text outputs still use the compatibility heuristics.

## Design Rule

The type-level model owns lifecycle correctness. Runtime policy and external IO stay behind `CodexWatcher.Runtime` until they are driven by typed effects.

Illegal lifecycle transitions should fail at compile time where practical and fail property tests otherwise.
