### Goal
Port the issue-planning policy transition surface to the indexed workflow API without changing live daemon routing. The round should add a moifold-owned indexed issue-planning adapter for the existing compatibility observations and prove parity for `IssuePlanningTurnStarted`, `IssuePlanningIssuesRequested`, `IssuePlanningGraphUpdated`, `IssuePlanningReadyIssuesFixed`, `IssuePlanningScopeCompleted`, `IssuePlanningTurnRetryRequested`, `IssuePlanningTurnCompleted`, and planning `WatcherBlocked` transitions from valid planning states.

### Approach
Keep concrete issue-planning policy in moifold and wrap the existing compatibility behavior instead of reimplementing it in `agent-workflow-core`. The new adapter should mirror the PR-review indexed adapter pattern: typed phantom state markers, wrappers around `SomeWatcherState`, `DaemonObservation`, `WatcherEvent`, `EffectPlan`, `SomeEffect`, and `EventReplayResult`, and an `IndexedWorkflowSpec` instance that delegates to `MoifoldSpec` for initial event, apply, observe, replay, effect validation, permission checks, labels, and terminal detection.

The indexed issue-planning module should live under the moifold package surface, for example `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`, and be listed in `moifold.cabal`. It must not move `PlannerConfig`, `PlanningGraph`, `IssueCreationRequest`, graph validation, Aeson event codecs, daemon-loop logic, filesystem compatibility writes, or runtime/app-server/GitHub effects into indexed core.

Do not route live daemon observations through the new adapter in this round. Items 014-016 own live daemon start, graph/request routing, terminal/retry routing, dry-run/execute daemon projection, and daemon transaction-result preservation. Round 013 may use execution compilation helpers in tests to prove effect ordering, dry-run reports, and request-id progression for the policy plans, but production daemon paths should remain on the existing compatibility route.

Worker fan-out is not used. The adapter, cabal exposure, and parity tests share one ownership boundary and the selected roadmap item is marked non-parallel-safe.

### Steps
1. Add the moifold-owned indexed adapter module for issue planning.
   - Define phantom markers for the planning states the item covers: ready/initialized, active plan turn, waiting for ready issues, blocked, and complete.
   - Define wrappers equivalent to the PR-review indexed adapters: `IssuePlanningIndexedState`, `IssuePlanningIndexedEvent`, `IssuePlanningIndexedObservation`, `IssuePlanningIndexedTick`, `IssuePlanningIndexedEffect`, `IssuePlanningIndexedEffectPlan`, and `IssuePlanningIndexedReplayResult`.
   - Implement `IndexedWorkflowSpec` by delegating to `workflowInitialEvent @MoifoldSpec`, `workflowApplyEvent @MoifoldSpec`, `workflowObserve @MoifoldSpec`, `workflowReplayEvents @MoifoldSpec`, `workflowValidateEffects @MoifoldSpec`, `workflowEffectAllowed @MoifoldSpec`, and the moifold label functions.
   - Preserve explicit source and target labels on indexed events and observations, as the PR-review adapters do, so tests can assert the intended typed edge labels even though the wrapped compatibility state remains `SomeWatcherState`.
2. Add adapter conversion helpers needed by tests.
   - Provide a helper that converts an indexed planned transition back to `PlannedTransition MoifoldSpec` by unwrapping the event and pre/post effect plans.
   - Provide a helper that unwraps `SomeIndexedWorkflowEvent IssuePlanningIndexedSpec` to `WatcherEvent` for replay.
   - Keep helpers local to the adapter unless tests need exported constructors/accessors.
3. Add the new module to `moifold.cabal` in the existing workflow module list near the PR-review indexed modules. Do not add a new package dependency or expose a public compatibility facade from `agent-workflow-core`.
4. Add focused indexed issue-planning tests in `test/Main.hs` beside the existing indexed workflow tests.
   - Add imports for the new adapter and register the new tests in the indexed workflow test group.
   - Add a reusable parity helper, modeled on `prReviewMergeabilityIndexedSpecMatchesCompatibility`, that compares direct `issuePlanningObserve`, generic `workflowObserve @MoifoldSpec`, generic `workflowPlanObservation @MoifoldSpec`, indexed observe, indexed plan, generic apply, indexed apply, direct/generic replay, indexed replay, effect labels, effect validation, effect permission, compiled action ordering, dry-run reports, request-id progression, and compatibility write shapes.
