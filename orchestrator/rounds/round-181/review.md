### Checks Run
- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; `1 of 1 test suites (1 of 1 test cases) passed`. Focused fanout coverage remained green, including deterministic request ids, persisted app-server thread ids, child command shape, launch write ordering, JSON-RPC/decode failures, and retryable clone classification.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `! rg -n 'CodexWatcher\.Core\.Ids' src/CodexWatcher/Cli/Command/IssueFanout.hs`
  Result: pass; no matches in the selected file.
- Command: `rg -n 'CodexWatcher\.Workflow\.Agent\.Ids|CodexWatcher\.Workflow\.GitHub\.Ids|BranchName|unBranchName|IssueNumber|RepoName|RequestId|ThreadId' src/CodexWatcher/Cli/Command/IssueFanout.hs`
  Result: pass; direct owner imports are present at lines 52-53, with existing uses including `RequestId <$> [8000 ..]`, `unBranchName`, `unRepoName`, `unThreadId`, and issue-number accessors.
- Command: `rg -n 'import CodexWatcher\.Core\.Ids' src app test docs moifold.cabal agent-workflow-* packages 2>/dev/null || true`
  Result: pass; remaining import users are outside this selected file. Production users remain in `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/EventLog/Types.hs`, and `src/CodexWatcher/Domain/IssueImplement/Loop.hs`. Test users remain under `test/`. No `app/`, `docs/`, `moifold.cabal`, `agent-workflow-*`, or `packages/` import matches were reported by this import-only scan.
- Command: `rg -n 'CodexWatcher\.Core\.Ids' src app test docs moifold.cabal agent-workflow-* packages 2>/dev/null || true`
  Result: pass; broad remaining-user scan separates production imports listed above, test imports, docs mentions under `docs/agentic-workflow-framework/`, `moifold.cabal` exposure, and the public facade module `src/CodexWatcher/Core/Ids.hs`. No `app/`, `agent-workflow-*`, or `packages/` users were reported.

### Plan Compliance
- Replace only the `CodexWatcher.Core.Ids` import in `src/CodexWatcher/Cli/Command/IssueFanout.hs`: met. The source diff removes the single facade import and adds `CodexWatcher.Workflow.Agent.Ids` plus `CodexWatcher.Workflow.GitHub.Ids`.
- Import `BranchName` from the GitHub owner because `unBranchName` is used: met. `BranchName (..)` is imported from `CodexWatcher.Workflow.GitHub.Ids`, and the existing `unBranchName` call remains at line 237.
- Preserve fanout planning, active issue discovery, child launch state writes, request-id progression, command rendering, dry-run text, process execution, parser/type modules, public facade exposure, Cabal, docs, runtime compatibility files, and behavior: met. The implementation source diff is import-only in `IssueFanout.hs`; no selected out-of-scope source, test, docs, Cabal, parser/type, or runtime compatibility file changed.
- Keep public compatibility facade available and avoid deprecation/removal claims: met. `src/CodexWatcher/Core/Ids.hs` and `moifold.cabal` exposure remain unchanged.

### Decision
**APPROVED**

### Evidence
The integrated implementation change in `src/CodexWatcher/Cli/Command/IssueFanout.hs` is scoped to replacing:

```haskell
import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..))
```

with direct owner imports:

```haskell
import CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..))
import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), RepoName (..))
```

`git diff --stat` also shows an existing controller-owned `orchestrator/state.json` diff in the worktree; this review did not modify it. No staging was performed, so `git diff --cached --check` was not applicable.
