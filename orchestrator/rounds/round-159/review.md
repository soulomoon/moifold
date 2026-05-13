### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. Test suite `watcher-core-test` completed with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass with no output.
- Command: `git diff --cached --check`
  Result: pass with no output.
- Command: `rg -n '^import[[:space:]]+CodexWatcher\.Core\.Ids' src/CodexWatcher/Cli/Command/RunnerGuard.hs`
  Result: pass for absence. No matches; command exited 1 as expected.
- Command: `rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids' src/CodexWatcher/Cli/Command/RunnerGuard.hs`
  Result: pass. Found `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))` at line 34 and `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))` at line 35.
- Command: `rg -n 'CodexWatcher\.Core\.Ids' src app test docs *.cabal agent-workflow-*/*.cabal agent-workflow-*/src`
  Result: pass. `src/CodexWatcher/Cli/Command/RunnerGuard.hs` is absent from the remaining-facade scan; expected remaining users include `moifold.cabal`, `src/CodexWatcher/Core/Ids.hs`, other moifold source modules, tests, and compatibility-policy docs.
- Command: `git status --short`
  Result: pass. Changed paths are `orchestrator/state.json`, `src/CodexWatcher/Cli/Command/RunnerGuard.hs`, and untracked `orchestrator/rounds/round-159/` artifacts.
- Command: `git diff --name-only`
  Result: pass. Tracked diffs are only `orchestrator/state.json` and `src/CodexWatcher/Cli/Command/RunnerGuard.hs`.
- Command: `git ls-files --others --exclude-standard`
  Result: pass. Untracked files before review were only `orchestrator/rounds/round-159/selection.md`, `plan.md`, and `implementation-notes.md`.
- Command: `git diff -U0 -- src/CodexWatcher/Cli/Command/RunnerGuard.hs`
  Result: pass. The production diff removes only the `CodexWatcher.Core.Ids` import and adds the two direct owner imports; no function bodies changed.
- Command: `git diff --cached --name-only`
  Result: pass. No staged paths.
- Command: `rg -n '^module CodexWatcher\.Core\.Ids|CodexWatcher\.Core\.Ids' src/CodexWatcher/Core/Ids.hs moifold.cabal`
  Result: pass. `src/CodexWatcher/Core/Ids.hs` still declares `module CodexWatcher.Core.Ids`, and `moifold.cabal` still exposes `CodexWatcher.Core.Ids`.
- Command: `sed -n '1,80p' src/CodexWatcher/Core/Ids.hs`
  Result: pass. The facade remains a re-export of `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.
- Command: `rg -n 'deprecat|remov|Cabal|exposed|release|terminal|milestone|approval|public compatibility|compatibility removal' orchestrator/rounds/round-159/selection.md orchestrator/rounds/round-159/plan.md orchestrator/rounds/round-159/implementation-notes.md`
  Result: pass. The round artifacts explicitly reserve deprecation, Cabal exposure removal, facade deletion, milestone completion, terminal completion, release approval, and public compatibility removal for later exact gates.

### Plan Compliance
- Step 1, edit only `src/CodexWatcher/Cli/Command/RunnerGuard.hs`: met. The production diff touches only that selected file.
- Step 2, remove `CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), TurnId (..))`: met. Focused absence scan found no `CodexWatcher.Core.Ids` import in the selected file.
- Step 3, add `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`: met at line 34.
- Step 4, add `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`: met at line 35.
- Step 5, leave existing `RepoName`, `unRepoName`, `ThreadId`, `unThreadId`, `TurnId`, and `unTurnId` uses unchanged: met. The zero-context source diff is import-only.
- Step 6, confirm no accidental edits outside selected source file and expected round artifacts: met. Tracked diffs are limited to controller round state plus the selected source file, and untracked files are round artifacts.
- Step 7, do not create `worker-plan.json`: met. No `orchestrator/rounds/round-159/worker-plan.json` exists.

### Decision
**APPROVED**

### Evidence
Roadmap lineage matches `2026-05-11-00-highest-value-cleanup` / `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-159-runner-guard-command-core-ids-split-import-migration`.

The implementation is the expected import-only production migration: `RunnerGuard.hs` now imports `RepoName` from `CodexWatcher.Workflow.GitHub.Ids` and `ThreadId`/`TurnId` from `CodexWatcher.Workflow.Agent.Ids`. `CodexWatcher.Core.Ids` remains present, unchanged, and exposed in `moifold.cabal`; remaining facade users are still visible for later reviewed gates.

The round does not change package descriptors, docs, runtime compatibility files, public facade modules, tests, function bodies, or behavior-facing command rendering. It does not imply deprecation, removal, Cabal exposure cleanup, milestone completion, terminal completion, release approval, or public compatibility approval.
