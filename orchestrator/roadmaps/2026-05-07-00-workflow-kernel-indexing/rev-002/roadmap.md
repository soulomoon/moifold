# Indexed PR-Review Adoption Roadmap

## Status Legend

- `pending`
- `in-progress`
- `done`

## Scope

This revision continues the workflow-kernel extraction after `rev-001` proved the
parallel indexed `WorkflowSpec` API with DocsMigration and one PR-review
mergeability slice. The remaining work should port real moifold workflow policy
through indexed adapters while preserving compatibility behavior: event JSON
schemas, golden logs, daemon result shapes, dry-run reports, action ordering, and
existing facade modules remain stable unless a later roadmap explicitly changes
them.

Keep concrete lifecycle policy in moifold. Do not move process execution,
filesystem writes, app-server startup, GitHub command execution, or concrete
`SomeWatcherState`/`WatcherEvent` ownership into the indexed core.

## Items

1. [pending] Port PR-review checking and verification observations to the indexed API
   Item id: item-007-indexed-pr-review-checking
   Depends on: none
   Parallel safe: no
   Parallel group: none
   Merge after: none
   Completion notes: Extend the indexed PR-review adapter to cover the checking and verification observation transitions currently exercised by `ReviewThreadsFound`, `NoReviewThreadsFound`, `PrReviewFeedbackFound`, and `PrReviewFixVerificationStarted`. Prove parity for emitted `WatcherEvent` values, source and target state labels, next states, pre/post effect plans, replay, permission acceptance, and observed-effect ordering.

2. [pending] Port PR-review worker outcome transitions to the indexed API
   Item id: item-008-indexed-pr-review-worker-outcomes
   Depends on: item-007-indexed-pr-review-checking
   Parallel safe: no
   Parallel group: none
   Merge after: item-007-indexed-pr-review-checking
   Completion notes: Cover fix-worker outcomes such as `PrReviewFixCompleted`, `PrReviewFixIncomplete`, and worker-blocked transitions through indexed planning. Preserve existing app-server output classification evidence, effect plans, daemon compatibility fields, and replay behavior.

3. [pending] Port PR-review reviewer outcome transitions to the indexed API
   Item id: item-009-indexed-pr-review-reviewer-outcomes
   Depends on: item-008-indexed-pr-review-worker-outcomes
   Parallel safe: no
   Parallel group: none
   Merge after: item-008-indexed-pr-review-worker-outcomes
   Completion notes: Cover reviewer outcomes such as `PrReviewCleanFound`, `PrReviewProblemsAdded`, `PrReviewReviewIncomplete`, reviewer-blocked transitions, and verification clean or missing-thread handling. Keep normalized classifier evidence and event-log replay parity intact.

4. [pending] Complete indexed mergeability and merge terminal coverage
   Item id: item-010-indexed-pr-review-mergeability-complete
   Depends on: item-009-indexed-pr-review-reviewer-outcomes
   Parallel safe: no
   Parallel group: none
   Merge after: item-009-indexed-pr-review-reviewer-outcomes
   Completion notes: Extend the existing clean-mergeability indexed slice to waiting, recheck, fix-required, blocked, stopped, and `PrReviewMergeCompleted` terminal paths. Preserve merge pre-commit ordering, request-id progression, and dry-run text.

5. [pending] Route one live PR-review daemon observation path through the indexed adapter
   Item id: item-011-indexed-pr-review-daemon-path
   Depends on: item-010-indexed-pr-review-mergeability-complete
   Parallel safe: no
   Parallel group: none
   Merge after: item-010-indexed-pr-review-mergeability-complete
   Completion notes: Replace one compatibility-only PR-review observation call site in daemon-facing policy with the indexed adapter while projecting back to existing moifold types. Prove daemon tick results, transaction failure reporting, dry-run output, and action ordering remain unchanged.

6. [pending] Prepare the next-domain indexed adoption plan
   Item id: item-012-indexed-next-domain-plan
   Depends on: item-011-indexed-pr-review-daemon-path
   Parallel safe: no
   Parallel group: none
   Merge after: item-011-indexed-pr-review-daemon-path
   Completion notes: Inspect current issue-planning and issue-implementation workflow policy after PR-review indexed coverage is real. Author the next revision deciding which domain should be ported next, with concrete parity surfaces and no premature package-boundary rewrites.
