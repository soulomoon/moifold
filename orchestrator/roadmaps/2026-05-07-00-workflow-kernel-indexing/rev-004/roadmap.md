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

12. [done] Port IssueImplement policy transitions to the indexed API
    Item id: item-018-indexed-issue-implementation-policy
    Depends on: item-017-indexed-issue-implementation-next-domain-plan
    Parallel safe: no
    Parallel group: none
    Merge after: item-017-indexed-issue-implementation-next-domain-plan
    Completion notes: Round 018 approved and merged the moifold-owned indexed IssueImplement policy adapter in commit `9f34a40`, exposing `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed` while keeping live daemon routing unchanged. Reviewer evidence covered the accepted observation/source-state matrix, invalid and blocking cases, ignored merged-PR replay/compatibility alignment, waiting-for-merge reviewer-present versus pending-reviewer projection, indexed-vs-compatibility parity for labels, events, effects, replay, validation, permissions, compatibility writes, dry-run text, request-id progression, and action ordering, plus unchanged `agent-workflow-core` ownership. Verification passed the focused indexed IssueImplement watcher-core test, full `cabal test watcher-core-test`, `cabal build all`, and `git diff --check`; staged whitespace check was not applicable because no files were staged.

13. [done] Route IssueImplement plan-mode and PR setup daemon observations through indexed projection
    Item id: item-019-indexed-issue-implementation-plan-and-pr-setup-daemon
    Depends on: item-018-indexed-issue-implementation-policy
    Parallel safe: no
    Parallel group: none
    Merge after: item-018-indexed-issue-implementation-policy
    Completion notes: Round 019 approved and merged the live IssueImplement plan-mode and PR setup daemon route through the moifold-owned indexed projection in commit `9b86b52`, covering plan turn start, plan completion, follow-up worker refresh, attempt-branch advancement, PR created, PR reused, and PR body updated observations. Reviewer evidence covered dry-run and execute daemon parity against compatibility and indexed projections, preservation of PR discovery, branch advancement, GitHub command parsing, issue-plan recording before PR body update, PR URL compatibility writes, dry-run text, action ordering, event append ordering, request-id behavior, daemon transaction/result surfaces, unchanged golden/schema/facade surfaces, source-scan guards keeping item-020+ routes on compatibility fallback, and package-boundary preservation, plus passing `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and manual source scans; staged whitespace check was not applicable because no files were staged.

14. [done] Route IssueImplement implementation-turn daemon observations through indexed projection
    Item id: item-020-indexed-issue-implementation-worker-daemon
    Depends on: item-019-indexed-issue-implementation-plan-and-pr-setup-daemon
    Parallel safe: no
    Parallel group: none
    Merge after: item-019-indexed-issue-implementation-plan-and-pr-setup-daemon
    Completion notes: Round 020 approved and merged the live `IssueImplementationReady` and `IssueImplementing` daemon routes for implementation-worker behavior through the moifold-owned indexed IssueImplement projection in commit `78e3100`, then projected back to the existing daemon transaction surface. Reviewer evidence covered worker refresh, implementation turn start, incomplete restart, blocked-from-ready, blocked-from-implementing, completed with or without reviewer thread, active-turn classification, structured-output handling, missing-output blocking, completed-before-known-PR incomplete behavior, stale PR blocking, dry-run and execute parity, request-id progression, compatibility writes, source-scan guards keeping item-021+ routes on compatibility fallback, and package-boundary preservation, plus passing focused IssueImplement daemon and automatic implementation tests, full `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and staged whitespace check with no staged changes.

