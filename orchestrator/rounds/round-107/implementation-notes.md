### Changes Made
- `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`: replaced the public `CodexWatcher.AppServerClient` compatibility-facade import with the direct owner import `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`. No classifier logic, parsing, structured outcome handling, or issue-planning observations changed.

### Tests
- `test/Main.hs`: existing `watcher-core-test` coverage includes `prop_turnClassifierCompletionStates`, `prop_turnClassifierMapsDomainOutputs`, `prop_turnClassifierPrefersStructuredOutputs`, and `prop_turnClassifierBlocksMissingOutputs`, covering running/failed/completed turn states, missing output blocking, issue/subissue request parsing, planning graph parsing, invalid issue-creation payload classification, and structured blocked/incomplete/complete outcome classification. Focused selector discovery found these as plain `quickCheckResult` entries in the custom `watcher-core-test` main; no supported focused selector interface was discoverable, so the full test executable was used.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- Import scan: `rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs` produced no matches.
- Import scan: `rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.Agent\.Codex\.Client[[:space:]]+\(AppServerTurn\)' src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs` found the direct owner import.
- Descriptor/facade exposure check: `git diff -- moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal src/CodexWatcher/AppServerClient.hs` was empty.
- `test ! -e orchestrator/rounds/round-107/worker-plan.json`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.

### Notes
- Explicit non-goals preserved: no package descriptor changes, public facade exposure changes, facade deprecation/removal, docs/fixture/test edits, app-server protocol changes, endpoint/session behavior changes, timeout/fallback changes, failure-formatting changes, or migration of any other importer.
- The public `CodexWatcher.AppServerClient` compatibility facade remains available and unchanged.
- `orchestrator/state.json` was already modified before this implementation pass and was not edited.
