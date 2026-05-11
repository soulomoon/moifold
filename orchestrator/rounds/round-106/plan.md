### Goal

Move the single production source importer
`src/CodexWatcher/Turn/Classifier/Common.hs` from the public compatibility
facade `CodexWatcher.AppServerClient` to the direct owner
`CodexWatcher.Workflow.Agent.Codex.Client` for `AppServerTurn` and its record
fields, while preserving existing turn-completion and structured-output
classification behavior.

This round must not change package descriptors, public facade exposure, docs,
fixtures, app-server protocol behavior, endpoint/session handling, timeout or
fallback behavior, failure formatting, or any other `CodexWatcher.AppServerClient`
importer.

### Approach

Keep the implementation deliberately mechanical and source-local. The current
module uses the facade only for `AppServerTurn` plus the
`appServerTurnStatus` and `appServerTurnOutput` fields reached through record
dot syntax. Replace the facade import with an explicit direct-owner import:

```haskell
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))
```

Do not rewrite classifier logic, exported names, status lists, structured
outcome parsing, missing-output handling, or downstream domain classifiers.
Preserve `CodexWatcher.AppServerClient` as an available public compatibility
module and leave Cabal exposed-module entries untouched.

Worker fan-out is not justified: the implementation is one import-line change
plus verification, and there are no separate non-overlapping source ownership
boundaries.

### Steps

1. Re-check coordination inputs from this worktree before editing:
   `orchestrator/state.json`,
   `orchestrator/rounds/round-106/selection.md`,
   `orchestrator/project-contract.md`, and
   `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`.
2. Inspect the current import and use sites in
   `src/CodexWatcher/Turn/Classifier/Common.hs`:

   ```sh
   sed -n '1,140p' src/CodexWatcher/Turn/Classifier/Common.hs
   rg -n 'CodexWatcher\.AppServerClient|AppServerTurn|appServerTurn(Status|Output)' \
     src/CodexWatcher/Turn/Classifier/Common.hs
   ```

3. Replace only the `CodexWatcher.AppServerClient` import in
   `src/CodexWatcher/Turn/Classifier/Common.hs` with the direct owner import
   for `AppServerTurn (..)`.
4. Do not edit any package descriptor, public facade module, docs, fixtures,
   test support, or any other importer. In particular, do not change
   `src/CodexWatcher/AppServerClient.hs` or `moifold.cabal`.
5. Discover whether focused classifier tests are directly runnable from
   existing names or patterns by inspecting the current test definitions around
   `prop_turnClassifierCompletionStates`,
   `prop_turnClassifierMapsDomainOutputs`,
   `prop_turnClassifierPrefersStructuredOutputs`, and
   `prop_turnClassifierBlocksMissingOutputs`. If there is no supported focused
   test selector for these QuickCheck properties, record that and use the
   baseline `watcher-core-test` gate.
6. Record implementation notes with the exact changed path, import scan
   results, focused-test discovery result, full validation commands, and an
   explicit statement that package descriptors and public facade exposure were
   not changed.

### Verification

Run these checks after the import move:

```sh
rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' \
  src/CodexWatcher/Turn/Classifier/Common.hs
```

Expected result: no matches.

```sh
rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.Agent\.Codex\.Client[[:space:]]+\(AppServerTurn \(\.\.\)\)' \
  src/CodexWatcher/Turn/Classifier/Common.hs
```

Expected result: exactly the direct-owner import in
`src/CodexWatcher/Turn/Classifier/Common.hs`.

```sh
git diff -- src/CodexWatcher/Turn/Classifier/Common.hs
git diff -- moifold.cabal cabal.project \
  agent-workflow-core/agent-workflow-core.cabal \
  agent-workflow-codex/agent-workflow-codex.cabal \
  agent-workflow-github/agent-workflow-github.cabal \
  src/CodexWatcher/AppServerClient.hs
```

Expected result: the source diff contains only the import move in
`src/CodexWatcher/Turn/Classifier/Common.hs`; the descriptor/facade diff is
empty.

Run focused classifier tests if the test suite exposes a supported selector or
pattern for the classifier properties discovered in step 5. If no focused
selector is discoverable, run the baseline:

```sh
cabal test watcher-core-test
```

Then run the required package and diff hygiene gates sequentially:

```sh
cabal build all
git diff --check
git diff --cached --check
```

Also confirm no unintended scope drift:

```sh
git diff --name-status
git diff -- src app test docs examples scripts fixtures moifold.cabal cabal.project \
  agent-workflow-core agent-workflow-codex agent-workflow-github
test ! -e orchestrator/rounds/round-106/worker-plan.json
```

The production/test/package diff should be limited to
`src/CodexWatcher/Turn/Classifier/Common.hs`, and no `worker-plan.json` should
exist for this round.