15. [done] Route IssueImplement review handoff and PR merge-wait daemon observations through indexed projection
    Item id: item-021-indexed-issue-implementation-handoff-and-merge-wait-daemon
    Depends on: item-020-indexed-issue-implementation-worker-daemon
    Parallel safe: no
    Parallel group: none
    Merge after: item-020-indexed-issue-implementation-worker-daemon
    Completion notes: Round 021 approved and merged the live IssueImplement review-handoff, reviewer-thread-ready, idempotent completion-after-handoff, and waiting-for-PR-merge daemon routes through the moifold-owned indexed IssueImplement projection in commit `758cfe4`, then projected back to the existing daemon transaction surface. Reviewer evidence covered `ObservedReviewHandoffInitialized`, `ObservedReviewHandoffStarted`, `ObservedImplementationCompleted` idempotence after handoff and merge-wait, `ObservedIssueReviewerThreadReady`, `ObservedPullRequestMerged`, PR merge polling through `gh pr view`, idle waiting text, wrong-PR blocking, existing reviewer reuse, `DaemonObservedTickResult` shape, detailed transaction failures, action ordering, compatibility writes, event append ordering, request-id stability, source-scan guards keeping item-022+ routes on compatibility fallback, and package-boundary preservation, plus passing focused indexed IssueImplement tests, full `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and staged whitespace check with no staged changes.

16. [done] Route IssueImplement post-merge review and follow-up daemon observations through indexed projection
    Item id: item-022-indexed-issue-implementation-post-merge-review-daemon
    Depends on: item-021-indexed-issue-implementation-handoff-and-merge-wait-daemon
    Parallel safe: no
    Parallel group: none
    Merge after: item-021-indexed-issue-implementation-handoff-and-merge-wait-daemon
    Completion notes: Round 022 approved and merged the live IssueImplement post-merge final-review turn start and clean, rework-required, incomplete, and blocked final-review outcome routes through the moifold-owned indexed IssueImplement projection in commit `5254194`, then projected back to the existing daemon transaction surface. Reviewer evidence covered dry-run and execute parity, event and planned-effect parity, request-id behavior, compatibility writes, append ordering, replay source state, final labels, domain ownership for `IssueFinalReviewOutcome`, prompt/version validation, reviewed-commit validation, missing-field diagnostics, source-scan guards keeping item-023 issue-close routes on compatibility fallback, and package-boundary preservation, plus passing focused indexed daemon, automatic merge/final-review, turn-classifier, full watcher-core, build, and whitespace checks with no staged changes.

17. [done] Route IssueImplement issue-close terminal daemon observations through indexed projection
    Item id: item-023-indexed-issue-implementation-close-daemon
    Depends on: item-022-indexed-issue-implementation-post-merge-review-daemon
    Parallel safe: no
    Parallel group: none
    Merge after: item-022-indexed-issue-implementation-post-merge-review-daemon
    Completion notes: Round 023 approved and merged the live `IssueWaitingForIssueClose` plus `ObservedIssueClosed` daemon route through the moifold-owned indexed IssueImplement projection in commit `b712ce2`, then projected back to the existing daemon transaction surface. Reviewer evidence covered close polling and retry ownership preservation, `CloseIssue` before `SleepUntilNextPoll`, remote closed detection, wrong-PR close rejection, dry-run and execute parity, idle waiting text, terminal `IssueComplete` evidence, `StopDaemon`, compatibility writes, request-id behavior, source-scan guards keeping item-024 lifecycle routes untouched, and package-boundary preservation, plus passing full watcher-core, build, whitespace, and staged-whitespace checks with no staged changes.

18. [pending] Harden IssueImplement lifecycle, repair, and child ownership after full indexed routing
    Item id: item-024-indexed-issue-implementation-lifecycle-hardening
    Depends on: item-023-indexed-issue-implementation-close-daemon
    Parallel safe: no
    Parallel group: none
    Merge after: item-023-indexed-issue-implementation-close-daemon
    Completion notes: After all live IssueImplement daemon observations are indexed-routed, audit and harden the remaining lifecycle surfaces that depend on IssueImplement terminal and compatibility behavior: issue-implementer child launch manifests, runtime status, healthcheck, repair commands, stale/completed child detection, dry-run launch output, and compatibility facade availability. Preserve moifold ownership of child process lifecycle, state directories, runtime-owner files, PID/lock handling, `issue-state.json`, `events.jsonl`, repair drop behavior, terminal success detection, and issue-planning fanout boundaries. This item may remove dead compatibility-only routing code only after tests prove no event schema, daemon result shape, dry-run rendering, compatibility write, or lifecycle behavior changed.
