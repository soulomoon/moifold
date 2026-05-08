### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date` for all build targets.
- Command: `cabal test watcher-core-test`
  Result: pass. The suite rebuilt and ended with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported.

### Plan Compliance
- Inspect current worker outcome path and existing indexed adapter pattern: met. The implementation follows the existing checking and mergeability indexed adapter shape, and review inspected `Watcher.hs`, `Agent.hs`, and both prior indexed adapters.
- Add a moifold-owned worker outcome indexed adapter: met. `src/CodexWatcher/Workflow/Moifold/PrReview/Worker/Indexed.hs` adds the narrow adapter and `moifold.cabal` exposes it.
- Define wrappers around existing moifold values without new schema/event surfaces: met. The adapter wraps `SomeWatcherState`, `WatcherEvent`, `DaemonObservation`, `ObservedPolicyTick`, `SomeEffect`, `EffectPlan`, and `EventReplayResult`; it does not add event constructors, JSON fields, daemon result constructors, or event `type` values.
- Delegate indexed behavior to `MoifoldSpec`: met. Initial/apply/observe/plan/replay/effect validation/effect permission/terminal and label methods all delegate through the existing moifold workflow interfaces.
- Preserve compatibility planning partitioning and effect plans: met. The adapter uses `legacyObservedPlannedTransition` and `moifoldPlannedTransitionFromEffects`; tests assert post-commit `SleepUntilNextPoll` for completed/incomplete outcomes and post-commit blocked effects for blocked outcomes.
- Model worker observations from `PrFixingReviews` without rerouting live daemon paths: met. Tests construct `DaemonPrReviewObservation (ObservedWorkerOutcome ...)` from a real fixing state, and diff inspection shows no daemon loop or live routing changes.
- Add focused tests beside existing indexed parity tests: met. `test/Main.hs` adds worker indexed parity, classifier-backed, and invalid-observation tests near the current PR-review indexed checks.
- Cover `WorkerCompleted`, `WorkerIncomplete`, and `WorkerBlocked`: met. Test output includes the three named parity cases and assertions for event parity, source/target labels, observed effects, replay parity, validation parity, and permission parity.
- Preserve classifier-backed worker output evidence and `AgentOutputClass`: met. Test output includes structured complete, structured incomplete, missing-output blocked, failed structured complete/incomplete, and malformed completed cases, asserting the expected `AgentComplete`, `AgentIncomplete`, `AgentBlocked`, and `AgentMalformed` classes.
- Use a replay prefix reaching `PrFixingReviews` without golden edits: met. Tests replay `PrReviewInitialized` plus `PrReviewUnresolvedFound`; no golden fixture files changed.
- Cover invalid worker outcome observations outside `PrFixingReviews`: met. The invalid-observation test compares `prReviewObserve`, compatibility `workflowObserve`/`workflowPlanObservation`, and indexed observe/plan failure results.
- Keep non-target surfaces stable: met. Diff inspection shows no changes under golden fixtures, roadmap files, event-log code, daemon code, dry-run/CLI rendering, runtime command/action metadata, existing PR-review facade/domain modules, checking/mergeability adapters, or compatibility modules. `orchestrator/state.json` contains the active round metadata already present for review; I did not update it.

### Decision
**APPROVED**

### Evidence
The integrated diff is limited to the new worker adapter exposure, focused tests, the new worker adapter module, round artifacts, and active round metadata. The new adapter delegates to `MoifoldSpec` rather than moving moifold lifecycle policy into `agent-workflow-core`, and no Aeson/event codec, golden log, daemon, dry-run, runtime command rendering, or action-ordering files changed.

`watcher-core-test` exercised the relevant preservation surfaces, including golden event-log type fields, dry-run/action metadata ordering, the existing PR-review checking and mergeability indexed tests, and the new PR-review worker indexed cases:

- `indexed workflow PR-review worker complete outcome matches compatibility`
- `indexed workflow PR-review worker incomplete outcome matches compatibility`
- `indexed workflow PR-review worker blocked outcome matches compatibility`
- classifier-backed complete, incomplete, missing-output blocked, failed complete/incomplete, and malformed completed cases
- `indexed workflow PR-review worker rejects invalid observation like facade`
