# moifold

moifold is a Haskell-first watcher runtime for turning GitHub issues into coordinated Codex work.

It gives a repository an operator-grade automation loop: plan a scoped issue tree, fan out ready implementation work, keep child watchers within their issue scope, watch PR review feedback, and resume safely from durable state when a daemon or app-server turn fails.

## Why teams use moifold

- Scoped planning: limit a planning watcher to one root issue or a selected issue set, so Codex plans only the work that matters now instead of roaming the whole repository.
- Docker-first setup: build and run watchers inside one persistent container, so the Haskell toolchain, `gh`, app-server reachability, target checkout paths, and watcher state all live in one repeatable operating environment.
- Automatic fanout: turn planner decisions into issue implementer child watchers, with `maxParallel` limits so the system can move several independent issues without flooding the repo.
- Durable execution: every watcher is driven by an append-only `events.jsonl` log, so state can be replayed, inspected, repaired, and resumed.
- Typed lifecycle safety: Haskell GADTs, typed domains, typed effects, and QuickCheck properties make illegal watcher transitions hard to express and easier to catch before runtime.
- Controlled mutation: dry-run is the default; execute mode requires an explicit flag and uses leases/pid files to avoid two daemons owning the same state directory.
- GitHub-native workflow: watchers use `gh`, git, PRs, issues, review threads, and Codex app-server turns instead of inventing a separate task system.
- Agent-run runbooks: setup, preflight, start, resume, restart, healthcheck, and validation flows are written so Codex or another agent can execute them directly, with a human operator only reviewing decisions and outputs when needed.

## What moifold automates

### Docker-first setup

moifold provides a persistent watcher container workflow for the runtime and the target project. The setup runbook builds the Docker image, starts the long-lived container, installs/selects the Haskell toolchain inside it, builds the watcher binary, verifies GitHub CLI auth, checks app-server reachability, and probes the target project's dependencies from the same environment that will run the daemons.

The benefit is repeatability: operators do not have to debug one set of paths, credentials, tools, and network assumptions on the host and another set inside the watcher. The same container is used for setup, dry runs, execute loops, restarts, and resume.

### Issue planning

moifold can run a repository planner or a scoped planner for a specific issue tree. The planner reads the current issue snapshot, proposes sub-issues when decomposition is needed, returns dependency data, and produces a canonical planning graph.

The benefit is practical scope control: a team can say "plan this root issue and its descendants" and get a constrained automation loop instead of a broad repo scan.

### Issue implementation

For ready issues, moifold creates or reuses child implementer watcher state, prepares issue workdirs and branches, starts Codex implementation turns, updates PR bodies from issue plans, and hands work off to PR review.

The benefit is parallel delivery with guardrails: independent issues can move at once, while each implementer stays tied to a concrete issue, branch, PR, and state directory.

### PR review and merge readiness

moifold can watch a PR, classify review feedback, start fix turns, track review-clean states, and drive merge readiness through the same replayable event model.

The benefit is less manual babysitting after implementation: review feedback becomes another resumable watcher lifecycle instead of a one-off prompt.

### Operations and recovery

moifold includes healthchecks, dry-run commands, restart scripts, daemon leases, pid guards, event-log repair helpers, and render-only service generation.

The benefit is confidence under failure: operators can inspect what will happen, recover from blocked turns, and resume old watcher state without throwing away history.

### Agent-operable runbooks

moifold's runbooks are designed as executable handoff instructions for Codex or another coding agent. They describe the environment contract, Docker container setup, preflight checks, generated dry-run/restart scripts, and resume paths in the order an agent should run them.

The benefit is lower operating burden: instead of teaching every human operator a long manual procedure, a team can ask Codex to follow the runbook, report preflight results, start the correct watcher, and preserve the same operational pattern across projects.

## Correctness model

moifold starts with the correctness core instead of runtime glue:

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

## Current scope

moifold currently models the lifecycle shared by:

- repository or scoped issue planning
- single issue implementation
- PR review fixing and merging

The core explicitly tracks phases such as plan mode, implementation, review checking, review fixing, merging, blocked, complete, and stopped.

## Start here

Ask Codex or another coding agent to follow the [Watcher Agent Runbook](docs/watcher-agent-runbook/README.md). The root README explains why moifold exists and where to go next; the runbook owns the exact command sequences that the agent should execute.

- Runtime setup: [docs/watcher-agent-runbook/moifold-setup/README.md](docs/watcher-agent-runbook/moifold-setup/README.md)
- Target project watcher setup: [docs/watcher-agent-runbook/project-watch/README.md](docs/watcher-agent-runbook/project-watch/README.md)
- Maintainer validation: [docs/watcher-agent-runbook/runbook-validation.md](docs/watcher-agent-runbook/runbook-validation.md)
- Event format reference: [docs/event-log-schema.md](docs/event-log-schema.md)

The normal agent-run path is:

1. Start the persistent Docker watcher container and build `moifold` inside it.
2. Create a project env file from `docs/watcher-agent-runbook/templates/watcher.env.example`.
3. Run project setup checks and GitHub/app-server preflight from inside the container.
4. Initialize the watcher state for issue planning, a specific issue, or a PR review watcher.
5. Run the generated dry-run command.
6. Report the dry-run result for review, then start the generated execute loop when it is acceptable.

## Operator entry points

The handoff-ready guide lives in the [Watcher Agent Runbook](docs/watcher-agent-runbook/README.md). It is the main entry point for Codex, another agent, or a human operator to set up, validate, start, and resume watcher daemons.

The runbook covers three practical workflows:

- `moifold` runtime setup: build the Docker setup image, start one persistent watcher container, run Haskell toolchain setup inside that container, `cabal update`, `cabal build all`, `WATCHER_BIN` resolution, mock app-server TCP validation, and real Codex app-server protocol checks from inside the container.
- Target project watcher operation: project env contract using container paths, check-only dependency probing inside the persistent watcher container, GitHub/app-server preflight, state initialization, generated `dry-run-command.sh` and `restart-command.sh`, dry runs, execute loops, and resume from existing state.
- Maintainer validation: after changing setup scripts, CLI wiring, watcher setup code, or the runbook itself, run the persistent Docker gate and stale-reference scan from `docs/watcher-agent-runbook/runbook-validation.md`.

The companion helpers live under `scripts/watcher-init/`, including Docker setup smoke, app-server checks, check-only project setup probing, and state initialization scripts for issue planning, issue implementation, and PR review watchers.

Automatic turn starts now include an output schema and prompts that ask for structured JSON. Classification first accepts outputs with an `outcome`, `status`, or `result` field such as `complete`, `incomplete`, `blocked`, `clean`, or `problems`; older free-text outputs still use the compatibility heuristics.

## Developer commands

For local development outside the operator runbook:

```bash
cabal test all
cabal run moifold -- replay-events /path/to/events.jsonl
bin=$(cabal list-bin moifold)
"$bin" healthcheck --state-root /workspace/artifacts
```

Use CLI `--help` output for command details. Use the runbook for real watcher operation.

## Design Rule

The type-level model owns lifecycle correctness. Runtime policy and external IO stay behind `CodexWatcher.Runtime` until they are driven by typed effects.

Illegal lifecycle transitions should fail at compile time where practical and fail property tests otherwise.
