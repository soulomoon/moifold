### Checks Run
- Command: `git diff -- src/CodexWatcher/Domain/IssuePlanning/Fanout.hs orchestrator/rounds/round-167/plan.md orchestrator/rounds/round-167/implementation-notes.md`
  Result: pass; the production diff is limited to replacing the `CodexWatcher.Core.Ids` import in `Fanout.hs` with direct `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` imports. The round plan and implementation notes are present as new artifacts.
- Command: `rg -n "CodexWatcher\.Core\.Ids" src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`
  Result: pass; exited 1 with no output, confirming the selected file has no remaining `CodexWatcher.Core.Ids` reference.
- Command: `rg -n "CodexWatcher\.Core\.Ids" src app test *.cabal docs packages 2>/dev/null || true`
  Result: pass; remaining facade users are outside the selected file and include expected production/test/docs users plus the public `moifold.cabal` exposure. No remaining `Fanout.hs` match was reported.
- Command: `rg -n "CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids|CodexWatcher\.Core\.Ids" codex-watcher.cabal *.cabal src packages 2>/dev/null || true`
  Result: pass; confirmed `Fanout.hs` now imports `CodexWatcher.Workflow.Agent.Ids (ThreadId (..))` and `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), RepoName (..))`, while `CodexWatcher.Core.Ids` remains exposed in `moifold.cabal` as required by the compatibility contract.
- Command: `git diff --check && git diff --cached --check`
  Result: pass; no whitespace errors and no staged diff errors.
- Command: `cabal build all`
  Result: pass; output reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; test suite completed with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`

### Plan Compliance
- Replace the current `CodexWatcher.Core.Ids` import in `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs` with direct owner imports: met; the file now imports `ThreadId` from `CodexWatcher.Workflow.Agent.Ids` and `BranchName`, `IssueNumber`, and `RepoName` from `CodexWatcher.Workflow.GitHub.Ids`.
- Leave type uses, constructors, record fields, parser logic, slug rendering, config JSON rendering, workdir command rendering, and compatibility-write construction unchanged: met; the production diff changes only import lines.
- Confirm the file no longer imports `CodexWatcher.Core.Ids`: met; the focused `rg` command returned no matches and exit 1.
- Inspect the resulting diff and verify it is limited to the import lines in `Fanout.hs`: met; the selected production diff is import-only.
- Do not perform broader `Core.Ids` convergence, package descriptor cleanup, facade deletion, deprecation, docs edits, test restructuring, runtime compatibility cleanup, or roadmap/state changes: met for implementation scope; remaining `Core.Ids` users and public facade exposure remain in place.

### Decision
**APPROVED**

### Evidence
The integrated result matches the selected extraction for `round-167-issue-planning-fanout-core-ids-split-import-migration`: one production source file moved from the combined `CodexWatcher.Core.Ids` compatibility facade to direct owner ID imports, with behavior left unchanged.

Baseline verification from `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md` passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

Roadmap alignment checks are satisfied for this round. The round records lineage for `2026-05-11-00-highest-value-cleanup` / `rev-001`; it does not append work to an older family; it does not treat preferred imports as deprecation or removal approval; and `CodexWatcher.Core.Ids` remains available and exposed for later gated cleanup.
