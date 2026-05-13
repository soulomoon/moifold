### Checks Run
- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.

- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`

- Command: `git diff --check`
  Result: pass; no whitespace or conflict-marker errors.

- Command: `git diff --cached --name-only`
  Result: pass; no staged files were present.

- Command: `git diff --cached --check`
  Result: skipped because `git diff --cached --name-only` showed no staged changes.

- Command: `git diff -- src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`
  Result: pass; the selected file diff only removes `import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)` and adds `import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)` plus `import CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, PrNumber)`.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`
  Result: pass; no matches, exit code 1 from `rg` for no selected-file matches.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test moifold.cabal`
  Result: pass for scoped review; remaining users are outside this round and prove this is not completion, removal, or deprecation of `CodexWatcher.Core.Ids`.

### Plan Compliance
- State lineage: met. `orchestrator/state.json` records roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, roadmap dir `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`, active round `round-174`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-174-issue-implement-indexed-core-ids-split-import-migration`, stage `review`, `worker_mode: none`, and `merge_ready: false`.

- Selection scope: met. `orchestrator/rounds/round-174/selection.md` and `plan.md` select only `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs` for migration from the `Core.Ids` compatibility facade to direct owner imports.

- Import replacement: met. The selected file changed from `CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)` to `CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, PrNumber)` and `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`.

- Export/API and behavior preservation: met. The selected-file diff contains only import changes; no export list, indexed state/effect/event/observation type, projection, transition helper, constructor, deriving clause, or function body changed.

- Out-of-scope surfaces: met. No Cabal, docs, tests, fixtures, runtime compatibility files, roadmap files, public facade module, or public facade exposure changed in the implementation diff. `CodexWatcher.Core.Ids` remains exposed in `moifold.cabal`.

- Remaining facade users: met. The scan over `src app test moifold.cabal` still reports remaining `CodexWatcher.Core.Ids` users in `moifold.cabal`, `src/CodexWatcher/Core/Ids.hs`, multiple production modules, and tests. These are outside this round, so this review does not approve completion, removal, or deprecation.

### Decision
**APPROVED**

### Evidence
The implementation matches the selected import-only migration. The only production file diff for `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs` is the requested replacement of the compatibility-facade import with direct owner imports. The selected file no longer imports `CodexWatcher.Core.Ids`.

Baseline verification passed: `cabal build all`, `cabal test watcher-core-test`, and `git diff --check`. Cached diff checking was skipped only because no files were staged.

Remaining `CodexWatcher.Core.Ids` users from the required scan are intentionally out of scope for this round: `moifold.cabal:46`, `src/CodexWatcher/Core/Ids.hs:1`, `src/CodexWatcher/EffectInterpreter.hs:20`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs:29`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs:38`, `src/CodexWatcher/GoldenReplay.hs:22`, `src/CodexWatcher/EventLog/Types.hs:17`, `src/CodexWatcher/EventLog/Replay.hs:17`, `src/CodexWatcher/Healthcheck.hs:32`, `src/CodexWatcher/StateMachine.hs:25`, `src/CodexWatcher/Cli/Command/IssueFanout.hs:44`, `src/CodexWatcher/Runtime/Compatibility.hs:14`, `src/CodexWatcher/Cli/Parser/Common.hs:41`, `src/CodexWatcher/Cli/Types.hs:22`, and the listed test imports under `test/`.
