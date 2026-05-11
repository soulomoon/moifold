### Goal

Move `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs` off the public
`CodexWatcher.AppServerClient` compatibility facade and onto the direct owner
`CodexWatcher.Workflow.Agent.Codex.Client` for `AppServerTurn`, preserving all
issue-planning turn classification behavior.

This round is only the selected source import convergence item for roadmap
`2026-05-11-00-highest-value-cleanup` `rev-001`, milestone
`milestone-003-import-convergence-package-boundaries`, direction
`direction-010-appserverclient-import-convergence`. It does not approve or
perform package descriptor changes, public facade exposure changes,
deprecation, facade removal, docs/fixture/test changes, app-server protocol
changes, endpoint/session behavior changes, timeout/fallback changes,
failure-formatting changes, or migration of any other importer.

### Approach

Use the round-105 readiness evidence and round-106 implementation/review
pattern as the precedent: this module is a narrow turn-classifier source
candidate because it uses the facade only for `AppServerTurn`. Keep the edit to
the import section of `TurnClassifier.hs`, replacing the open facade import
with an explicit direct-owner import:

```haskell
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)
```

No classifier logic, exports, constructors, JSON parsing, structured outcome
handling, missing-output behavior, issue/subissue request parsing, planning
graph parsing, blocked/incomplete/complete classification, package exposure, or
public compatibility facade module should change. The public
`CodexWatcher.AppServerClient` facade must remain available as required by
`orchestrator/project-contract.md`.

Do not create `orchestrator/rounds/round-107/worker-plan.json`; this is a
single-file implementation with no justified non-overlapping worker fan-out.

### Steps

1. Re-check coordination context before editing:
   `orchestrator/rounds/round-107/selection.md`,
   `orchestrator/state.json`, `orchestrator/project-contract.md`, and
   `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`.
2. Inspect the current import and use sites in
   `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`. Confirm the
   `CodexWatcher.AppServerClient` import supplies only the `AppServerTurn`
   type used by `classifyIssuePlanningTurn`, while shared completion helpers
   still come from `CodexWatcher.Turn.Classifier.Common`.
3. Replace only the facade import in
   `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs` with an explicit
   import from `CodexWatcher.Workflow.Agent.Codex.Client` for `AppServerTurn`.
   Keep all behavior-bearing code unchanged.
4. Run import scans proving the selected file no longer imports the facade and
   now imports the direct owner:
   ```sh
   rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs
   rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.Agent\.Codex\.Client[[:space:]]+\(AppServerTurn\)' src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs
   ```
   The first command must produce no matches; the second must find the new
   import.
5. Inspect/discover focused issue-planning classifier test reachability before
   running broad gates. Start with:
   ```sh
   rg -n 'classifyIssuePlanningTurn|prop_turnClassifier|issue planning|IssuePlanning|quickCheckResult|testGroup|tasty|hspec' test src
   ```
   If no supported focused selector is discoverable, record that the
   issue-planning classifier assertions are plain `watcher-core-test` coverage
   and proceed with the required full test executable.
6. Confirm no package descriptor or public facade exposure changes:
   ```sh
   git diff -- moifold.cabal cabal.project \
     agent-workflow-core/agent-workflow-core.cabal \
     agent-workflow-codex/agent-workflow-codex.cabal \
     agent-workflow-github/agent-workflow-github.cabal \
     src/CodexWatcher/AppServerClient.hs
   ```
   This diff must be empty.
7. Confirm no unrelated production, test, docs, fixture, package-candidate, or
   prior-artifact edits were introduced, apart from the selected source file
   and this round's allowed artifacts.
8. Confirm `orchestrator/rounds/round-107/worker-plan.json` does not exist.

### Verification

Required validation gates:

```sh
rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs
rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.Agent\.Codex\.Client[[:space:]]+\(AppServerTurn\)' src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs
rg -n 'classifyIssuePlanningTurn|prop_turnClassifier|issue planning|IssuePlanning|quickCheckResult|testGroup|tasty|hspec' test src
cabal test watcher-core-test
cabal build all
git diff -- moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal src/CodexWatcher/AppServerClient.hs
test ! -e orchestrator/rounds/round-107/worker-plan.json
git diff --check
git diff --cached --check
```

Expected behavior evidence from `watcher-core-test` must continue to cover the
issue-planning classifier cases named in the selection: running turns, failed
turns, missing-output blocking, issue/subissue request parsing, planning-graph
parsing, invalid issue-creation payload classification, and structured
blocked/incomplete/complete outcome classification. If no focused selector is
available, record that result in the implementation notes instead of inventing
one.
