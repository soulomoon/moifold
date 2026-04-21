# codex-watcher-hs

Haskell-first rewrite of the Codex watcher system.

This repository starts with the correctness core instead of runtime glue:

- Type-level watcher domains and lifecycle phases.
- GADT states that prevent impossible state combinations.
- Typed effects, including mutation permissions.
- Pure transitions from typed state plus event to next typed state and effect plan.
- JSON event-log replay for Node watcher `events.jsonl` files.
- QuickCheck properties for global invariants.

The existing Node watcher remains the runtime reference while this model matures.

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

Replay a Node watcher event log:

```bash
cabal run codex-watcher-hs -- replay-events /path/to/events.jsonl
```

Run the read-only Haskell healthcheck over existing Node watcher state:

```bash
bin=$(cabal list-bin codex-watcher-hs)
"$bin" healthcheck --state-root /workspace/artifacts
```

The command emits JSON and checks command availability, `gh auth`, watcher state files, workdir/git health, PR review event-log replay, duplicate ownership, and planner `maxParallel` invariants. It intentionally does not mutate GitHub, app-server threads, or local checkouts.

## Design Rule

The type-level model owns lifecycle correctness. Runtime policy and external IO stay outside the core until the model is stable.

Illegal lifecycle transitions should fail at compile time where practical and fail property tests otherwise.
