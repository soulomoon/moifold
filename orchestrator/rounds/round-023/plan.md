### Goal
Route the live IssueImplement issue-close terminal daemon observation for item 023 through the existing moifold-owned indexed IssueImplement projection, while preserving the current close polling, retry, terminal success, and daemon result behavior.

This round covers `IssueWaitingForIssueClose` plus `ObservedIssueClosed`, including wrong-PR close rejection through the indexed projection. It must not change GitHub close semantics, issue terminal success criteria, issue-implementer child lifecycle, repair, healthcheck, fanout, or lifecycle hardening behavior.

### Approach
Keep `runIssueWaitingForIssueClose` and `retryCloseIssue` in `src/CodexWatcher/Domain/IssueImplement/Loop.hs` as the owners of remote issue polling and close retry effects. The only live routing change should be in `src/CodexWatcher/Daemon.hs`: when the replayed state is `IssueWaitingForIssueClose` and the observation is `ObservedIssueClosed prNumber`, prepare the daemon transaction with `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed.projectIssueImplementIssueClosedObservation`, then project back to the existing `PreparedDaemonObservation` shape via `preparedFromIssueImplementProjection`.

Preserve the existing indexed adapter and compatibility domain semantics:

- `projectIssueImplementIssueClosedObservation` remains moifold-owned in `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`.
- `IssueClosedEvent`, terminal `CompleteState (IssueComplete prNumber)`, and post-commit `StopDaemon` stay unchanged.
- A mismatched close PR still blocks with `RecordBlocked` then `StopDaemon`.
- Remote issue polling still uses `gh issue view`; open remote issues still execute or dry-run `CloseIssue` before `SleepUntilNextPoll`; closed remote issues still emit `ObservedIssueClosed`.
- Compatibility writes, event append ordering, daemon result constructors, detailed transaction failure shape, dry-run text, runtime command rendering, and request-id behavior remain compatible.

### Steps
1. Add one focused IssueImplement case in `src/CodexWatcher/Daemon.hs` near the existing item-022 post-merge routes:
   - `SomeWatcherState IssueWaitingForIssueClose {}` plus `DaemonIssueImplementObservation (ObservedIssueClosed prNumber)` calls `WorkflowIssueImplementIndexed.projectIssueImplementIssueClosedObservation state prNumber`.
   - The case returns `preparedFromIssueImplementProjection projected`.
2. Do not change `runIssueWaitingForIssueClose` or `retryCloseIssue` except if a compiler-guided import/export adjustment is strictly required. Their behavior must remain:
   - `remoteIssueIsClosed remote` emits `ObservedIssueClosed prNumber` through `loopObserveWithExecutor`.
   - an open issue runs `CloseIssue issueConfig prNumber` before `SleepUntilNextPoll`;
   - the idle text remains `closed issue after merged PR #<n>; waiting to observe closed issue`;
   - the dry-run text remains `would close issue after merged PR #<n>`.
3. Extend `test/Main.hs` daemon parity coverage:
   - Add `workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchIssueCloseProjections`.
   - Add `issueImplementDaemonIssueCloseProjectionCases` with at least:
     - successful close from `IssueWaitingForIssueClose` to `IssueImplement/Complete` using `ObservedIssueClosed prNumber`, event `IssueClosedEvent prNumber`, final state `CompleteState (IssueComplete prNumber)`, and effect plan `[StopDaemonTag]`;
     - wrong-PR close from the same state using `ObservedIssueClosed stalePr`, event `IssueClosedEvent stalePr`, blocked final state, and effect plan `[RecordBlockedTag, StopDaemonTag]`.
   - Run both cases through the existing `runIssueImplementDaemonProjectionCase` helper for `DryRunActions` and `ExecuteActions` so the assertions cover compatibility/indexed event parity, pre/post effect plan parity, compiled action and request-id parity, compatibility writes, event append ordering, final state label, replay source state, dry-run reports, and daemon observed result shape.
