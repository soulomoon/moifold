### Changes Made
- `src/CodexWatcher/Turn/Classifier/Common.hs`: replaced the `CodexWatcher.AppServerClient` import with `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))` so the classifier imports `AppServerTurn` from its direct owner. No classifier logic, exports, status lists, structured-output parsing, or missing-output behavior changed.

### Tests
- `test/Main.hs`: inspected the existing classifier properties `prop_turnClassifierCompletionStates`, `prop_turnClassifierMapsDomainOutputs`, `prop_turnClassifierPrefersStructuredOutputs`, and `prop_turnClassifierBlocksMissingOutputs`; they are plain `quickCheckResult` entries in the single `watcher-core-test` executable. I did not find a supported focused selector or named test pattern for running only these properties, so I used the required baseline gate.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.

### Notes
- Import scan before editing showed `src/CodexWatcher/Turn/Classifier/Common.hs` used `CodexWatcher.AppServerClient` only for `AppServerTurn`, `appServerTurnStatus`, and `appServerTurnOutput`.
- Post-change facade scan passed: `rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' src/CodexWatcher/Turn/Classifier/Common.hs` produced no matches.
- Post-change direct-owner scan passed: `rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.Agent\.Codex\.Client[[:space:]]+\(AppServerTurn \(\.\.\)\)' src/CodexWatcher/Turn/Classifier/Common.hs` found `src/CodexWatcher/Turn/Classifier/Common.hs:19`.
- Descriptor and public facade exposure check passed: `git diff -- moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal src/CodexWatcher/AppServerClient.hs` was empty.
- Scope check for production/test/package/docs/example/script/fixture paths showed only the one source import move in `src/CodexWatcher/Turn/Classifier/Common.hs`.
- No `orchestrator/rounds/round-106/worker-plan.json` exists.
- Non-goals preserved: no package descriptor edits, no public facade exposure changes, no `src/CodexWatcher/AppServerClient.hs` change, no protocol/endpoint/session/timeout/fallback/failure-formatting behavior changes, no docs/fixtures/tests changes, and no other `CodexWatcher.AppServerClient` importer migration.
- Existing worktree note: `orchestrator/state.json` was already modified before this implementation pass and was left untouched.
