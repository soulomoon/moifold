### Goal
Migrate only `src/CodexWatcher/StateMachine.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing the same identifier types from their direct owner modules, while preserving all state-machine behavior and public compatibility facade availability.

### Approach
This is a single-file, serial import-convergence slice under milestone `milestone-003-import-convergence-package-boundaries` and direction `direction-011-core-ids-import-convergence`. The implementation should replace the existing `CodexWatcher.Core.Ids` import in `StateMachine.hs` with owner imports:

- `CodexWatcher.Workflow.GitHub.Ids` for `BranchName (..)`, `CommitSha`, `IssueNumber (..)`, `PrNumber (..)`, and `ReviewThreadId`
- `CodexWatcher.Workflow.Agent.Ids` for `ThreadId`

No function body, export list, constructor use, validation rule, branch-attempt parser/renderer, PR mismatch text, review-thread resolution behavior, package descriptor, public facade exposure, or compatibility surface should change. This round is import convergence only; it is not deprecation, removal, milestone completion, or package publication approval.

### Steps
1. In `src/CodexWatcher/StateMachine.hs`, replace the single `CodexWatcher.Core.Ids` import with direct imports from `CodexWatcher.Workflow.GitHub.Ids` and `CodexWatcher.Workflow.Agent.Ids`.
2. Keep the imported symbol set minimal and aligned with existing use: preserve `BranchName (..)` for `unBranchName` and construction in `nextIssueAttemptBranch`, preserve `IssueNumber (..)` for `unIssueNumber` in branch parsing, preserve `PrNumber (..)` for `unPrNumber` and PR constructors, and import `CommitSha`, `ReviewThreadId`, and `ThreadId` as types.
3. Do not edit the module export list, event constructors, `Decision` shape, phase-action validation, `step`, PR mismatch handling, review-thread resolution, `nextIssueAttemptBranch`, or helper logic.
4. Do not edit Cabal files, tests, docs, roadmap files, compatibility facades, runtime compatibility files, or any other production module.
5. Do not write `worker-plan.json`; the selected slice is one file with no useful non-overlapping worker ownership.
6. After implementation, record in `implementation-notes.md` that the public `CodexWatcher.Core.Ids` facade remains available and that remaining facade users are expected outside this selected file.

### Verification
Run the roadmap baseline:

```sh
cabal build all
cabal test watcher-core-test
git diff --check
git diff --cached --check
```

Run the focused selected-file scan and require no matches:

```sh
rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/StateMachine.hs
```

Run a remaining facade-user scan and record the remaining matches as evidence that this round does not claim completion or removal:

```sh
rg -n "CodexWatcher\\.Core\\.Ids" src app test docs *.cabal agent-workflow-* || true
```

Review the diff manually to confirm it is import-only for `src/CodexWatcher/StateMachine.hs` and does not change behavior, package exposure, public compatibility modules, or roadmap status.
