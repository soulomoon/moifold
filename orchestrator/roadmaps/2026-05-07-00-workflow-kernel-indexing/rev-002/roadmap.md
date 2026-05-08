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

1. [done] Port PR-review checking and verification observations to the indexed API
   Item id: item-007-indexed-pr-review-checking
   Depends on: none
   Parallel safe: no
   Parallel group: none
   Merge after: none
   Completion notes: Round 007 approved and merged the indexed PR-review checking adapter for `ReviewThreadsFound`, `NoReviewThreadsFound`, `PrReviewFeedbackFound`, and `PrReviewFixVerificationStarted`. Reviewer evidence covered unresolved and clean thread parity, feedback observations, verification start, replay/effect/permission parity, invalid observation failures, schema/golden/daemon/dry-run/action-ordering preservation, plus passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

2. [done] Port PR-review worker outcome transitions to the indexed API
   Item id: item-008-indexed-pr-review-worker-outcomes
   Depends on: item-007-indexed-pr-review-checking
   Parallel safe: no
   Parallel group: none
   Merge after: item-007-indexed-pr-review-checking
   Completion notes: Round 008 approved and merged the indexed PR-review fix-worker outcome adapter for completed, incomplete, and blocked worker observations. Reviewer evidence covered classifier-backed `AgentOutputClass` preservation, invalid observation parity, replay/effect/validation/permission parity, unchanged golden/event/daemon/dry-run/action-ordering surfaces, plus passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

3. [done] Port PR-review reviewer outcome transitions to the indexed API
   Item id: item-009-indexed-pr-review-reviewer-outcomes
   Depends on: item-008-indexed-pr-review-worker-outcomes
   Parallel safe: no
   Parallel group: none
   Merge after: item-008-indexed-pr-review-worker-outcomes
   Completion notes: Round 009 approved and merged the indexed PR-review reviewer outcome adapter for clean, problems-added, incomplete, blocked, verification-clean, and missing-thread verification outcomes. Reviewer evidence covered MoifoldSpec delegation, classifier-backed outputs, invalid observations, replay/apply/effect/permission parity, unchanged live daemon routing and compatibility behavior, preservation of golden/daemon/dry-run/action-ordering surfaces, plus passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

4. [done] Complete indexed mergeability and merge terminal coverage
   Item id: item-010-indexed-pr-review-mergeability-complete
   Depends on: item-009-indexed-pr-review-reviewer-outcomes
   Parallel safe: no
   Parallel group: none
   Merge after: item-009-indexed-pr-review-reviewer-outcomes
   Completion notes: Round 010 approved and merged the indexed PR-review mergeability terminal coverage for retry, recheck, fix-required, blocked, clean merge, and merge-completed observations. Reviewer evidence covered indexed blocked/complete markers, invalid observation failure parity, replay/effect/permission parity, dry-run parity, request-id preservation, clean merge pre-commit ordering, merged compatibility writes, unchanged golden/schema/daemon/action-ordering surfaces, plus passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

5. [done] Route one live PR-review daemon observation path through the indexed adapter
   Item id: item-011-indexed-pr-review-daemon-path
   Depends on: item-010-indexed-pr-review-mergeability-complete
   Parallel safe: no
   Parallel group: none
   Merge after: item-010-indexed-pr-review-mergeability-complete
   Completion notes: Round 011 approved and merged the live `PrWaitingForMergeability` plus `ObservedMergeabilityClean` daemon path through the indexed PR-review mergeability adapter while projecting back to existing moifold daemon transaction surfaces. Reviewer evidence covered unchanged daemon tick results and failure reporting, dry-run and execute parity, pre-commit merge failure handling, invalid observation parity, compatibility writes, action ordering, request-id stability, unchanged event schema/golden/facade surfaces, plus passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

6. [pending] Prepare the next-domain indexed adoption plan
   Item id: item-012-indexed-next-domain-plan
   Depends on: item-011-indexed-pr-review-daemon-path
   Parallel safe: no
   Parallel group: none
   Merge after: item-011-indexed-pr-review-daemon-path
   Completion notes: Inspect current issue-planning and issue-implementation workflow policy after PR-review indexed coverage is real. Author the next revision deciding which domain should be ported next, with concrete parity surfaces and no premature package-boundary rewrites.
