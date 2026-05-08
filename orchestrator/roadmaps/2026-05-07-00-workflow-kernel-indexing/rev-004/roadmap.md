# Indexed Workflow Adoption Roadmap

Roadmap id: `2026-05-07-00-workflow-kernel-indexing`
Roadmap revision: `rev-004`

## Status Legend

- `pending`
- `in-progress`
- `done`

## Scope

This revision continues the workflow-kernel extraction after `rev-003`
completed indexed IssuePlanning policy and live daemon routing. The next
adoption domain is `IssueImplement`.

Keep concrete moifold lifecycle policy in moifold. `agent-workflow-core`
continues to own only generic indexed workflow and transaction APIs. Do not move
`IssueConfig`, `IssueFinalReviewOutcome`, `WatcherEvent`, `SomeWatcherState`,
Aeson event codecs, GitHub command execution, app-server starts, daemon-loop
runtime, issue-implementer child lifecycle, healthcheck/runtime ownership,
compatibility writes, filesystem writes, PR body rendering, or issue-plan file
ownership into indexed core.

`IssueImplement` is intentionally split more finely than IssuePlanning. Its
side-effect surface spans issue plan turns, PR discovery, PR creation or reuse,
attempt-branch advancement, PR body updates, issue plan recording,
implementation worker turns, review handoff, PR merge waiting, post-merge
reviewer turns, follow-up branch and issue updates, issue close, and child
lifecycle reporting. Future rounds should port these slices in dependency
order, proving indexed-vs-compatibility parity before live daemon routing expands
to the next slice.

For every adoption slice, preserve event JSON schemas, event `type` fields,
golden logs, daemon result shapes, detailed transaction failures, dry-run
reports, runtime command rendering, action ordering, request-id progression,
compatibility facades, compatibility writes, replay behavior, effect validation,
effect permissions, and compatibility writes unless a later roadmap revision
explicitly changes them.

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

