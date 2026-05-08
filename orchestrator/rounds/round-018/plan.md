### Goal
Add a moifold-owned indexed IssueImplement policy adapter and focused parity coverage for the current compatibility policy surface, without routing any live daemon path through the new adapter.

The round should leave concrete IssueImplement lifecycle policy in moifold, keep `agent-workflow-core` generic, and preserve existing event JSON schemas, event `type` fields, golden fixtures, daemon result shapes, dry-run text, compatibility writes, action ordering, and request-id progression.

### Approach
Implement the adapter as a compatibility-preserving indexed wrapper around the existing moifold policy functions, following the established `CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed` and PR-review indexed modules. The new module should live at `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs` and be exposed from `moifold.cabal`.

Use indexed phantom markers for the IssueImplement policy points that matter to this slice: ready-to-plan, active plan mode, plan ready, implementation ready, implementing, handoff ready, handoff initialized, waiting for PR merge, post-merge reviewer pending, post-merge reviewer ready, post-merge reviewing, waiting for issue close, blocked, and complete. The underlying indexed state remains `SomeWatcherState`; event, observation, effect, effect-plan, and replay wrappers delegate to `MoifoldSpec`, preserving compatibility labels and behavior.

Add projection helpers for every currently accepted `IssueImplementObservation` source case, not just one helper per constructor. Several observations are valid from multiple source states today, and the plan must preserve those idempotent or compatibility routes:

- `ObservedPlanTurnStarted` from `IssueReadyToPlan`.
- `ObservedPlanCompleted` from `IssueInPlanMode`.
- `ObservedIssueAttemptBranchAdvanced` from `IssueImplementationReady`.
- `ObservedIssueWorkerThreadRefreshed` from `IssueReadyToPlan`, `IssuePlanReady`, and `IssueImplementationReady`.
- `ObservedPullRequestCreated` and `ObservedPullRequestReused` from `IssueImplementationReady` and `IssueImplementing`.
- `ObservedPullRequestBodyUpdated` from `IssuePlanReady`, `IssueImplementationReady`, and `IssueImplementing`.
- `ObservedImplementationTurnStarted` from `IssueImplementationReady`.
- `ObservedImplementationIncomplete` from `IssueImplementing`.
- `ObservedImplementationBlocked` from `IssueImplementationReady` and `IssueImplementing`.
- `ObservedReviewHandoffInitialized` from `IssueHandoffReady`, `IssueHandoffInitialized`, and `IssueWaitingForPrMerge`.
- `ObservedReviewHandoffStarted` from `IssueHandoffInitialized` and `IssueWaitingForPrMerge`.
- `ObservedImplementationCompleted` from `IssueImplementing`, `IssueHandoffReady`, `IssueHandoffInitialized`, and `IssueWaitingForPrMerge`, including stale-PR blocked behavior.
- `ObservedIssueReviewerThreadReady` from handoff-ready, handoff-initialized, waiting-for-merge, post-merge-pending-reviewer, and post-merge-review-ready states.
- `ObservedPullRequestMerged` from `IssueWaitingForPrMerge`, plus the existing ignored-merge observations from implementation-ready, implementing, handoff-ready, handoff-initialized, post-merge-pending-reviewer, post-merge-review-ready, post-merge-reviewing, and waiting-for-issue-close.
- `ObservedPostMergeReviewStarted` from `IssuePostMergeReviewReady`, and the existing invalid failure from `IssuePostMergeReviewPendingReviewer`.
- `ObservedPostMergeReviewerOutcome` for clean, rework-required, incomplete, and blocked outcomes.
- `ObservedIssueClosed` from `IssueWaitingForIssueClose`.
- `ObservedIssueImplementBlocked` from every currently accepted non-terminal IssueImplement state.

Do not import or move `IssueConfig`, `IssueFinalReviewOutcome`, concrete watcher states/events, Aeson codecs, GitHub execution, app-server transport, compatibility write ownership, or issue-implementer child lifecycle into `agent-workflow-core`.

