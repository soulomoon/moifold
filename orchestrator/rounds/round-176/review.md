### Checks Run
- Command: `sed -n '1,220p' orchestrator/state.json`
  Result: pass. State lineage matches roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-176-state-machine-core-ids-split-import-migration`, stage `review`, `worker_mode: none`, and `merge_ready: false`.

- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Project contract keeps import convergence separate from public deprecation/removal, keeps compatibility facades available until exact gates are satisfied, and requires baseline checks for shared contracts.

- Command: `git diff -- src/CodexWatcher/StateMachine.hs`
  Result: pass. The selected file only removes `import CodexWatcher.Core.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), ReviewThreadId, ThreadId)` and adds `import CodexWatcher.Workflow.Agent.Ids (ThreadId)` plus `import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), ReviewThreadId)`.

- Command: `git diff --name-status && git ls-files --others --exclude-standard orchestrator/rounds/round-176`
  Result: pass for scoped review. Tracked dirty files are `orchestrator/state.json` and `src/CodexWatcher/StateMachine.hs`; untracked round artifacts are `selection.md`, `plan.md`, and `implementation-notes.md`. The `orchestrator/state.json` diff is controller stage metadata for the active round. The implementation slice changes only `src/CodexWatcher/StateMachine.hs` plus round artifacts; no Cabal, docs, tests, runtime compatibility files, public facade modules, package exposure, or roadmap files changed.

- Command: `cabal build all`
  Result: pass. Cabal built all targets successfully, including `CodexWatcher.StateMachine` and the `moifold` executable.

- Command: `cabal test watcher-core-test`
  Result: pass. `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `git diff --check`
  Result: pass. No whitespace or conflict-marker errors reported.

- Command: `if git diff --cached --quiet; then printf 'SKIPPED: no staged changes\n'; else git diff --cached --check; fi`
  Result: pass/skipped. Output: `SKIPPED: no staged changes`.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/StateMachine.hs`
  Result: pass. No matches; `rg` exit code 1 is expected for no selected-file matches.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs *.cabal agent-workflow-* || true`
  Result: pass for scoped review. Remaining users exist outside this round, including `moifold.cabal`, tests, docs, `src/CodexWatcher/Core/Ids.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/GoldenReplay.hs`, `src/CodexWatcher/EventLog/*`, issue loop modules, healthcheck, and CLI modules. This confirms the round is not completion, removal, or deprecation.

### Plan Compliance
- Replace the selected `CodexWatcher.Core.Ids` import in `src/CodexWatcher/StateMachine.hs`: met. The old combined compatibility-facade import was removed and replaced with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.

- Preserve the selected symbol set and ownership split: met. Agent-owned `ThreadId` moved to `Workflow.Agent.Ids`; GitHub-owned `BranchName (..)`, `CommitSha`, `IssueNumber (..)`, `PrNumber (..)`, and `ReviewThreadId` moved to `Workflow.GitHub.Ids`.

- Keep behavior and API unchanged: met. The selected-file diff is import-only; no function body, export list, constructor, validation rule, branch-attempt parser/renderer, PR mismatch text, review-thread resolution path, event type, decision type, or helper logic changed.

- Avoid out-of-scope surfaces: met. No package descriptors, public compatibility facade exposure, runtime compatibility files, docs, tests, roadmap files, or release/public wording changed in the implementation slice.

- Preserve public compatibility availability and avoid deprecation/removal claims: met. `CodexWatcher.Core.Ids` remains exposed and still has remaining users outside this file. The round artifacts and implementation notes state this is import convergence only, not facade deprecation, Cabal exposure cleanup, runtime compatibility cleanup, milestone completion, or removal approval.

### Decision
**APPROVED**

### Evidence
The round is aligned to roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001` under `milestone-003-import-convergence-package-boundaries` and `direction-011-core-ids-import-convergence`. The active extracted item is `round-176-state-machine-core-ids-split-import-migration`.

The production diff for `src/CodexWatcher/StateMachine.hs` is import-only:

```diff
-import CodexWatcher.Core.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), ReviewThreadId, ThreadId)
+import CodexWatcher.Workflow.Agent.Ids (ThreadId)
+import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), ReviewThreadId)
```

The selected file has no remaining `CodexWatcher.Core.Ids` import. The broad facade scan still reports expected remaining users outside this slice, so approval does not imply `CodexWatcher.Core.Ids` deprecation, removal, Cabal exposure change, runtime compatibility cleanup, milestone completion, or terminal roadmap completion.
