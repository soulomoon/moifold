### Checks Run
- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass; no whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass; no staged diff or staged whitespace errors.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids|IssueNumber|RepoName|unIssueNumber" test/IssueFanoutAppServerSpec.hs`
  Result: pass; the selected file imports `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), RepoName (..), unIssueNumber)` at line 18 and all existing `IssueNumber`, `RepoName`, and `unIssueNumber` uses remain in place.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" test/IssueFanoutAppServerSpec.hs`
  Result: pass; no matches, exit code 1.
- Command: `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(IssueNumber \\(\\.\\.\\), RepoName \\(\\.\\.\\), unIssueNumber\\)" test/IssueFanoutAppServerSpec.hs`
  Result: pass; the exact direct-owner import is present at line 18.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs *.cabal`
  Result: pass; remaining `CodexWatcher.Core.Ids` users are outside the selected file and remain as known follow-up import-convergence users, including the public facade exposure in `moifold.cabal`.
- Command: `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)" moifold.cabal src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Core/Ids.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Permission.hs`
  Result: pass; `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission` remain present and exposed.
- Command: `git diff --name-only && git ls-files --others --exclude-standard`
  Result: pass; changed paths are limited to `orchestrator/state.json`, `test/IssueFanoutAppServerSpec.hs`, and round-153 artifacts.

### Plan Compliance
- Replace only the selected import in `test/IssueFanoutAppServerSpec.hs`: met; the diff changes only `CodexWatcher.Core.Ids` to `CodexWatcher.Workflow.GitHub.Ids` for `IssueNumber`, `RepoName`, and `unIssueNumber`.
- Leave test bodies, helpers, command rendering expectations, retry classification assertions, child-start classification assertions, JSON-RPC failure assertions, and decode-failure assertions unchanged: met; the selected test file diff is import-only, and `cabal test watcher-core-test` passed with the issue fanout app-server coverage still running.
- Confirm the selected file no longer imports `CodexWatcher.Core.Ids` and now imports the direct owner: met; focused `rg` scans prove no selected-file facade import and the exact direct-owner import at line 18.
- Keep package descriptors, public facades, production files, docs, runtime compatibility files, broader migration, deprecation/removal, milestone completion, terminal completion, release approval, and public compatibility removal out of scope: met; scope scan shows no changed production, docs, package descriptor, compatibility runtime, or public facade files. Remaining facade users and exposed facades are preserved.
- Record implementation notes: met; `orchestrator/rounds/round-153/implementation-notes.md` records the import-only change and out-of-scope boundaries.

### Decision
**APPROVED**

### Evidence
The integrated round result is a one-file import convergence slice plus controller/round artifacts. The code diff in `test/IssueFanoutAppServerSpec.hs` changes only:

```haskell
import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), RepoName (..), unIssueNumber)
```

No selected-file `CodexWatcher.Core.Ids` import remains. Broader import scans show remaining `CodexWatcher.Core.Ids` users in `src`, `test`, docs, and `moifold.cabal`, which are expected blockers/follow-up users and not removal approval. The compatibility facade modules named by the active roadmap verification remain present and exposed in `moifold.cabal`.

Baseline validation passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`. Scope validation passed: changed paths are limited to controller state, round-153 artifacts, and `test/IssueFanoutAppServerSpec.hs`.
