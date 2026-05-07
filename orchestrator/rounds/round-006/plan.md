### Goal
Port one PR-review mergeability-clean transition slice to the indexed workflow API while preserving the existing compatibility behavior. The selected slice is `PrWaitingForMergeability` observing `PrReviewMergeabilityClean` and transitioning to `PrMerging` with the current merge pre-commit effect. The round must prove parity against the existing PR-review facade using golden-backed lifecycle data, without changing `WatcherEvent` JSON schemas, golden logs, daemon result shapes, dry-run output, action ordering, or roadmap identity.

### Approach
Break the failed module cycle by separating ownership:

- `CodexWatcher.Workflow.Moifold.PrReview.Mergeability` remains the compatibility facade module. It should own only `PrReviewMergeabilityObservation(..)` and `observePrReviewMergeability`, plus the imports needed for that direct facade. It must not import `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.Observation`, or `CodexWatcher.Workflow.Indexed.Spec`.
- Add a sibling production module, `CodexWatcher.Workflow.Moifold.PrReview.Mergeability.Indexed`, to own the indexed adapter for this slice. This module may import `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.Observation`, `CodexWatcher.Workflow.Indexed.Spec`, and the compatibility `Mergeability` module because it is not imported by `CodexWatcher.Domain.PrReview.Watcher`.
- Keep `CodexWatcher.Domain.PrReview.Watcher -> CodexWatcher.Workflow.Moifold.PrReview.Mergeability` as the daemon/domain compatibility path, and keep the new indexed module off that path. The intended graph is:
  `Workflow.Types -> Workflow.Observation -> Domain.PrReview.Watcher -> Workflow.Moifold.PrReview.Mergeability`
  and separately
  `Workflow.Moifold.PrReview.Mergeability.Indexed -> Workflow.Types`.

The indexed implementation should still delegate to `MoifoldSpec` and the existing compatibility behavior. The boundary change is only a module split to avoid the cycle; it is not authorization to introduce a second PR-review state machine, new event constructors, codec changes, golden rewrites, daemon-loop changes, runtime command changes, or dry-run formatting changes.

Do not use worker fan-out. The implementation is a small module-boundary repair plus focused tests, the roadmap item is not parallel-safe, and splitting it would create overlapping ownership of the same adapter and parity assertions.

### Steps
1. Restore `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability.hs` to compatibility-only ownership: export `PrReviewMergeabilityObservation(..)` and `observePrReviewMergeability`; remove the indexed wrapper types, indexed instance, and imports of `Workflow.Types`, `Workflow.Observation`, and `Workflow.Indexed.Spec` from this module. Keep the observable behavior of clean, retry, recheck, fix-required, and invalid observations unchanged.
2. Create `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability/Indexed.hs` for the production indexed slice. Define and export `PrReviewMergeabilityIndexedSpec`, `PrReviewIndexedState`, `PrReviewIndexedEvent`, `PrReviewIndexedObservation`, `PrReviewIndexedEffect`, `PrReviewIndexedEffectPlan`, `PrReviewIndexedTick`, `PrReviewIndexedReplayResult`, and only the phantom markers needed for the golden lifecycle prefix and the clean transition from `PrReviewIndexedWaitingForMergeability` to `PrReviewIndexedMerging`.
3. Implement `IndexedWorkflow.IndexedWorkflowSpec PrReviewMergeabilityIndexedSpec` in the new indexed module by delegating through the existing compatibility API: `workflowInitialEvent @MoifoldSpec`, `workflowApplyEvent @MoifoldSpec`, `workflowObserve @MoifoldSpec`, `legacyObservedPlannedTransition`, `moifoldPlannedTransitionFromEffects`, `workflowReplayEvents @MoifoldSpec`, `workflowValidateEffects @MoifoldSpec`, `workflowEffectAllowed @MoifoldSpec`, and the existing label functions. Indexed observations should wrap the same `DaemonPrReviewObservation (ObservedMergeabilityClean commit)` shape used by the facade path.
4. Add `CodexWatcher.Workflow.Moifold.PrReview.Mergeability.Indexed` to `moifold.cabal` beside the existing mergeability module. Do not move the compatibility facade out of the main library or change package boundaries beyond exposing this sibling module.
5. Update `test/Main.hs` so facade tests continue importing `CodexWatcher.Workflow.Moifold.PrReview.Mergeability`, while indexed parity helpers and tests import `CodexWatcher.Workflow.Moifold.PrReview.Mergeability.Indexed`. Keep test-only helpers limited to wrapping/unwrapping exported indexed constructors and golden fixture plumbing.
6. Preserve or add golden-backed indexed parity coverage for the selected slice. The primary test should load `golden/event-log/pr-review/mlf2-pr6-merged/events.jsonl`, replay the real lifecycle prefix through the clean-review state into `PrWaitingForMergeability`, then observe `ObservedMergeabilityClean` through both the old compatibility path and the indexed path. Assert the same emitted event, next state label, effect plan, pre/post action partitioning, and replay result.
7. Preserve the negative clean-commit guard: an indexed clean observation with a commit that differs from `cleanReviewCommit` must fail the same way as `observePrReviewMergeability` and must not produce an event or effect plan.
8. Keep existing facade and contract tests in place, especially `workflowPrReviewMergeabilityFacadeMatchesWatcher`, `workflowPrReviewMergeabilityPlannedTransitionKeepsMergePreCommitEffect`, and `workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions`. If an existing indexed parity test is replaced, the replacement must be golden-backed and at least as strict about event, state label, effect ordering, replay, validation, and permission parity.
9. Inspect the final diff before verification. It should be limited to the compatibility mergeability module, the new indexed sibling module, `moifold.cabal`, and focused test imports/helpers/assertions. Do not edit `orchestrator/state.json`, roadmap files, review/merge artifacts, golden fixtures, event schemas, replay code, daemon loops, runtime command rendering, or dry-run output code.

### Verification
Before running the full baseline, verify the module-cycle repair structurally with `cabal build all`; the previous failing cycle must be absent:

`CodexWatcher.Workflow.Types -> CodexWatcher.Workflow.Observation -> CodexWatcher.Domain.PrReview.Watcher -> CodexWatcher.Workflow.Moifold.PrReview.Mergeability -> CodexWatcher.Workflow.Types`

Run the exact baseline commands from the active roadmap bundle:

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check`

Focused PR-review indexed parity checks must be included in `watcher-core-test` and exercised by `cabal test watcher-core-test`:

- `workflowPrReviewMergeabilityIndexedSpecMatchesCompatibilityForCleanFromGoldenLifecycle`: real `mlf2` PR-6 golden lifecycle prefix, indexed observe/plan/replay parity, same event, same next state label, same effect plan, same replay result.
- `workflowPrReviewMergeabilityIndexedSpecPreservesMergeEffectOrdering`: indexed clean transition keeps `MergePullRequest` as the existing pre-commit effect, leaves post-commit effects empty, and preserves dry-run action reports.
- `workflowPrReviewMergeabilityIndexedSpecRejectsMismatchedCleanCommitLikeFacade`: indexed clean observation preserves the compatibility facade's mismatched-commit failure behavior.

Also verify by diff inspection that these files remain unchanged unless a reviewer explicitly approves a contract change: `golden/`, `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/EventLog/Replay.hs`, daemon result/loop modules, runtime command rendering modules, dry-run output paths, roadmap files, and `orchestrator/state.json`.