10. [done] Route issue-planning terminal and retry daemon observations through the indexed adapter
    Item id: item-016-indexed-issue-planning-terminal-and-retry-daemon
    Depends on: item-015-indexed-issue-planning-daemon-graph-and-requests
    Parallel safe: no
    Parallel group: none
    Merge after: item-015-indexed-issue-planning-daemon-graph-and-requests
    Completion notes: Round 016 approved and merged the remaining issue-planning ready-issues-fixed, scope-completed, retry, turn-completed, and blocked daemon/fanout observations through the moifold-owned indexed issue-planning adapter in commit `f716838`, then projected back to the existing daemon transaction surfaces. Reviewer evidence covered systemError retry/block behavior, missing active turn recovery, completion and fanout boundaries, `issuePlanningCompletionEvent` preservation, `DaemonObservedTickResult`, detailed transaction failures, dry-run and execute parity, compatibility writes, action ordering, request-id progression, replay/effect validation/effect permission parity, invalid-observation failures, unchanged golden surfaces, and package-boundary preservation, plus passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`, and an `agent-workflow-core` boundary scan.

11. [done] Prepare the issue-implementation indexed adoption plan
    Item id: item-017-indexed-issue-implementation-next-domain-plan
    Depends on: item-016-indexed-issue-planning-terminal-and-retry-daemon
    Parallel safe: no
    Parallel group: none
    Merge after: item-016-indexed-issue-planning-terminal-and-retry-daemon
    Completion notes: Round 017 inspected current `IssueImplement` policy, daemon, automatic-loop, and test surfaces and authored `rev-004` as an artifact-only IssueImplement indexed adoption plan. Indexed IssueImplement implementation remains deferred until this revision is approved.

12. [pending] Port IssueImplement policy transitions to the indexed API
    Item id: item-018-indexed-issue-implementation-policy
    Depends on: item-017-indexed-issue-implementation-next-domain-plan
    Parallel safe: no
    Parallel group: none
    Merge after: item-017-indexed-issue-implementation-next-domain-plan
    Completion notes: Add a moifold-owned indexed IssueImplement adapter, likely `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed`, covering the full compatibility policy surface without changing live daemon routing. Cover `ObservedPlanTurnStarted`, `ObservedPlanCompleted`, `ObservedIssueAttemptBranchAdvanced`, `ObservedIssueWorkerThreadRefreshed`, `ObservedPullRequestCreated`, `ObservedPullRequestReused`, `ObservedPullRequestBodyUpdated`, `ObservedImplementationTurnStarted`, `ObservedImplementationIncomplete`, `ObservedImplementationBlocked`, `ObservedReviewHandoffInitialized`, `ObservedReviewHandoffStarted`, `ObservedImplementationCompleted`, `ObservedIssueReviewerThreadReady`, `ObservedPullRequestMerged`, `ObservedPostMergeReviewStarted`, `ObservedPostMergeReviewerOutcome`, `ObservedIssueClosed`, and `ObservedIssueImplementBlocked`. Prove indexed-vs-compatibility parity for source labels, target labels, final state labels, event labels, pre/post effect plans, replay effects, effect validation, effect permission, invalid observations, compatibility writes, and request-id/action-ordering behavior. Do not route live daemon paths in this item.

13. [pending] Route IssueImplement plan-mode and PR setup daemon observations through indexed projection
    Item id: item-019-indexed-issue-implementation-plan-and-pr-setup-daemon
    Depends on: item-018-indexed-issue-implementation-policy
    Parallel safe: no
    Parallel group: none
    Merge after: item-018-indexed-issue-implementation-policy
    Completion notes: Route live daemon observations for plan turn start/completion, worker refresh after follow-up, attempt-branch advancement, PR create/reuse, and PR body update through the indexed IssueImplement adapter after existing classifiers and GitHub/command probes produce compatibility observations. Preserve `runIssueReadyToPlan`, `runIssuePlanActive`, `runIssuePlanReady`, `observeExistingPullRequest`, `advanceMergedAttemptBranchOrCreatePullRequest`, `retryCreatePullRequest`, and `updatePullRequestBody` behavior: PR discovery remains in moifold, branch advancement rules remain unchanged, `issue-plan.md` is recorded before PR body update, PR URL compatibility writes remain stable, command result parsing remains unchanged, dry-run reports remain text-compatible, and no implementation-turn or handoff daemon routes are added yet.

14. [pending] Route IssueImplement implementation-turn daemon observations through indexed projection
    Item id: item-020-indexed-issue-implementation-worker-daemon
    Depends on: item-019-indexed-issue-implementation-plan-and-pr-setup-daemon
    Parallel safe: no
    Parallel group: none
    Merge after: item-019-indexed-issue-implementation-plan-and-pr-setup-daemon
    Completion notes: Route live `IssueImplementationReady` and `IssueImplementing` daemon observations through indexed projection for implementation turn start, incomplete, blocked, completed, and worker refresh behavior. Preserve `StartIssueImplementationWorkerTurn`, active-turn classification, structured output parsing, missing-output blocking, completed-before-known-PR incomplete behavior, stale PR mismatch blocking, restart-on-incomplete behavior, app-server request-id progression, dry-run output, and compatibility writes. Do not route review handoff, PR merge wait, post-merge review, follow-up, or issue close in this item.

15. [pending] Route IssueImplement review handoff and PR merge-wait daemon observations through indexed projection
    Item id: item-021-indexed-issue-implementation-handoff-and-merge-wait-daemon
    Depends on: item-020-indexed-issue-implementation-worker-daemon
    Parallel safe: no
    Parallel group: none
    Merge after: item-020-indexed-issue-implementation-worker-daemon
    Completion notes: Route handoff-ready, handoff-initialized, waiting-for-PR-merge, and reviewer-thread-ready observations through indexed projection. Preserve `ObservedReviewHandoffInitialized`, `ObservedReviewHandoffStarted`, `ObservedImplementationCompleted` idempotence after handoff, `ObservedIssueReviewerThreadReady`, `ObservedPullRequestMerged`, PR merge polling through `gh pr view`, idle waiting text, wrong-PR blocking, existing reviewer reuse, `DaemonObservedTickResult` shape, detailed transaction failures, action ordering, compatibility writes, and request-id stability. Do not route post-merge reviewer start/outcomes, issue close, or follow-up in this item.

16. [pending] Route IssueImplement post-merge review and follow-up daemon observations through indexed projection
    Item id: item-022-indexed-issue-implementation-post-merge-review-daemon
    Depends on: item-021-indexed-issue-implementation-handoff-and-merge-wait-daemon
    Parallel safe: no
    Parallel group: none
    Merge after: item-021-indexed-issue-implementation-handoff-and-merge-wait-daemon
    Completion notes: Route post-merge reviewer thread creation, final-review turn start, final-review classification, clean, rework-required, incomplete, and blocked outcomes through indexed projection. Preserve `runIssuePostMergeReviewPendingReviewer`, `runIssuePostMergeReviewReady`, `runIssuePostMergeReviewing`, `IssueFinalReviewOutcome`, final reviewer prompt/version validation, reviewed-commit validation, missing-field diagnostics, reviewer-thread app-server starts, clean-to-close behavior, rework-to-follow-up behavior, follow-up branch incrementing, `UpdateIssueFollowUp` effects, no-close-on-rework behavior, dry-run/execute parity, compatibility writes, and detailed daemon failures. Do not route terminal issue close in this item.

17. [pending] Route IssueImplement issue-close terminal daemon observations through indexed projection
    Item id: item-023-indexed-issue-implementation-close-daemon
    Depends on: item-022-indexed-issue-implementation-post-merge-review-daemon
    Parallel safe: no
    Parallel group: none
    Merge after: item-022-indexed-issue-implementation-post-merge-review-daemon
    Completion notes: Route issue close polling and terminal close observation through indexed projection. Preserve `runIssueWaitingForIssueClose`, `retryCloseIssue`, `ObservedIssueClosed`, `CloseIssue` before `SleepUntilNextPoll` retry behavior, remote issue closed detection, idle waiting text after close command, terminal `IssueComplete` evidence, `StopDaemon`, compatibility writes, daemon result shape, dry-run text, command rendering, and wrong-PR close rejection. Do not change GitHub close semantics or issue terminal success criteria.

18. [pending] Harden IssueImplement lifecycle, repair, and child ownership after full indexed routing
    Item id: item-024-indexed-issue-implementation-lifecycle-hardening
    Depends on: item-023-indexed-issue-implementation-close-daemon
    Parallel safe: no
    Parallel group: none
    Merge after: item-023-indexed-issue-implementation-close-daemon
    Completion notes: After all live IssueImplement daemon observations are indexed-routed, audit and harden the remaining lifecycle surfaces that depend on IssueImplement terminal and compatibility behavior: issue-implementer child launch manifests, runtime status, healthcheck, repair commands, stale/completed child detection, dry-run launch output, and compatibility facade availability. Preserve moifold ownership of child process lifecycle, state directories, runtime-owner files, PID/lock handling, `issue-state.json`, `events.jsonl`, repair drop behavior, terminal success detection, and issue-planning fanout boundaries. This item may remove dead compatibility-only routing code only after tests prove no event schema, daemon result shape, dry-run rendering, compatibility write, or lifecycle behavior changed.
