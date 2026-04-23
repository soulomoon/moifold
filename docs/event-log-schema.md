# Event Log Schema

Watcher runtimes append newline-delimited JSON to `events.jsonl`. The Haskell replay model ignores unknown fields, so runtime metadata such as `emittedAt`, `repoFullName`, `prNumber`, and `branch` can be included on every event.

The first event must initialize exactly one watcher domain. Re-initialization is invalid.

## Issue Planning

```json
{"type":"issue_planning_initialized","repoFullName":"owner/name","maxParallel":8}
{"type":"issue_planning_turn_started","plannerThreadId":"thread-id","plannerTurnId":"turn-id"}
{"type":"issue_planning_issues_requested","issues":[{"title":"Subissue title","body":"Subissue details"}]}
{"type":"issue_planning_turn_completed"}
```

Valid replay path:

`IssuePlanning / Initialized -> PlanMode -> Initialized`

Important replay rules:

- `issue_planning_issues_requested` is emitted when the planner decides new issues or subissues must be created.
- The runtime creates those GitHub issues, records the event, and returns to `Initialized` so the next planner turn works from the refreshed issue set.
- Implementer fanout only happens after `issue_planning_turn_completed`; it does not happen immediately after issue creation.

## Issue Implementation

```json
{"type":"issue_implement_initialized","repoFullName":"owner/name","issueNumber":42,"branch":"codex/issue-42","workerThreadId":"thread-id"}
{"type":"issue_pr_created","prNumber":7,"prUrl":"https://github.com/owner/name/pull/7"}
{"type":"issue_pr_reused","prNumber":7,"prUrl":"https://github.com/owner/name/pull/7"}
{"type":"issue_plan_turn_started","planTurnId":"turn-plan"}
{"type":"issue_plan_completed"}
{"type":"issue_pr_body_updated","prNumber":7}
{"type":"issue_implementation_turn_started","implementationTurnId":"turn-implementation"}
{"type":"issue_implementation_incomplete","reason":"worker marked implementation incomplete"}
{"type":"issue_implementation_blocked","reason":"human-readable blocker"}
{"type":"issue_implementation_completed","prNumber":7}
{"type":"issue_review_handoff_initialized","prNumber":7}
{"type":"issue_review_handoff_started","prNumber":7}
{"type":"issue_pr_merged","prNumber":7}
{"type":"issue_closed","prNumber":7}
```

Valid replay path:

`IssueImplement / Implementing setup -> PlanMode -> Implementing -> handoff-ready -> waiting for PR merge -> waiting for issue close -> Complete`

Compatibility notes:

- `issue_pr_created` or `issue_pr_reused` moves the implementer from PR setup into `PlanMode` and writes `issue_status: "ready_to_plan"`.
- `issue_plan_turn_started` writes `issue_status: "planning"`.
- `issue_plan_completed` writes `issue_status: "plan_ready"` and may include `implementationTurnId`; when present, replay remembers that worker thread for the later implementation turn.
- After planning, the runtime must emit `issue_pr_body_updated` before any implementation turn starts. The runtime verifies `issue-plan.md` is present and non-empty before committing `issue_plan_completed`.

Important replay rules:

- `issue_implement_initialized` starts in PR setup; there is no triage turn.
- `issue_pr_created` or `issue_pr_reused` must occur before `issue_plan_turn_started`.
- `issue_plan_completed` must occur before `issue_pr_body_updated`.
- `issue_review_handoff_initialized` and `issue_review_handoff_started` are only valid after `issue_implementation_completed`; they cannot bypass an implementation turn.
- `issue_implementation_incomplete` returns to implementation-ready and emits a worker-start effect; it is not a blocked state.
- `issue_implementation_blocked` moves to `Blocked`.
- `issue_implementation_completed` only records that the implementation worker finished and the PR is ready to hand off, not that the issue is done.
- Review handoff events move the implementer into the PR lifecycle.
- `issue_pr_merged` moves the implementer to a non-terminal issue-close wait state and emits the GitHub issue close effect.
- `issue_closed` is the single terminal fact for an implemented issue; only then does the implementer move to `Complete`.

## PR Review

```json
{"type":"pr_review_initialized","repoFullName":"owner/name","prNumber":6,"branch":"branch-name","workerThreadId":"worker-thread","reviewerThreadId":"reviewer-thread"}
{"type":"pr_review_unresolved_found","reviewThreadIds":["thread-id"],"commitSha":"head-sha","workerTurnId":"turn-id"}
{"type":"pr_review_fix_completed"}
{"type":"pr_review_fix_incomplete","reason":"worker marked completion_status incomplete"}
{"type":"pr_review_no_unresolved_found","commitSha":"head-sha","reviewerTurnId":"turn-id"}
{"type":"pr_review_clean_found","commitSha":"head-sha","comment":"LGTM"}
{"type":"pr_review_mergeability_waiting","reason":"pre-merge merge state is UNSTABLE"}
{"type":"pr_review_mergeability_recheck","reason":"pre-merge found unresolved review threads"}
{"type":"pr_review_mergeability_clean","commitSha":"head-sha"}
{"type":"pr_review_problems_added","commitSha":"head-sha"}
{"type":"pr_review_review_incomplete","reason":"reviewer state missing required fields"}
{"type":"pr_review_merge_completed","mergeCommitSha":"merge-sha"}
```

Important replay rules:

- `pr_review_unresolved_found` starts a worker repair turn.
- `pr_review_fix_completed` and `pr_review_fix_incomplete` both return to `CheckingReviews`; incomplete means the runtime should immediately re-check instead of sleeping.
- `pr_review_no_unresolved_found` starts a reviewer turn.
- `pr_review_clean_found` moves to `WaitingMergeability`; the watcher does not merge until a later pre-merge check emits `pr_review_mergeability_clean`.
- `pr_review_mergeability_waiting` stays in `WaitingMergeability` and sleeps; use it for retryable GitHub states such as `UNSTABLE`, unknown mergeability, or pending checks.
- `pr_review_mergeability_recheck` returns to `CheckingReviews`; use it when the reviewed head changed or review threads reappeared.
- `pr_review_mergeability_clean` moves to `Merging`.
- `pr_review_problems_added` and `pr_review_review_incomplete` both return to `CheckingReviews`.
- `pr_review_merge_completed` moves to `Complete`.

## Terminal Events

```json
{"type":"watcher_blocked","reason":"human-readable blocker"}
{"type":"watcher_stopped","reason":"human-readable stop reason"}
```

Terminal events can be emitted by any watcher domain. After `Blocked`, `Complete`, or `Stopped`, only `watcher_stopped` is accepted by replay.
