### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. The suite rebuilt and ended with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported.

### Plan Compliance
- Inspect the existing PR-review compatibility and indexed surfaces: met. The implementation follows the existing mergeability indexed adapter shape and delegates through `MoifoldSpec`.
- Add a PR-review checking indexed adapter and expose it from Cabal: met. `src/CodexWatcher/Workflow/Moifold/PrReview/Checking/Indexed.hs` defines the adapter, and `moifold.cabal` exposes it.
- Define typed markers for checking/review-fixing/reviewing-clean and replay-prefix states: met. The adapter defines uninitialized, checking reviews, fixing reviews, and reviewing clean markers; tests use the fixing-to-checking replay prefix for `PrReviewFixCompleted`.
- Wrap existing moifold state/event/observation/tick/effect/effect-plan/replay values without changing schemas: met. The adapter wraps `SomeWatcherState`, `WatcherEvent`, `DaemonObservation`, `ObservedPolicyTick`, `SomeEffect`, `EffectPlan`, and `EventReplayResult`.
- Delegate indexed behavior to `MoifoldSpec` with compatible pre/post effect partitioning: met. The implementation uses `workflowObserve`, `workflowReplayEvents`, effect validation/permission delegation, `legacyObservedPlannedTransition`, and `moifoldPlannedTransitionFromEffects`.
- Preserve checking observation behavior for unresolved threads, no unresolved threads, feedback, and verification start: met. `watcher-core-test` includes passing assertions for unresolved threads, clean threads, feedback from checking/queued/verifying states, and verification start from the golden lifecycle.
- Preserve the compatibility facade and avoid daemon live routing changes: met. `CodexWatcher.Workflow.Moifold.PrReview` and daemon loop/routing modules are not changed; no live daemon path is routed through the new adapter.
- Add focused indexed parity tests: met. `test/Main.hs` compares facade, compatibility `MoifoldSpec`, and indexed paths for event, source/target labels, next-state label, pre/post effects, observed effects, replay state/effects, validation, permission, and invalid observation failures.
- Use golden-backed setup for verification start: met. The tests load `golden/event-log/pr-review/mlf2-pr6-merged/events.jsonl` and replay the prefix to `PrVerifyingReviewFix`.
- Keep edge coverage at least as strong as the facade: met. Tests cover empty review threads, unresolved threads, feedback from three checking-phase state constructors, verification start, and invalid observation failure parity.
- Preserve event schemas/golden logs/daemon/dry-run/action-ordering surfaces: met. Diff inspection shows no changes to event codecs, golden fixtures, daemon result/routing modules, dry-run rendering, runtime command rendering, or action metadata/order tests; the existing golden/schema/action-ordering tests also passed.

### Decision
**APPROVED**

### Evidence
The integrated round stays within the roadmap item scope: a new moifold-owned indexed checking adapter, one Cabal exposure line, and focused core tests. The new adapter introduces no `WatcherEvent` constructors, event `type` fields, JSON fields, golden fixture changes, daemon result constructors, dry-run text changes, runtime action rendering changes, or compatibility facade export changes.

The passing test output included these task-specific checks: `indexed workflow PR-review checking unresolved threads match compatibility`, `indexed workflow PR-review checking clean threads match compatibility`, `indexed workflow PR-review feedback from checking matches compatibility`, `indexed workflow PR-review feedback from queued fix matches compatibility`, `indexed workflow PR-review feedback from verification checking matches compatibility`, `indexed workflow PR-review verification start matches compatibility from golden lifecycle`, and `indexed workflow PR-review checking rejects invalid observation like facade`.

`orchestrator/state.json` is dirty with active-round controller state only; I did not modify it during review.
