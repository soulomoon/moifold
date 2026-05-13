### Checks Run
- Command: `git diff -- src/CodexWatcher/Domain/PrReview/LaunchCli.hs orchestrator/rounds/round-168/plan.md orchestrator/rounds/round-168/implementation-notes.md`
  Result: pass. `LaunchCli.hs` changed only imports: removed `CodexWatcher.Core.Ids (BranchName (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..))`, added `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..))`, and added `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), PrNumber (..), RepoName (..))`. `plan.md` and `implementation-notes.md` are new round artifacts and match the selected one-file migration.
- Command: `git diff --no-index -- /dev/null orchestrator/rounds/round-168/plan.md`
  Result: pass. Inspected new plan artifact; it limits implementation to the `LaunchCli.hs` import migration and requires baseline checks.
- Command: `git diff --no-index -- /dev/null orchestrator/rounds/round-168/implementation-notes.md`
  Result: pass. Inspected new implementation notes; they report the same import-only change and verification set.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
  Result: pass. No matches; command exited 1 as expected for this check.
- Command: `rg -n "CodexWatcher\\.Workflow\\.(GitHub|Agent)\\.Ids" src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
  Result: pass. Found direct owner imports at `src/CodexWatcher/Domain/PrReview/LaunchCli.hs:23` and `src/CodexWatcher/Domain/PrReview/LaunchCli.hs:39`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs $(rg --files -g '*.cabal' -g 'package.yaml' -g 'cabal.project')`
  Result: pass. Remaining `Core.Ids` users are outside `LaunchCli.hs` and include the public facade exposure in `moifold.cabal`, tests, docs, and other moifold modules that the selection marks out of scope.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.(GitHub|Agent)\\.Ids" $(rg --files -g '*.cabal' -g 'package.yaml' -g 'cabal.project')`
  Result: pass. Package exposure remains aligned: `moifold.cabal` exposes `CodexWatcher.Core.Ids`, `agent-workflow-codex.cabal` exposes `CodexWatcher.Workflow.Agent.Ids`, and `agent-workflow-github.cabal` exposes `CodexWatcher.Workflow.GitHub.Ids`.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. `watcher-core-test` passed, including PR-review launch CLI coverage; final summary: `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged diff whitespace errors.

### Plan Compliance
- Step 1, locate the existing `CodexWatcher.Core.Ids` import in `LaunchCli.hs`: met. The inspected diff shows the old combined facade import was the only removed import.
- Step 2, remove only that `CodexWatcher.Core.Ids` import from `LaunchCli.hs`: met. `rg` over `LaunchCli.hs` found no `CodexWatcher.Core.Ids` import, and the file diff is import-only.
- Step 3, add `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `PrNumber`, and `RepoName`: met. The direct GitHub owner import is present at line 39 with exactly those constructors.
- Step 4, add `CodexWatcher.Workflow.Agent.Ids` for `RequestId` and `ThreadId`: met. The direct Agent owner import is present at line 23 with exactly those constructors.
- Step 5, leave expressions and type signatures unchanged except import ordering or formatting: met. The `LaunchCli.hs` diff contains no expression, type signature, JSON, event, command rendering, runtime-owner, compatibility-write, or output-text changes.
- Step 6, do not edit other production, test, documentation, package descriptor, roadmap, state, or compatibility files for implementation: met for implementation scope. The only production code change is `LaunchCli.hs`; `orchestrator/state.json` and round artifacts are orchestration metadata.

### Decision
**APPROVED**

### Evidence
The integrated result matches the selected extraction for `round-168-pr-review-launch-cli-core-ids-split-import-migration`: `LaunchCli.hs` now imports `RequestId` and `ThreadId` from `CodexWatcher.Workflow.Agent.Ids`, and `BranchName`, `PrNumber`, and `RepoName` from `CodexWatcher.Workflow.GitHub.Ids`.

The change preserves the roadmap and project-contract boundaries. `CodexWatcher.Core.Ids` remains exposed in `moifold.cabal`, direct owner modules remain exposed from their owning packages, and remaining facade users are outside this selected one-file migration. No removal, deprecation, package exposure change, compatibility file migration, docs policy change, runtime behavior change, or public API cleanup is claimed by this round.

Baseline verification passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`. Focused import convergence checks also passed.
