### Goal
Migrate only `src/CodexWatcher/Domain/PrReview/Watcher.hs` away from the combined `CodexWatcher.Core.Ids` compatibility facade by importing the existing identifier types from their direct owner modules, while preserving all PR-review watcher behavior.

### Approach
Keep this as a sequential one-file import migration. `CodexWatcher.Workflow.GitHub.Ids` already owns and exports `CommitSha` and `ReviewThreadId (..)`, and `CodexWatcher.Workflow.Agent.Ids` already owns and exports `TurnId`; the current `CodexWatcher.Core.Ids` module only re-exports those owner modules.

Do not split this into worker fan-out. The implementation has one write target, no independent ownership boundaries, and no integration step that benefits from parallel workers.

The implementation must not change the export list, data declarations, function bodies, pattern matches, event constructors, error text, or behavior in `PrReviewObservation`, `prReviewObserve`, `unresolvedReviewEvidence`, mergeability forwarding, worker outcome handling, reviewer outcome handling, or `verifyReviewerOutcome`.

### Steps
1. Edit only `src/CodexWatcher/Domain/PrReview/Watcher.hs`.
2. Replace `import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), TurnId)` with direct owner imports:
   - `import CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId (..))`
   - `import CodexWatcher.Workflow.Agent.Ids (TurnId)`
3. Preserve the rest of the import list except for any mechanical ordering adjustment required by the repo formatter.
4. Leave every function body and exported symbol unchanged.
5. Do not edit `CodexWatcher.Core.Ids`, package descriptors, tests, docs, roadmap files, state files, public compatibility facades, or any other remaining `CodexWatcher.Core.Ids` importer.
6. After the edit, confirm the target file no longer imports `CodexWatcher.Core.Ids` and that remaining `CodexWatcher.Core.Ids` users are outside this round's scope.

### Verification
Run the roadmap baseline checks for this production-source import migration:

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check` if staging is involved

Also record focused import evidence:

- `rg -n "CodexWatcher.Core.Ids" src/CodexWatcher/Domain/PrReview/Watcher.hs` should return no matches.
- `rg -n "CodexWatcher.Core.Ids" src app test -g '*.hs'` may still show other users; those are explicitly out of scope for round 161.
