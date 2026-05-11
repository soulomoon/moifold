### Goal

Move only `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` off the public `CodexWatcher.AppServerClient` compatibility facade by replacing that import with the direct owner import for the one symbol it currently supplies. This round is import-only: preserve every code body, behavior, planner-thread initialization path, request id progression, dry-run synthetic planner thread behavior, planned app-server request/result behavior, active-turn read behavior, planning systemError retry/blocking behavior, and snapshot command failure formatting.

Shared invariants remain governed by `orchestrator/project-contract.md`. This plan belongs to roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, item `round-120-issue-planning-loop-appserverclient-import-convergence`.

### Approach

Use a sequential single-file import migration. Do not create worker fan-out, do not add tests, and do not touch package descriptors, docs, fixtures, protocol/client/facade modules, runtime compatibility files, app code, test code, direct-owner modules, or other remaining `CodexWatcher.AppServerClient` importers.

The exact current `CodexWatcher.AppServerClient` symbol used by `IssuePlanning/Loop.hs` is:

- `AppServerTurn`, used only by `planningSystemErrorObservation`'s type signature.

The direct owner import for this round is:

- `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.

Do not import `CodexWatcher.Workflow.Agent.Codex.Transport`; `IssuePlanning/Loop.hs` already builds planner app-server requests and parses responses through the existing qualified `CodexWatcher.Workflow.Agent.Codex` import. Do not change `CodexWatcher.AppServerClient` itself; the facade must remain available and exposed.

### Steps

1. Open `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` and confirm the only facade import is `import CodexWatcher.AppServerClient`.
2. Replace that facade import with the explicit direct owner import:

   ```haskell
   import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)
   ```

3. Preserve every non-import line in `IssuePlanning/Loop.hs`. In particular, do not edit `runPlanningReady`, `startPlannerTurn`, `runPlanningActive`, `runPlanningWaiting`, `ensurePlannerThread`, `startPlannerThread`, snapshot handling, `planningSystemErrorObservation`, or any command/runtime/request parsing logic.
4. Preserve import formatting outside the one import replacement. Keep the existing qualified `CodexWatcher.Workflow.Agent.Codex` import unchanged.
5. Do not edit `CodexWatcher.AppServerClient`, `CodexWatcher.AppServerProtocol`, `CodexWatcher.Workflow.Agent.Codex.Client`, `CodexWatcher.Workflow.Agent.Codex.Transport`, `CodexWatcher.Workflow.Agent.Codex.Interpreter`, `CodexWatcher.Domain.IssuePlanning.TurnClassifier`, package descriptors, docs, fixtures, runtime compatibility files, tests, app code, or any other importer.
6. Do not create `orchestrator/rounds/round-120/worker-plan.json`; this round has a single production file and no safe or useful worker split.

### Verification

Run the focused planning classifier and systemError retry/blocking gate:

```sh
printf 'prop_turnClassifierMapsDomainOutputs\nprop_turnClassifierPrefersStructuredOutputs\nprop_turnClassifierBlocksMissingOutputs\nautomaticPlanningSystemErrorRetriesWatcher\nautomaticPlanningSystemErrorBlocksAfterRetryLimit\n:quit\n' | cabal repl watcher-core-test
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
! rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' src/CodexWatcher/Domain/IssuePlanning/Loop.hs
rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.Agent\.Codex\.Client[[:space:]]+\(AppServerTurn\)' src/CodexWatcher/Domain/IssuePlanning/Loop.hs
```

Run forbidden diff guards. Only `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` and the round artifact `orchestrator/rounds/round-120/plan.md` should be new/changed for this round, aside from pre-existing controller-owned `selection.md` and `orchestrator/state.json`:

```sh
git diff --name-only -- . \
  ':!src/CodexWatcher/Domain/IssuePlanning/Loop.hs' \
  ':!orchestrator/rounds/round-120/plan.md' \
  ':!orchestrator/rounds/round-120/selection.md' \
  ':!orchestrator/state.json'
```

That command must print no paths. Then verify forbidden production surfaces specifically:

```sh
git diff --name-only -- \
  src/CodexWatcher/AppServerClient.hs \
  src/CodexWatcher/AppServerProtocol.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Interpreter.hs \
  src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs \
  src/CodexWatcher/Domain/PrReview/LaunchCli.hs \
  src/CodexWatcher/AutomaticLoop/Runner.hs \
  src/CodexWatcher/Cli/Command/IssueFanout.hs \
  docs runtime fixtures app test

git diff --name-only -- '*.cabal' 'package.yaml' 'cabal.project*'
```

Both commands must print no paths. Verify the target diff is import-only and does not change code bodies:

```sh
git diff -- src/CodexWatcher/Domain/IssuePlanning/Loop.hs
git diff -- src/CodexWatcher/Domain/IssuePlanning/Loop.hs | rg -n '^[-+](?!import |$)' && false || true
```

Run no-worker and control-plane checks after implementation/review state is current:

```sh
test ! -e orchestrator/rounds/round-120/worker-plan.json

jq -e '
  .roadmap_id == "2026-05-11-00-highest-value-cleanup"
  and .roadmap_revision == "rev-001"
  and .controller_stage == "dispatch-rounds"
  and .active_round_id == "round-120"
  and (.active_rounds | length) == 1
  and .active_rounds[0].round_id == "round-120"
  and .active_rounds[0].stage == "plan"
  and .active_rounds[0].worker_mode == "none"
  and .active_rounds[0].merge_ready == false
  and (.active_rounds[0].roadmap_item_id == "round-120-issue-planning-loop-appserverclient-import-convergence")
' orchestrator/state.json

jq -e '
  (.review_records == null or (.review_records | type == "object"))
  and (.roadmap_update == null)
' orchestrator/state.json
```

If the controller has advanced the round to review or implementation by the time these checks run, adjust only the expected `.active_rounds[0].stage` predicate to the current lifecycle stage and keep all lineage, worker mode, merge readiness, and roadmap-update assertions intact.

### Worker Fan-Out

Worker fan-out is not used. The selected scope is a single-file import-only migration with no independent ownership boundaries, so `orchestrator/rounds/round-120/worker-plan.json` must not be created.
