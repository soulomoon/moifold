### Checks Run
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass; loaded active verification for `2026-05-11-00-highest-value-cleanup` `rev-001`. Baselines include `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check` when staging is involved. Because this round changes test code, the artifact-only skip does not apply, so `cabal build all` was run.
- Command: `git diff -- test/ObserveCommandSpec.hs`
  Result: pass; the selected implementation diff removes `CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), TurnId (..), unThreadId)` and adds direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.
- Command: `git diff --unified=0 -- test/ObserveCommandSpec.hs`
  Result: pass; zero-context diff shows only one removed import and two added imports. No test body, helper, or assertion lines changed.
- Command: `git diff --numstat -- test/ObserveCommandSpec.hs`
  Result: pass; `2 1 test/ObserveCommandSpec.hs`, matching the import-only split.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" test/ObserveCommandSpec.hs`
  Result: pass; exited with no matches, which is expected for this negative scan.
- Command: `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(RepoName \\(\\.\\.\\)\\)" test/ObserveCommandSpec.hs`
  Result: pass; found `16:import CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`.
- Command: `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids \\(ThreadId \\(\\.\\.\\), TurnId \\(\\.\\.\\), unThreadId\\)" test/ObserveCommandSpec.hs`
  Result: pass; found `15:import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..), unThreadId)`.
- Command: `git diff --name-status`
  Result: pass; tracked changes are `M orchestrator/state.json` and `M test/ObserveCommandSpec.hs`. The `state.json` change activates round-155 review metadata; the selected implementation change is limited to `test/ObserveCommandSpec.hs`.
- Command: `git status --short --untracked-files=all`
  Result: pass; before reviewer artifact creation, untracked round artifacts were `selection.md`, `plan.md`, and `implementation-notes.md`; tracked modified files were `orchestrator/state.json` and `test/ObserveCommandSpec.hs`.
- Command: `git status --short --untracked-files=all`
  Result: pass; after reviewer artifact creation, untracked round artifacts are `selection.md`, `plan.md`, `implementation-notes.md`, `review.md`, and `review-record.json`; tracked modified files remain `orchestrator/state.json` and `test/ObserveCommandSpec.hs`.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `cabal build all`
  Result: pass; built and linked the `moifold` executable with GHC 9.12.2.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged changes and no cached whitespace errors.
- Command: `python3 -m json.tool orchestrator/rounds/round-155/review-record.json`
  Result: pass; `review-record.json` parses as valid JSON.

### Plan Compliance
- Step 1, open `test/ObserveCommandSpec.hs` and edit only the import block: met. The zero-context diff shows only import lines changed in the selected implementation file.
- Step 2, remove the `CodexWatcher.Core.Ids` import for `RepoName`, `ThreadId`, `TurnId`, and `unThreadId`: met. Focused scan found no `CodexWatcher.Core.Ids` occurrence in `test/ObserveCommandSpec.hs`.
- Step 3, add `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`: met. Focused scan found the direct GitHub owner import at line 16.
- Step 4, add `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..), unThreadId)`: met. Focused scan found the direct agent owner import at line 15.
- Step 5, leave observe execute, dry-run, configured-endpoint, planner-thread, event-log, and app-server request assertions unchanged: met. The implementation diff is import-only, and `watcher-core-test` passed.
- Step 6, confirm no other files were intentionally changed and no worker plan was created: met for implementation scope. The only implementation file changed is `test/ObserveCommandSpec.hs`; `orchestrator/state.json` and the untracked selection/plan/implementation notes are round-control artifacts. No worker plan exists and `worker_mode` is `none` in state.

### Decision
**APPROVED**

### Evidence
The selected scope is satisfied: `test/ObserveCommandSpec.hs` moved from the combined `CodexWatcher.Core.Ids` compatibility facade to direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` and `CodexWatcher.Workflow.Agent.Ids`. Test bodies and assertions were unchanged by diff. The compatibility facade remains available and untouched; this review does not approve deprecation, Cabal exposure cleanup, facade removal, runtime compatibility cleanup, milestone completion, release approval, or terminal roadmap completion.

The required checks passed: `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, `git diff --cached --check`, focused import scans, and scope/name-status checks including untracked artifacts.
