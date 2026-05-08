### Goal
Port PR-review fix-worker outcome transitions to the indexed workflow API while preserving the existing moifold compatibility behavior. The covered outcomes are `WorkerCompleted`, `WorkerIncomplete`, and `WorkerBlocked` as observed through `ObservedWorkerOutcome`, producing the existing `PrReviewFixCompleted`, `PrReviewFixIncomplete`, and `WatcherBlocked` events from `PrFixingReviews`.

The round must keep event JSON schemas, event `type` fields, golden logs, daemon result shapes, dry-run output, action ordering, classifier evidence, effect plans, replay behavior, permission behavior, and compatibility facades stable.

### Approach
Keep this as a sequential, single-owner change. The roadmap marks `item-008-indexed-pr-review-worker-outcomes` as not parallel-safe, and the implementation will need to touch the same PR-review worker outcome observation surface, indexed adapter pattern, Cabal exposure, and focused parity tests. Worker fan-out would create overlapping ownership of transition labels, wrapper types, effect-plan assertions, and compatibility comparisons.

Add a moifold-owned indexed adapter for PR-review worker outcomes, following the existing pattern in `CodexWatcher.Workflow.Moifold.PrReview.Checking.Indexed` and `CodexWatcher.Workflow.Moifold.PrReview.Mergeability.Indexed`. Prefer a narrow sibling module such as `src/CodexWatcher/Workflow/Moifold/PrReview/Worker/Indexed.hs`, exposed from `moifold.cabal`, rather than widening the checking or mergeability modules beyond their current intent.

The adapter should wrap existing concrete moifold values and delegate behavior to `MoifoldSpec`: `SomeWatcherState`, `WatcherEvent`, `DaemonObservation`, `ObservedPolicyTick`, `SomeEffect`, `EffectPlan`, and `EventReplayResult`. `agent-workflow-core` continues to own only the generic indexed API; moifold continues to own concrete PR-review lifecycle policy, `WatcherEvent`/`SomeWatcherState`, Aeson event codecs, replay policy, daemon observation projection, runtime effects, app-server/GitHub actions, and dry-run rendering.

Do not route a live daemon call site through the indexed adapter in this round. Do not change `CodexWatcher.Workflow.Moifold.PrReview` checking helpers, `CodexWatcher.Domain.PrReview.Loop`, `CodexWatcher.Domain.PrReview.Watcher` semantics, event codecs, golden fixtures, dry-run text, app-server action rendering, or compatibility module availability except for adding the intentionally narrow indexed adapter module.

### Steps
1. Inspect the current worker outcome path before editing: `src/CodexWatcher/Domain/PrReview/Watcher.hs`, `src/CodexWatcher/Domain/PrReview/Protocol.hs`, `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`, `src/CodexWatcher/Workflow/Moifold/PrReview/Agent.hs`, the existing indexed adapters under `src/CodexWatcher/Workflow/Moifold/PrReview/*/Indexed.hs`, and the indexed parity helpers in `test/Main.hs`.
2. Add the worker outcome indexed adapter module with typed points for at least `PrReview/Uninitialized`, `PrReview/CheckingReviews`, `PrReview/FixingReviews`, `PrReview/ReviewingClean`, and `PrReview/Blocked` if a blocked marker is needed for source/target typing. The main worker outcome transitions are `PrReview/FixingReviews -> PrReview/CheckingReviews` for completed and incomplete outcomes, and `PrReview/FixingReviews -> PrReview/Blocked` for blocked outcomes.
3. Define indexed wrappers for state, event, observation, observed tick, effect, effect plan, and replay result. Keep them as wrappers around the existing moifold values plus source and target labels, matching the checking and mergeability adapters. Do not add new event constructors, new JSON fields, new event `type` values, or new daemon result constructors.
4. Implement `IndexedWorkflowSpec` for the worker adapter by delegating all behavior to `MoifoldSpec`: initial/apply event, observe, observed transition, observed state, plan transition, replay, replay state, effect validation, effect permissions, terminal checks, state labels, event labels, observation labels, and effect labels.
5. Use the existing `legacyObservedPlannedTransition` and `moifoldPlannedTransitionFromEffects` partitioning so pre-commit and post-commit effect plans remain byte-for-byte equivalent to compatibility planning. For the worker outcomes, the expected post-commit behavior is the existing `SleepUntilNextPoll` plan for completed and incomplete outcomes, and the existing blocked-state `RecordBlocked` behavior for blocked outcomes.
6. Model indexed observations as `DaemonPrReviewObservation (ObservedWorkerOutcome outcome)` from a `PrFixingReviews` state. Preserve the compatibility facade path in `prReviewObserve`; the indexed adapter should prove parity with it, not replace daemon routing yet.
7. Add focused tests in `test/Main.hs` beside the current PR-review checking and mergeability indexed tests. Reuse the existing helper style where possible, or add a worker-specific helper that compares facade `prReviewObserve`, compatibility `workflowObserve`/`workflowPlanObservation`, and indexed observe/plan.
8. Cover the three worker outcome cases from a real fixing state:
   - `WorkerCompleted` produces `PrReviewFixCompleted`, transitions from `PrReview/FixingReviews` to `PrReview/CheckingReviews`, preserves replay state/effects, and keeps the existing `SleepUntilNextPoll` effect plan.
   - `WorkerIncomplete reason` produces `PrReviewFixIncomplete reason`, transitions from `PrReview/FixingReviews` to `PrReview/CheckingReviews`, preserves replay state/effects, and keeps the existing `SleepUntilNextPoll` effect plan.
   - `WorkerBlocked reason` produces `WatcherBlocked reason`, transitions from `PrReview/FixingReviews` to `PrReview/Blocked`, preserves replay state/effects, and keeps the existing blocked effect plan and permission result.
