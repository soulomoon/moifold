### Goal

Migrate `src/CodexWatcher/Workflow/Moifold/PrReview.hs` away from the
`CodexWatcher.Core.Ids` compatibility facade by importing its existing ID types
from their direct owner modules, while preserving PR-review observation
behavior and leaving all public compatibility surfaces exposed.

### Approach

This is a one-file production import-convergence slice under
`2026-05-11-00-highest-value-cleanup` / `rev-001`. Keep the implementation to
the import section of `src/CodexWatcher/Workflow/Moifold/PrReview.hs`: replace
the current `CodexWatcher.Core.Ids` import with direct imports from
`CodexWatcher.Workflow.GitHub.Ids` for GitHub-owned identifiers and
`CodexWatcher.Workflow.Agent.Ids` for agent-owned identifiers.

Do not change function bodies, event constructors, decision construction,
review evidence handling, summaries, parser/renderer behavior, command output,
fixtures, package descriptors, documentation, or `CodexWatcher.Core.Ids`
itself. The shared invariants and compatibility constraints remain those in
`orchestrator/project-contract.md`.

### Steps

1. Open `src/CodexWatcher/Workflow/Moifold/PrReview.hs` and locate the import
   of `CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), ThreadId, TurnId)`.
2. Remove that `CodexWatcher.Core.Ids` import.
3. Add `import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`.
4. Add `import CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId (..))`.
5. Leave all declarations and function bodies unchanged, including
   `PrReviewCheckingObservation`, `observePrReviewChecking`,
   `reviewFeedbackObservedTick`, `unresolvedThreadIds`,
   `unresolvedReviewEvidence`, `unresolvedReviewEvidenceOrThreadIds`, and
   `reviewThreadSummary`.
6. Inspect the diff and confirm that the only production-code change is the
   import replacement in `src/CodexWatcher/Workflow/Moifold/PrReview.hs`.
7. Do not edit roadmap files, controller state, package descriptors, tests,
   compatibility facades, or any other production modules.

### Verification

Run focused checks for this one-file import migration:

1. `git diff -- src/CodexWatcher/Workflow/Moifold/PrReview.hs`
2. `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Workflow/Moifold/PrReview.hs`
   and confirm it returns no matches.
3. `cabal build all`
4. `cabal test watcher-core-test`
5. `git diff --check`

If the implementation is staged during a later role, also run
`git diff --cached --check`.

Record in `implementation-notes.md` that this round changed only the direct ID
owner imports in `src/CodexWatcher/Workflow/Moifold/PrReview.hs`, and that
`CodexWatcher.Core.Ids` remains available and exposed.

### Worker Fan-Out

No worker fan-out. The round has a single owned file and a single import
replacement, so `worker-plan.json` is not required.
