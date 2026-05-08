### Changes Made
- `src/CodexWatcher/Workflow/Moifold/PrReview/Worker/Indexed.hs`: added the moifold-owned indexed adapter for PR-review worker outcomes, wrapping existing `SomeWatcherState`, `WatcherEvent`, `DaemonObservation`, `ObservedPolicyTick`, effects, plans, and replay results while delegating behavior to `MoifoldSpec`.
- `moifold.cabal`: exposed the new worker indexed adapter module from the main moifold library.
- `test/Main.hs`: added PR-review worker indexed parity tests for completed, incomplete, blocked, classifier-backed, and invalid-observation cases.

### Tests
- `test/Main.hs`: verifies `WorkerCompleted`, `WorkerIncomplete`, and `WorkerBlocked` from `PrFixingReviews` preserve compatibility events, source/target labels, observed effects, pre/post plans, replay results, effect validation, and effect permissions.
- `test/Main.hs`: verifies structured complete, structured incomplete, missing-output blocked, failed structured complete/incomplete, and malformed completed worker outputs keep the existing `AgentOutputClass` evidence before indexed planning.
- `test/Main.hs`: verifies invalid worker outcome observations outside `PrFixingReviews` fail the same way through `prReviewObserve`, `workflowObserve`, `workflowPlanObservation`, and the indexed adapter.

### Notes
No daemon live path was routed through the indexed adapter. Event codecs, golden logs, daemon result shapes, dry-run output, action rendering, roadmap files, and `orchestrator/state.json` were left unchanged.