4. Strengthen automatic-loop close polling tests without changing the loop:
   - In `automaticIssueMergeWaitsForIssueClose` or a focused nearby test, assert that an open remote issue in `IssueWaitingForIssueClose` invokes the rendered close command and `SleepUntilNextPoll` in that order, returns no observed event, and preserves the idle text after the close command.
   - Keep the existing closed remote issue path proving `GhIssueView` closed detection emits `IssueClosedEvent prNumber` and reaches phase `Complete`.
   - Add a projection-match assertion for the closed remote issue tick: the observed tick must match `projectIssueImplementIssueClosedObservation` for event, final state shape, and compiled `StopDaemon` plan.
   - Assert dry-run close retry reports still include the `CloseIssue` command rendering and do not commit `IssueClosedEvent` until remote closed detection produces `ObservedIssueClosed`.
5. Update source-scan guard `workflowIssueImplementIndexedDaemonDoesNotRouteLaterProjectors`:
   - Move `projectIssueImplementIssueClosedObservation` and `ObservedIssueClosed` from forbidden to required for `src/CodexWatcher/Daemon.hs`.
   - Keep the item-020 through item-022 projector names required.
   - Keep lifecycle/item-024 surfaces out of the daemon projection guard: no new child lifecycle, repair, healthcheck, fanout, or automatic-loop ownership imports should appear.
6. Preserve `workflowIssueImplementIndexedDaemonRoutingIsLimitedToDaemonProjectionOnly`: indexed imports and `projectIssueImplement*` calls remain confined to `src/CodexWatcher/Daemon.hs`; `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/DaemonLoop.hs`, `src/CodexWatcher/DaemonLoop/ActiveTurn.hs`, `src/CodexWatcher/DaemonLoop/Runtime.hs`, `src/CodexWatcher/AutomaticLoop/Runner.hs`, and `src/CodexWatcher/AutomaticLoop/Output.hs` must not import the indexed adapter or `IssueImplementIndexedSpec`.
7. Leave item-024 untouched:
   - Do not change issue-implementer child launch manifests, runtime status, stopped child restarts, terminal ready-issue completion, active issue capacity, state-dir ownership, PID/lock/runtime-owner handling, healthcheck issue-implement reporting, repair drop behavior, or issue-planning fanout boundaries.
   - Do not remove compatibility routing or compatibility writes as dead code in this round.

### Verification
The `watcher-core-test` executable is a monolithic custom test runner, so focused verification is by exact test functions and assertions inside `test/Main.hs`, then the full executable command.

Exact test coverage to add or update:

1. `workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchIssueCloseProjections`
2. `issueImplementDaemonIssueCloseProjectionCases`
3. `automaticIssueMergeWaitsForIssueClose`
4. Assertions named `closed issue completes issue implementer`, `clean post-merge review schedules issue close`, and new close-retry assertions for close command ordering, idle text, dry-run rendering, and no premature `IssueClosedEvent`.

Run the roadmap baseline:

1. `cabal test watcher-core-test`
2. `cabal build all`
3. `git diff --check`
4. `git diff --cached --check` only if changes are staged later by an implementer or integrator.

Manual/source-scan guards to record in implementation notes:

- `rg -n "IssueWaitingForIssueClose|ObservedIssueClosed|projectIssueImplementIssueClosedObservation" src/CodexWatcher/Daemon.hs test/Main.hs` must show the item-023 daemon route and tests are present.
- `rg -n "runIssueWaitingForIssueClose|retryCloseIssue|CloseIssue|SleepUntilNextPoll|waiting to observe closed issue|would close issue after merged PR" src/CodexWatcher/Domain/IssueImplement/Loop.hs test/Main.hs` must show polling and retry behavior stayed in the domain loop and is tested.
- `rg -n "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed|IssueImplementIndexedSpec|projectIssueImplement" src/CodexWatcher/Domain src/CodexWatcher/DaemonLoop src/CodexWatcher/AutomaticLoop` must show no indexed import or projector use outside daemon projection.
- `rg -n "ChildDaemon|healthcheck|repair|IssuePlanningFanout|runtime-owner|launch manifest|pid|lock" src test/Main.hs` should only be used as a guard if item-024 surfaces appear in the diff; item 023 should not touch them.

### Worker Fan-Out
No worker fan-out. The route, tests, and guards touch one daemon routing case plus nearby shared test helpers; splitting this would create coordination overhead without non-overlapping ownership.