9. Preserve classifier evidence by adding or extending tests that start with representative `AppServerTurn` values and pass through the existing worker classifier/agent role into `ObservedWorkerOutcome`: structured complete, structured incomplete, missing-output blocked, failed-turn structured complete/incomplete, and malformed completed output. The tests should assert the indexed plan for each resulting observation is the same as compatibility planning and that `AgentOutputClass` remains `AgentComplete`, `AgentIncomplete`, `AgentMalformed`, or `AgentBlocked` as it is today.
10. Use a replay prefix that reaches `PrFixingReviews`, either built directly from `PrReviewInitialized` plus `PrReviewUnresolvedFound` or from the existing PR-review golden lifecycle if that keeps the tests clearer. Do not modify golden files; golden logs are preservation evidence, not update targets for this round.
11. Include negative coverage for invalid worker outcome observations outside `PrFixingReviews`, proving the indexed observe and indexed plan-observation paths return the same failure as the compatibility path and do not produce an event or effect plan.
12. Inspect the final diff before verification. It should be limited to the new worker indexed adapter module, `moifold.cabal`, and focused `test/Main.hs` imports/helpers/assertions unless the implementer can justify a directly required local helper extraction. Do not edit `orchestrator/state.json`, roadmap files, review/merge artifacts, event codecs, replay modules, daemon loops, dry-run rendering, runtime effect rendering, or golden fixtures.

### Verification
Run the baseline commands from `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-002/verification.md`:

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check`

The focused `watcher-core-test` evidence should include PR-review worker indexed parity assertions for:

- `WorkerCompleted` from `PrFixingReviews`, proving `PrReviewFixCompleted`, `PrReview/FixingReviews -> PrReview/CheckingReviews`, pre/post effect-plan parity, observed-effect parity, replay parity, validation parity, and permission parity.
- `WorkerIncomplete reason` from `PrFixingReviews`, proving `PrReviewFixIncomplete reason`, `PrReview/FixingReviews -> PrReview/CheckingReviews`, effect-plan parity, replay parity, validation parity, and permission parity.
- `WorkerBlocked reason` from `PrFixingReviews`, proving `WatcherBlocked reason`, `PrReview/FixingReviews -> PrReview/Blocked`, blocked effect-plan parity, replay parity, validation parity, permission parity, and no daemon result shape change.
- Classifier-backed worker outputs for structured complete, structured incomplete, missing-output blocked, failed-turn structured complete/incomplete, and malformed completed output, proving classifier evidence and `AgentOutputClass` are not weakened before indexed planning.
- Invalid worker observations outside `PrFixingReviews`, proving indexed failures match compatibility failures.

Also verify by diff inspection that these surfaces remain unchanged: event `type` fields, Aeson JSON schemas, golden event logs, `EventReplayResult` semantics, `DaemonTickResult` and `DaemonObservedTickResult` fields, dry-run report text/fields, app-server/GitHub action ordering, runtime command rendering, compatibility facade modules, roadmap files, and `orchestrator/state.json`.
