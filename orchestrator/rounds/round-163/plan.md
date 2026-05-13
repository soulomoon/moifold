### Goal
Migrate only `src/CodexWatcher/Domain/PrReview/Protocol.hs` off the combined `CodexWatcher.Core.Ids` compatibility facade by importing `CommitSha` and `ReviewThreadId` from `CodexWatcher.Workflow.GitHub.Ids`, and `ThreadId` and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`.

This round belongs to roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-163-pr-review-protocol-core-ids-split-import-migration`.

### Approach
Keep the implementation as a behavior-preserving import migration. Do not touch any function bodies, exported names, PR-review session types, worker/reviewer outcomes, turn-start/wait/emit helpers, `runPrReviewWorkerProtocol`, `runPrReviewReviewerProtocol`, or event-constructor behavior.

Use the direct owner modules that already provide the same identifiers:

- `CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId)`
- `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`

Leave `CodexWatcher.Core.Ids` itself exposed and unchanged. Do not migrate other facade users, edit tests, package descriptors, docs, roadmap status, state files, or compatibility policy in this round. Shared compatibility and package-boundary invariants remain governed by `orchestrator/project-contract.md`.

Worker fan-out is not justified: the selected work is a one-file import-only migration with no non-overlapping implementation ownership boundary. Do not create `worker-plan.json`.

### Steps
1. Edit `src/CodexWatcher/Domain/PrReview/Protocol.hs` only.
2. Replace `import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId, ThreadId, TurnId)` with:
   - `import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`
   - `import CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId)`
3. Preserve all other imports unless the formatter or compiler requires ordering-only cleanup.
4. Confirm the source diff for `src/CodexWatcher/Domain/PrReview/Protocol.hs` is import-only.
5. Do not create, delete, deprecate, or modify any compatibility facade, runtime compatibility file, Cabal exposed-module entry, roadmap file, state file, or test module.
6. Record implementation notes with the exact changed file, import-only scope, verification commands, focused import scans, and the remaining `CodexWatcher.Core.Ids` users from the post-change scan.

### Verification
Run the baseline checks required for production-code cleanup in the active roadmap verification file:

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check` if staging is involved

Run focused import-convergence checks and record their output in the implementation notes:

- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/PrReview/Protocol.hs` should produce no matches.
- `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/Domain/PrReview/Protocol.hs` should show the new direct owner imports.
- `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github examples` should list the remaining facade users and must not list `src/CodexWatcher/Domain/PrReview/Protocol.hs`.
- `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal` should confirm public facades remain exposed and the direct owner modules remain exposed.

Review the diff and existing focused behavior expectations:

- `WorkerSession`, `ReviewerSession`, `WorkerOutcome`, and `ReviewerOutcome` definitions must be unchanged.
- Worker and reviewer turn-start, wait, emit, and protocol-runner functions must be unchanged.
- `ReviewerClean`, `ReviewerProblemsAdded`, `PrReviewCleanFound`, and `PrReviewProblemsAdded` event construction must be unchanged.
