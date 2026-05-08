# Indexed Workflow Adoption Roadmap

Roadmap id: `2026-05-07-00-workflow-kernel-indexing`
Roadmap revision: `rev-003`

## Status Legend

- `pending`
- `in-progress`
- `done`

## Scope

This revision continues the workflow-kernel extraction after `rev-002` completed
indexed PR-review policy coverage and routed one live PR-review daemon path
through the indexed adapter. The next adoption domain is `IssuePlanning`.

Keep concrete moifold lifecycle policy in moifold. `agent-workflow-core`
continues to own only generic indexed workflow and transaction APIs. Do not move
`PlannerConfig`, `PlanningGraph`, `IssueCreationRequest`, `WatcherEvent`,
`SomeWatcherState`, Aeson codecs, GitHub snapshot fetching, app-server starts,
fanout launch planning, compatibility writes, daemon-loop runtime, or filesystem
writes into indexed core.

`IssuePlanning` is intentionally selected before `IssueImplement`. The planning
domain has a bounded policy surface around `PlanningReady`,
`PlanningTurnActive`, `PlanningWaitingForReadyIssues`, blocked, and complete. It
already has replay, watcher, daemon, automatic-loop, graph-normalization, scope,
and fanout tests that can anchor indexed-vs-compatibility parity.

`IssueImplement` is intentionally deferred. It has a wider side-effect surface:
PR discovery, PR creation or reuse, PR body updates, issue plan recording,
implementation worker turns, review handoff, PR merge waiting, post-merge
reviewer turns, issue follow-up updates, and issue close. That domain should be
planned from a proven `IssuePlanning` indexed shape rather than becoming the
first non-PR-review indexed port.

For every adoption slice, preserve event JSON schemas, event `type` fields,
golden logs, daemon result shapes, dry-run reports, action ordering,
request-id progression, compatibility facades, replay behavior, effect
validation, effect permissions, and compatibility writes unless a later roadmap
revision explicitly changes them.

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

6. [done] Prepare the next-domain indexed adoption plan
   Item id: item-012-indexed-next-domain-plan
   Depends on: item-011-indexed-pr-review-daemon-path
   Parallel safe: no
   Parallel group: none
   Merge after: item-011-indexed-pr-review-daemon-path
   Completion notes: Round 012 selected `IssuePlanning` as the next indexed adoption domain after PR-review indexed policy and one live daemon path were covered. `IssuePlanning` is smaller and policy-focused, with concrete parity anchors for planning start, issue creation requests, graph update and normalization, ready-issues-fixed, scope completion, retry, blocked, completed, replay, daemon dry-run/execute, graph/scope validation, and fanout boundaries. `IssueImplement` is explicitly deferred because PR lifecycle, implementation worker, review handoff, merge wait, post-merge review, issue close, and follow-up behavior form a larger side-effect surface that should be planned after the issue-planning indexed shape is proven.

7. [done] Port issue-planning policy transitions to the indexed API
   Item id: item-013-indexed-issue-planning-policy
   Depends on: item-012-indexed-next-domain-plan
   Parallel safe: no
   Parallel group: none
   Merge after: item-012-indexed-next-domain-plan
   Completion notes: Round 013 approved and merged the moifold-owned indexed issue-planning adapter in commit `e2a12a7`, covering `IssuePlanningTurnStarted`, `IssuePlanningIssuesRequested`, `IssuePlanningGraphUpdated`, `IssuePlanningReadyIssuesFixed`, `IssuePlanningScopeCompleted`, `IssuePlanningTurnRetryRequested`, `IssuePlanningTurnCompleted`, and `WatcherBlocked` policy transitions. Reviewer evidence covered graph validation success and failure cases, invalid-observation parity, replay/effect/permission/dry-run/request-id/action-ordering parity, compatibility write preservation, unchanged live daemon routing and schema/core ownership surfaces, plus passing focused indexed and issue-planning tests, `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

8. [done] Route live issue-planning daemon start through the indexed adapter
   Item id: item-014-indexed-issue-planning-daemon-start
   Depends on: item-013-indexed-issue-planning-policy
   Parallel safe: no
   Parallel group: none
   Merge after: item-013-indexed-issue-planning-policy
   Completion notes: Round 014 approved and merged the live `PlanningReady` plus `ObservedPlanningTurnStarted` daemon-start route through the moifold-owned indexed issue-planning adapter in commit `6cbb843`, then projected back to existing daemon transaction surfaces. Reviewer evidence covered planner turn start, request-id progression, dry-run and execute reports, action ordering, compatibility writes, snapshot-path preservation, invalid-observation rejection, unchanged non-start issue-planning daemon routes, and package-boundary preservation, plus passing `cabal test watcher-core-test` before and after `cabal build all`, passing `cabal build all`, clean `git diff --check`, and clean staged whitespace when committed.

9. [done] Route issue-planning graph and request daemon observations through the indexed adapter
   Item id: item-015-indexed-issue-planning-daemon-graph-and-requests
   Depends on: item-014-indexed-issue-planning-daemon-start
   Parallel safe: no
   Parallel group: none
   Merge after: item-014-indexed-issue-planning-daemon-start
   Completion notes: Round 015 approved and merged the active-turn `ObservedPlanningIssuesRequested` and normalized `ObservedPlanningGraphUpdated` daemon routes through the moifold-owned indexed issue-planning adapter in commit `98441ab`, then projected back to the existing daemon transaction surface. Reviewer evidence covered issue creation command plans, graph update recording, `planning-state.json` compatibility writes, dry-run and execute parity, action ordering, request-id behavior, wrong-source rejection, invalid graph blocked-route behavior, unchanged compatibility routing for item-016 terminal/retry observations, and package-boundary preservation, plus passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and clean staged whitespace when committed.

10. [pending] Route issue-planning terminal and retry daemon observations through the indexed adapter
    Item id: item-016-indexed-issue-planning-terminal-and-retry-daemon
    Depends on: item-015-indexed-issue-planning-daemon-graph-and-requests
    Parallel safe: no
    Parallel group: none
    Merge after: item-015-indexed-issue-planning-daemon-graph-and-requests
    Completion notes: Route retry, blocked, scope-complete, ready-issues-fixed, and completed planning observations through the indexed path. Preserve systemError retry/block behavior, missing active turn recovery, completion boundaries, `issuePlanningCompletionEvent`, ready-issues fanout boundaries, fanout completion boundary, `DaemonObservedTickResult`, detailed transaction failures, dry-run and execute parity, compatibility writes, action ordering, request-id progression, replay effects, effect validation, effect permissions, and invalid-observation failures.

11. [pending] Prepare the issue-implementation indexed adoption plan
    Item id: item-017-indexed-issue-implementation-next-domain-plan
    Depends on: item-016-indexed-issue-planning-terminal-and-retry-daemon
    Parallel safe: no
    Parallel group: none
    Merge after: item-016-indexed-issue-planning-terminal-and-retry-daemon
    Completion notes: After issue-planning indexed coverage is merged, inspect `IssueImplement` and author the next roadmap revision for plan, implementation, PR discovery/creation/reuse, PR body update, review handoff, PR merge waiting, post-merge review, issue close, and follow-up slices. Keep `IssueImplement` planning artifact-only in this item; do not start its indexed implementation until the revision is approved.
