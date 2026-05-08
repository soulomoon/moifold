# Verification Contract

Roadmap id: `2026-05-07-00-workflow-kernel-indexing`
Roadmap revision: `rev-004`

## Baseline Checks

- Command: `cabal build all`
  Why: Builds every internal library, executable, and test target across the moifold package split.
- Command: `cabal test watcher-core-test`
  Why: Runs the core regression suite, including golden replay, package-boundary, workflow-facade, daemon, execution, indexed-spec, adapter, issue-planning, issue-implementation, classifier, repair, healthcheck, and fanout tests.
- Command: `git diff --check`
  Why: Catches whitespace errors before review.
- Command: `git diff --cached --check`
  Why: Required when a round stages changes before review or merge.

## Task-Specific Checks

- Add focused tests for the selected roadmap item before relying on new behavior. Artifact-only roadmap rounds must instead verify the authored roadmap, verification, and retry contracts directly.
- For every indexed IssueImplement port, prove old compatibility IssueImplement behavior and indexed IssueImplement behavior emit the same event label, source label, target label, final state label, pre-commit effect plan, post-commit effect plan, observed effects, replay result, replay effects, effect validation result, effect permission result, action ordering, request-id progression, dry-run reports, compatibility writes, and invalid-observation failures.
- Cover every `IssueImplementObservation`: `ObservedPlanTurnStarted`, `ObservedPlanCompleted`, `ObservedIssueAttemptBranchAdvanced`, `ObservedIssueWorkerThreadRefreshed`, `ObservedPullRequestCreated`, `ObservedPullRequestReused`, `ObservedPullRequestBodyUpdated`, `ObservedImplementationTurnStarted`, `ObservedImplementationIncomplete`, `ObservedImplementationBlocked`, `ObservedReviewHandoffInitialized`, `ObservedReviewHandoffStarted`, `ObservedImplementationCompleted`, `ObservedIssueReviewerThreadReady`, `ObservedPullRequestMerged`, `ObservedPostMergeReviewStarted`, `ObservedPostMergeReviewerOutcome`, `ObservedIssueClosed`, and `ObservedIssueImplementBlocked`.
- Cover every `IssueFinalReviewOutcome`: clean, rework-required, incomplete, and blocked. Preserve reviewed commit validation, reviewer prompt-version validation, required final-review fields, clean-review verification summary requirements, rework findings requirements, blocked reason behavior, and default LGTM comment behavior.
- For plan-mode and PR setup routing, preserve PR discovery, PR create/reuse parsing, existing PR link validation, merged-attempt branch advancement, branch-mismatch blocking, `issue-plan.md` recording, PR body update command rendering, PR URL compatibility writes, dry-run reports, execute report prepending, and request-id stability when no app-server action is present.
- For implementation-turn routing, preserve `StartIssueImplementationWorkerTurn`, active turn classification, structured output parsing, missing-output blocking, completed-before-known-PR incomplete behavior, stale PR mismatch blocking, restart-on-incomplete behavior, `ImplementationBlocked` stop behavior, app-server request-id progression, dry-run output, and compatibility writes.
- For review handoff and merge waiting, preserve `IssueReviewHandoffInitialized`, `IssueReviewHandoffStarted`, idempotent duplicate observations while waiting for merge, reviewer-thread-ready handling, PR merge polling through `gh pr view`, idle waiting text, wrong-PR blocking, existing reviewer reuse, daemon tick shape, detailed transaction failures, and request-id stability.
- For post-merge review and follow-up, preserve reviewer-thread creation, final-review turn starts, final-review target commit from `headRefOid`, missing `headRefOid` external failure text, final-review classifier outcomes, clean-to-close effects, rework-to-follow-up effects, follow-up branch incrementing, `UpdateIssueFollowUp`, no-close-on-rework behavior, incomplete reviewer retry, blocked reviewer stop behavior, dry-run/execute parity, compatibility writes, and detailed daemon failures.
- For issue close, preserve remote issue closed detection, `CloseIssue` before `SleepUntilNextPoll` retry behavior, idle waiting text after close command, `IssueClosedEvent`, terminal `IssueComplete` evidence, `StopDaemon`, wrong-PR close rejection, command rendering, dry-run reports, daemon result shape, and compatibility writes.
- Preserve child lifecycle and automatic-loop boundaries: issue-planning fanout launch planning, existing implementer discovery, stopped implementer restarts, terminal ready-issue completion, active-issue capacity, state-dir ownership, workdir setup commands, launch manifests, runtime-owner/PID/lock handling, healthcheck issue-implement reporting, and repair drop behavior.
- For daemon routing rounds, prove `DaemonTickResult`, `DaemonObservedTickResult`, `DaemonObservedTransactionFailure`, detailed transaction failure text, dry-run reports, action ordering, audit labels, compatibility write timing, and event append ordering remain compatible.
- For package-boundary-adjacent rounds, keep recursive boundary assertions passing: `agent-workflow-core` must not import moifold lifecycle policy, `IssueConfig`, `IssueFinalReviewOutcome`, Codex app-server transport, GitHub adapters, daemon/runtime interpreters, Aeson event codecs, concrete `WatcherEvent`, concrete `SomeWatcherState`, issue-implementer child lifecycle, or compatibility write ownership.
- Do not change event `type` fields, JSON schemas, golden fixtures, public compatibility module availability, daemon result constructors, dry-run rendering, runtime command rendering, prompt schemas, or structured-output field requirements unless a later roadmap item explicitly says so.

## Approval Criteria

- Every baseline check passes, except artifact-only planning rounds may run only artifact verification and must document why production build/test commands were not run.
- Every selected task-specific check passes.
- `selection.md` records `roadmap_id`, `roadmap_revision`, `roadmap_dir`, and `roadmap_item_id`.
- `implementation-notes.md` records changed files and verification evidence.
- `review.md` records evidence for the round.
- `review-record.json` records the same roadmap identity when the round finalizes.
- The round stays inside the active roadmap bundle recorded in `orchestrator/state.json`.
- The round's `roadmap_id` is exactly `2026-05-07-00-workflow-kernel-indexing`, not a recomputed title-derived value.
- If worker fan-out is used later, `worker-plan.json` must exist and reviewer approval must be based on the integrated round result.
- The reviewer decision is explicit.

## Reviewer Record Format

### Round `<round-id>`

- Baseline checks:
- Task-specific checks:
- Decision:
- Evidence:
