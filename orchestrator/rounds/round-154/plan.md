### Goal
Migrate only `test/AutomaticLoopRunnerSpec.hs` away from the combined
`CodexWatcher.Core.Ids` compatibility facade by importing the existing GitHub
and agent identifier types from their direct owner modules, while preserving
all automatic-loop runner test behavior.

### Approach
Keep this as a one-file import convergence change under roadmap
`2026-05-11-00-highest-value-cleanup` revision `rev-001`, milestone
`milestone-003-import-convergence-package-boundaries`, direction
`direction-011-core-ids-import-convergence`, and extracted item
`round-154-automatic-loop-runner-spec-core-ids-split-import-migration`.

The implementation should replace the current
`CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), unThreadId)` import with
owner imports:

- `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`
- `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), unThreadId)`

Do not change test bodies, helpers, assertions, production modules, package
descriptors, docs, compatibility facades, public exposure, or any broader
`Core.Ids` users. The project-wide compatibility, package-boundary, and
cleanup approval invariants remain governed by `orchestrator/project-contract.md`.

### Steps
1. Edit `test/AutomaticLoopRunnerSpec.hs` and remove the
   `CodexWatcher.Core.Ids` import.
2. Add direct imports for `RepoName (..)` from
   `CodexWatcher.Workflow.GitHub.Ids` and `ThreadId (..), unThreadId` from
   `CodexWatcher.Workflow.Agent.Ids`.
3. Confirm no other lines in `test/AutomaticLoopRunnerSpec.hs` changed unless a
   formatter makes a necessary import-order adjustment.
4. Confirm this round does not edit production code, Cabal files, docs,
   compatibility modules, public facade exports, or other tests.
5. Record in implementation notes that `CodexWatcher.Core.Ids` remains
   available and exposed; this round is preferred-import convergence only, not
   deprecation or removal approval.

### Verification
Run focused and baseline checks because this touches test code and import
ownership:

1. `cabal test watcher-core-test`
2. `cabal build all`
3. `git diff --check`

Before handoff to review, inspect the final diff and verify:

- `test/AutomaticLoopRunnerSpec.hs` no longer imports `CodexWatcher.Core.Ids`.
- The automatic-loop execute, dry-run, retry-classification, request-id,
  thread-id, and endpoint-backed app-server assertions are unchanged.
- No removal or deprecation claim is made for `CodexWatcher.Core.Ids`, and no
  Cabal exposure or compatibility-surface change is present.

### Worker Fan-Out
Worker fan-out is not used. The selected scope is serial, one-file, and has no
non-overlapping ownership boundary that would justify `worker-plan.json`.