### Steps
1. Add `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed` with the same wrapper shape as the existing indexed moifold adapters: indexed state/event/observation/tick/effect/effect-plan/replay types, `IssueImplementIndexedSpec`, `issueImplementIndexedSomeEvent`, and `issueImplementIndexedTransitionToCompatibility`.
2. Define an `IssueImplementIndexedProjection` record carrying the compatibility `PlannedTransition MoifoldSpec`, final `SomeWatcherState`, source label, target label, and full effect plan. Add a shared `projectIssueImplementObservation` helper that calls `indexedWorkflowObserve`, `indexedWorkflowPlanObservation`, converts the indexed transition back to the compatibility transition, and exposes the final observed state.
3. Add typed projection helpers for the accepted observation/source-state matrix above. For observations whose target depends on compatibility policy, such as stale PR mismatches, ignored merged PRs, and final-review outcomes, branch by the compatibility-observed event/final state and then choose the indexed source/target marker that matches the existing result.
4. Expose the new module in `moifold.cabal`. Do not import it from live daemon modules, `CodexWatcher.Domain.IssueImplement.Loop`, `CodexWatcher.DaemonLoop`, or automatic-loop routing code in this round.
5. Extend `test/Main.hs` imports and add an IssueImplement parity helper analogous to `issuePlanningIndexedSpecMatchesCompatibility`. It should compare facade `issueImplementObserve`, `workflowObserve`, `workflowPlanObservation`, indexed observe/plan, compatibility apply, indexed apply, compatibility replay, indexed replay, source/target/final labels, event labels, pre/post effect labels, replay effects, effect validation, effect permission, compiled action ordering, dry-run text, request-id progression, and `compatibilityStateWrites`.
6. Build explicit test fixtures for the IssueImplement source states and replay prefixes, reusing existing sample values such as `sampleIssuePlanMarkdown`, `CleanReviewEvidence`, `ReviewEvidence`, `IssueConfig`, `PrNumber`, `ThreadId`, `TurnId`, and `CommitSha`.
7. Add focused tests covering all accepted observation/source-state cases listed in Approach. The assertions should pin the important effects: start plan worker, record issue plan, create/reuse PR sleep behavior, PR body update compatibility writes, start implementation worker, implementation restart on incomplete, blocked stop effects, handoff idempotence, reviewer-thread readiness, PR merge to post-merge-review states, clean-to-close, rework-to-follow-up, incomplete-review retry, issue close stop, ignored merged PR sleep, stale/wrong PR blocked behavior, and blocked observations from each accepted source state.
8. Add invalid-observation parity tests where current compatibility rejects or blocks: plan start from an active plan state, implementation completion before an implementation turn, post-merge review start without a reviewer thread, wrong PR body update/completion/handoff/close observations, and representative observations from terminal or wrong-domain states. The indexed adapter must return the same failure text or blocked transition behavior as compatibility.
9. Add a source-scan regression that live daemon routing remains untouched for this item. It should assert no `CodexWatcher.Domain.IssueImplement.Loop`, `CodexWatcher.DaemonLoop`, or automatic-loop module imports or calls the new indexed IssueImplement module or projection helpers.
10. Run the focused watcher test target first, then the roadmap baseline checks. If failures require narrowing, rerun with the exact focused matcher for the new IssueImplement indexed tests before running the full baseline again.

### Verification
Run these commands before review:

- `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement'`
- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` if any changes are staged

The review evidence should explicitly record:

- Every `IssueImplementObservation` constructor is covered, including the multi-source compatibility cases.
- Every `IssueFinalReviewOutcome` constructor is covered: clean, rework-required, incomplete, and blocked.
- Indexed and compatibility paths match for event label, source label, target label, final state label, pre/post effect plans, replay state/effects, effect validation, effect permission, compatibility writes, dry-run text, action ordering, and request-id behavior.
- Invalid observations either fail or block exactly like the compatibility path.
- Live IssueImplement daemon routing remains unchanged.
- `agent-workflow-core` did not gain moifold lifecycle policy, concrete watcher states/events, `IssueConfig`, `IssueFinalReviewOutcome`, app-server transport, GitHub execution, daemon runtime, Aeson event codecs, compatibility writes, or child lifecycle ownership.