5. Cover all valid issue-planning policy transitions.
   - `PlanningReady` plus `ObservedPlanningTurnStarted` must produce `IssuePlanningTurnStarted`, transition `IssuePlanning/Initialized -> IssuePlanning/PlanMode`, preserve `StartPlannerTurn` as a pre-commit effect, preserve dry-run app-server request id progression, and preserve active-turn compatibility writes.
   - `PlanningTurnActive` plus `ObservedPlanningIssuesRequested` must produce `IssuePlanningIssuesRequested`, transition back to `IssuePlanning/Initialized`, preserve ordered `CreateIssue` effects followed by `SleepUntilNextPoll`, preserve dry-run command reports, and preserve ready compatibility writes.
   - `PlanningTurnActive` plus valid `ObservedPlanningGraphUpdated` must produce `IssuePlanningGraphUpdated`, transition to `IssuePlanning/Initialized` with the waiting-ready-issues state shape, preserve `RecordPlanningGraph` before `SleepUntilNextPoll`, and preserve `planner-state.json`, `planning-state.json`, and `daemon-state.json` compatibility write shapes.
   - `PlanningWaitingForReadyIssues` plus `ObservedPlanningReadyIssuesFixed` must produce `IssuePlanningReadyIssuesFixed`, transition to `IssuePlanning/Initialized`, and preserve the `SleepUntilNextPoll` plan and ready compatibility writes.
   - `PlanningReady` plus `ObservedPlanningScopeCompleted` must produce `IssuePlanningScopeCompleted`, transition to `IssuePlanning/Complete`, preserve post-commit `StopDaemon`, and preserve terminal compatibility writes.
   - `PlanningTurnActive` plus `ObservedPlanningTurnRetryRequested` must produce `IssuePlanningTurnRetryRequested`, transition to `IssuePlanning/Initialized`, and preserve `SleepUntilNextPoll`.
   - `PlanningTurnActive` plus `ObservedPlanningTurnCompleted` must produce `IssuePlanningTurnCompleted`, transition to `IssuePlanning/Complete`, and preserve post-commit `StopDaemon`.
   - `ObservedPlanningBlocked` from `PlanningReady`, `PlanningTurnActive`, and `PlanningWaitingForReadyIssues` must produce `WatcherBlocked`, transition to `IssuePlanning/Blocked`, preserve `RecordBlocked` then `StopDaemon`, preserve blocked compatibility writes, and keep final-state labels intact.
6. Cover graph validation and invalid-observation parity.
   - Add tests for invalid graph observations that already return a compatibility `WatcherBlocked`, including duplicate ready issue, duplicate blocked issue, duplicate dependency entry, ready/blocked overlap, dependency-on-ready, and out-of-scope graph failures. Assert the indexed path preserves the same event, blocked state, effects, labels, replay behavior, validation, permissions, and compatibility writes.
   - Add at least one scoped dependency closure success case so valid graph coverage does not only test the simple graph shape.
   - Add invalid observation tests for each observation used from a wrong source state, and assert indexed failures match the compatibility `workflowObserve @MoifoldSpec` failure text.
7. Preserve replay and observed effect contracts explicitly.
   - For every covered event, compare compatibility replay and indexed replay final state labels, state shape, and replay effect lists using prefixes that start with `IssuePlanningInitialized`.
   - Assert observed effect lists equal the concatenated pre/post planned effect lists after partitioning.
   - Assert indexed event label, observation label, source label, target label, final state label, pre-commit effect labels, and post-commit effect labels match the compatibility route and the expected roadmap labels.
8. Preserve dry-run reports, action ordering, and request ids at the policy-plan level.
   - Compile each observed full effect plan with both `compileEffectPlan` and `WorkflowExecution.compileWorkflowEffectPlanWithMetadata` using a fixed `EffectRuntimeConfig`.
   - Compare rendered planned actions, dry-run reports, action ordering, and `compiledNextRequestId`.
   - Include a start-turn case that proves `StartPlannerTurn` consumes the current app-server request id and advances it exactly once, and a non-app-server case that proves request id remains stable when no app-server action is planned.
9. Preserve compatibility writes at the resulting state boundary.
   - Compare `compatibilityStateWrites` for compatibility-observed and indexed-observed final states for ready, active, waiting-ready-issues, blocked, and complete outcomes.
   - For graph updates, assert `planning-state.json` contains the same `PlanningGraph` JSON as the compatibility route.
10. Run focused validation first, then baseline validation.
   - Focused command: `cabal test watcher-core-test --test-options '--match indexed workflow'` or the closest exact matcher for the indexed workflow group if the local runner requires a narrower name.
   - Focused command: `cabal test watcher-core-test --test-options '--match issue planning'` if the indexed matcher does not cover the graph/scope regression cases.
   - Baseline commands: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check` if files are staged before review.
11. Record implementation evidence in `orchestrator/rounds/round-013/implementation-notes.md` after implementation.
   - List changed source/test/cabal files.
   - Record focused and baseline command results.
   - Note explicitly that live daemon routing was not changed and no `worker-plan.json` was used.

### Verification
The implementation is correct when the new indexed issue-planning adapter compiles, all eight issue-planning observations and planning `WatcherBlocked` transitions match the existing compatibility path, graph validation success/failure behavior is preserved, invalid observations fail the same way, effect labels and pre/post effect partitions match, replay final states/effects match, permissions and validation match, dry-run reports and action ordering match, request-id progression matches, and compatibility writes remain unchanged.

Required commands for the completed implementation are:

1. `cabal test watcher-core-test --test-options '--match indexed workflow'`
2. `cabal test watcher-core-test --test-options '--match issue planning'`
3. `cabal build all`
4. `cabal test watcher-core-test`
5. `git diff --check`
6. `git diff --cached --check` if anything is staged
