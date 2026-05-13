### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged changes were present; no whitespace errors reported.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.Agent\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids" test/AutomaticLoopRunnerSpec.hs`
  Result: pass. `test/AutomaticLoopRunnerSpec.hs` no longer imports `CodexWatcher.Core.Ids`; it imports `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), unThreadId)` and `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs *.cabal packages 2>/dev/null || true`
  Result: pass with expected remaining users outside this round. The scan still finds `CodexWatcher.Core.Ids` exposed in `moifold.cabal`, defined in `src/CodexWatcher/Core/Ids.hs`, and imported by other src/test/docs surfaces. This is consistent with the selected preferred-import migration and does not imply removal or deprecation approval.
- Command: `git diff --stat && git diff --name-status`
  Result: pass. Tracked changes are limited to `orchestrator/state.json` and `test/AutomaticLoopRunnerSpec.hs`.
- Command: `git diff --cached --name-status && git ls-files --others --exclude-standard`
  Result: pass. No staged changes. Untracked files before review were only `orchestrator/rounds/round-154/selection.md`, `plan.md`, and `implementation-notes.md`; adding this review creates only round artifacts.

### Plan Compliance
- Edit only `test/AutomaticLoopRunnerSpec.hs` and remove the `CodexWatcher.Core.Ids` import: met. The test diff removes only the combined facade import.
- Add direct owner imports for `RepoName`, `ThreadId`, and `unThreadId`: met. `RepoName (..)` now comes from `CodexWatcher.Workflow.GitHub.Ids`, and `ThreadId (..), unThreadId` now come from `CodexWatcher.Workflow.Agent.Ids`.
- Do not change test bodies except necessary import ordering: met. The file diff is import-only; automatic-loop execute, dry-run, retry-classification, request-id, thread-id, and endpoint-backed app-server assertions are unchanged.
- Do not edit production code, Cabal files, docs, compatibility modules, public facade exports, or other tests: met. Tracked implementation scope is the selected test file plus controller state.
- Record that `CodexWatcher.Core.Ids` remains available and exposed and that this is not deprecation/removal approval: met. `implementation-notes.md` states this explicitly, and the broader scan confirms remaining facade exposure/users.

### Decision
**APPROVED**

### Evidence
The integrated round result matches roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-154-automatic-loop-runner-spec-core-ids-split-import-migration`.

The only selected implementation file change is:

```diff
-import CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), unThreadId)
+import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), unThreadId)
+import CodexWatcher.Workflow.GitHub.Ids (RepoName (..))
```

Baseline verification passed, focused import scans passed, and the scope check found no out-of-scope tracked implementation files. Remaining `CodexWatcher.Core.Ids` users are expected blockers/evidence for later rounds, not a failure of this selected one-file import convergence round.
