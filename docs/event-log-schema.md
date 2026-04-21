# Event Log Schema

Watcher runtimes append newline-delimited JSON to `events.jsonl`. The Haskell replay model ignores unknown fields, so runtime metadata such as `emittedAt`, `repoFullName`, `prNumber`, and `branch` can be included on every event.

The first event must initialize exactly one watcher domain. Re-initialization is invalid.

## Issue Planning

```json
{"type":"issue_planning_initialized","repoFullName":"owner/name","maxParallel":8}
{"type":"issue_planning_turn_started","plannerThreadId":"thread-id","plannerTurnId":"turn-id"}
{"type":"issue_planning_turn_completed"}
```

Valid replay path:

`IssuePlanning / Initialized -> PlanMode -> Initialized`

## Issue Implementation

```json
{"type":"issue_implement_initialized","repoFullName":"owner/name","issueNumber":42,"branch":"codex/issue-42","workerThreadId":"thread-id"}
{"type":"issue_triage_turn_started","triageTurnId":"turn-triage"}
{"type":"issue_triage_already_fixed","evidence":"already fixed on base branch"}
{"type":"issue_triage_needs_implementation"}
{"type":"issue_triage_blocked","reason":"missing reproduction"}
{"type":"issue_plan_turn_started","planTurnId":"turn-plan"}
{"type":"issue_plan_completed"}
{"type":"issue_pr_created","prNumber":7,"prUrl":"https://github.com/owner/name/pull/7"}
{"type":"issue_pr_reused","prNumber":7,"prUrl":"https://github.com/owner/name/pull/7"}
{"type":"issue_implementation_turn_started","implementationTurnId":"turn-implementation"}
{"type":"issue_implementation_incomplete","reason":"worker marked implementation incomplete"}
{"type":"issue_implementation_blocked","reason":"human-readable blocker"}
{"type":"issue_review_handoff_initialized","prNumber":7}
{"type":"issue_review_handoff_started","prNumber":7}
{"type":"issue_implementation_completed","prNumber":7}
```

Valid replay path:

`IssueImplement / Triage -> PlanMode -> Implementing -> Complete`

Compatibility notes:

- `issue_start_plan_mode` is accepted as a legacy alias for `issue_plan_turn_started`.
- `issue_plan_completed` may include legacy `implementationTurnId`; when present, replay starts the first implementation turn immediately.
- Without `implementationTurnId`, `issue_plan_completed` moves to implementation-ready and emits effects to push the branch and create or reuse a PR before any implementation turn starts.

Important replay rules:

- `issue_triage_already_fixed` moves directly to `Complete`.
- `issue_triage_needs_implementation` moves to `PlanMode`; implementation cannot start before a plan event.
- `issue_plan_completed` must occur before `issue_pr_created` or `issue_pr_reused`.
- `issue_implementation_incomplete` returns to implementation-ready and emits a worker-start effect; it is not a blocked state.
- `issue_implementation_blocked` moves to `Blocked`.
- Review handoff events are accepted before final `issue_implementation_completed` so the issue watcher only completes after PR review handoff has been initialized and started.

## PR Review

```json
{"type":"pr_review_initialized","repoFullName":"owner/name","prNumber":6,"branch":"branch-name","workerThreadId":"worker-thread","reviewerThreadId":"reviewer-thread"}
{"type":"pr_review_unresolved_found","reviewThreadIds":["thread-id"],"commitSha":"head-sha","workerTurnId":"turn-id"}
{"type":"pr_review_fix_completed"}
{"type":"pr_review_fix_incomplete","reason":"worker marked completion_status incomplete"}
{"type":"pr_review_no_unresolved_found","commitSha":"head-sha","reviewerTurnId":"turn-id"}
{"type":"pr_review_clean_found","commitSha":"head-sha","comment":"LGTM"}
{"type":"pr_review_problems_added","commitSha":"head-sha"}
{"type":"pr_review_review_incomplete","reason":"reviewer state missing required fields"}
{"type":"pr_review_merge_completed","mergeCommitSha":"merge-sha"}
```

Important replay rules:

- `pr_review_unresolved_found` starts a worker repair turn.
- `pr_review_fix_completed` and `pr_review_fix_incomplete` both return to `CheckingReviews`; incomplete means the runtime should immediately re-check instead of sleeping.
- `pr_review_no_unresolved_found` starts a reviewer turn.
- `pr_review_clean_found` moves to `Merging`.
- `pr_review_problems_added` and `pr_review_review_incomplete` both return to `CheckingReviews`.
- `pr_review_merge_completed` moves to `Complete`.

## Terminal Events

```json
{"type":"watcher_blocked","reason":"human-readable blocker"}
{"type":"watcher_stopped","reason":"human-readable stop reason"}
```

Terminal events can be emitted by any watcher domain. After `Blocked`, `Complete`, or `Stopped`, only `watcher_stopped` is accepted by replay.
