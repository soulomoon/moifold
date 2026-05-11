### Goal

Move only `src/CodexWatcher/Cli/Command/Observe.hs` off the public `CodexWatcher.AppServerClient` compatibility facade by replacing that import with direct owner imports. This round is import-only: preserve every code body, behavior, parser, stdout/stderr/exit outcome, endpoint requirement, dry-run null interpreter fallback, and planner `turn/start` traffic covered by round 118.

Shared invariants remain governed by `orchestrator/project-contract.md`. This plan belongs to roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, item `round-119-observe-appserverclient-import-convergence`.

### Approach

Use a sequential single-file import migration. Do not create worker fan-out, do not add tests, and do not touch package descriptors, docs, fixtures, protocol/client/facade modules, runtime compatibility files, app code, or other remaining `CodexWatcher.AppServerClient` importers.

The exact current `CodexWatcher.AppServerClient` symbols used by `Observe.hs` are:

- `appServerInterpreterFromEndpoint`
- `defaultAppServerClientOptions`
- `AppServerInterpreter (..)`

Their direct owner imports for this round are:

- `CodexWatcher.Workflow.Agent.Codex.Transport (appServerInterpreterFromEndpoint, defaultAppServerClientOptions)` for the endpoint-backed interpreter builder and default client options.
- No additional direct import is required for `AppServerInterpreter (..)`, because `Observe.hs` already imports `CodexWatcher.ActionExecutor`, and `CodexWatcher.ActionExecutor` re-exports `AppServerInterpreter (..)`. Keep the dry-run constructor use unchanged as `AppServerInterpreter (\_ -> pure Null)`.

Do not import `CodexWatcher.Workflow.Agent.Codex.Client` for this file; `Observe.hs` does not use client parsing or failure symbols directly. Do not change `CodexWatcher.AppServerClient` itself; the facade must remain available and exposed.

### Steps

1. Open `src/CodexWatcher/Cli/Command/Observe.hs` and confirm the only facade import is `import CodexWatcher.AppServerClient`.
2. Replace that facade import with an explicit direct owner import:

   ```haskell
   import CodexWatcher.Workflow.Agent.Codex.Transport
     ( appServerInterpreterFromEndpoint
     , defaultAppServerClientOptions
     )
   ```

3. Preserve every non-import line in `Observe.hs`. In particular, do not edit `observeOnce`, `observeOnceExecutor`, `parseDaemonObservation`, observation specs, required flag handling, or formatting/output code.
4. Leave the `AppServerInterpreter (\_ -> pure Null)` expression exactly as-is, relying on the existing `CodexWatcher.ActionExecutor` import for that constructor.
5. Do not edit `CodexWatcher.ActionExecutor`, `CodexWatcher.AppServerClient`, `agent-workflow-codex` owner modules, `CodexWatcher.AppServerProtocol`, direct endpoint parsing, daemon workflow modules, tests, fixtures, docs, package descriptors, runtime compatibility files, app code, or any other importer.
6. Do not create `orchestrator/rounds/round-119/worker-plan.json`; this round has a single production file and no safe or useful worker split.

### Verification

Run the focused round-118 observe coverage gate:

```sh
printf 'ObserveCommandSpec.observeCommandTests\n:quit\n' | cabal repl watcher-core-test
```

Run the baseline checks:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

Run target import scans:

```sh
! rg -n 'import CodexWatcher\.AppServerClient' src/CodexWatcher/Cli/Command/Observe.hs
rg -n 'CodexWatcher\.Workflow\.Agent\.Codex\.Transport.*appServerInterpreterFromEndpoint|appServerInterpreterFromEndpoint|defaultAppServerClientOptions' src/CodexWatcher/Cli/Command/Observe.hs
```

Run forbidden diff guards. Only `src/CodexWatcher/Cli/Command/Observe.hs` and the round artifact `orchestrator/rounds/round-119/plan.md` should be new/changed for this round:

```sh
git diff --name-only -- . \
  ':!src/CodexWatcher/Cli/Command/Observe.hs' \
  ':!orchestrator/rounds/round-119/plan.md' \
  ':!orchestrator/rounds/round-119/selection.md' \
  ':!orchestrator/state.json'
```

That command must print no paths. Then verify forbidden production surfaces specifically:

```sh
git diff --name-only -- \
  src/CodexWatcher/AppServerClient.hs \
  src/CodexWatcher/ActionExecutor.hs \
  src/CodexWatcher/AppServerProtocol.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Interpreter.hs \
  src/CodexWatcher/Domain/PrReview/LaunchCli.hs \
  src/CodexWatcher/Domain/IssuePlanning/Loop.hs \
  src/CodexWatcher/AutomaticLoop/Runner.hs \
  src/CodexWatcher/Cli/Command/IssueFanout.hs \
  docs runtime fixtures app test

git diff --name-only -- '*.cabal' 'package.yaml' 'cabal.project*'
```

Both commands must print no paths. Verify the Observe diff is import-only and does not change code bodies:

```sh
git diff -- src/CodexWatcher/Cli/Command/Observe.hs
git diff -- src/CodexWatcher/Cli/Command/Observe.hs | rg -n '^[-+](?!import |$)' && false || true
```

Run no-worker and control-plane checks after implementation/review state is current:

```sh
test ! -e orchestrator/rounds/round-119/worker-plan.json

jq -e '
  .roadmap_id == "2026-05-11-00-highest-value-cleanup"
  and .roadmap_revision == "rev-001"
  and .controller_stage == "dispatch-rounds"
  and .active_round_id == "round-119"
  and (.active_rounds | length) == 1
  and .active_rounds[0].round_id == "round-119"
  and .active_rounds[0].stage == "plan"
  and .active_rounds[0].worker_mode == "none"
  and .active_rounds[0].merge_ready == false
  and (.active_rounds[0].roadmap_item_id == "round-119-observe-appserverclient-import-convergence")
' orchestrator/state.json

jq -e '
  (.review_records == null or (.review_records | type == "object"))
  and (.roadmap_update == null)
' orchestrator/state.json
```

If the controller has advanced the round to review by the time these checks run, update only the expected `.active_rounds[0].stage` predicate to the current lifecycle stage and keep all lineage, worker mode, merge readiness, and roadmap-update assertions intact.

### Worker Fan-Out

Worker fan-out is not used. The selected scope is a single-file import-only migration with no independent ownership boundaries, so `orchestrator/rounds/round-119/worker-plan.json` must not be created.
