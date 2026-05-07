### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported the workspace was up to date, confirming the integrated package graph builds and the previous mergeability module cycle is absent.
- Command: `cabal test watcher-core-test`
  Result: pass. The `watcher-core-test` suite built and ran successfully; Cabal reported `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass. No whitespace errors were reported.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors were reported; there are no staged changes.

### Plan Compliance
- Step 1: met. `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability.hs` remains compatibility-only, exports only `PrReviewMergeabilityObservation(..)` and `observePrReviewMergeability`, and does not import `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.Observation`, or `CodexWatcher.Workflow.Indexed.Spec`.
- Step 2: met. `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability/Indexed.hs` defines the indexed PR-review mergeability spec, indexed state/event/observation/effect/effect-plan/tick/replay wrappers, and the phantom markers needed for the golden lifecycle prefix through `PrReviewIndexedWaitingForMergeability -> PrReviewIndexedMerging`.
- Step 3: met. The indexed `IndexedWorkflowSpec` delegates to `MoifoldSpec` for initial/apply/observe/replay/effect validation/permissions/labels, and derives indexed planned transitions from `legacyObservedPlannedTransition` and `moifoldPlannedTransitionFromEffects`.
- Step 4: met. `moifold.cabal` exposes `CodexWatcher.Workflow.Moifold.PrReview.Mergeability.Indexed` beside `CodexWatcher.Workflow.Moifold.PrReview.Mergeability`.
- Step 5: met. `test/Main.hs` imports indexed helper types from `.Mergeability.Indexed` while keeping the compatibility facade import from `.Mergeability`.
- Step 6: met. The indexed parity test loads `golden/event-log/pr-review/mlf2-pr6-merged/events.jsonl`, replays the lifecycle prefix into `PrReview/WaitingMergeability`, and checks event, target label, next state shape, pre/post effect plan, observed effects, and replay parity.
- Step 7: met. The mismatched clean-commit test checks the facade, compatibility `MoifoldSpec` observe/plan path, and indexed observe/plan path all fail with `mergeability clean commit does not match reviewed commit`.
- Step 8: met. Existing facade and contract tests remain present, including `workflowPrReviewMergeabilityFacadeMatchesWatcher`, `workflowPrReviewMergeabilityPlannedTransitionKeepsMergePreCommitEffect`, and `workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions`; `watcher-core-test` exercised them.
- Step 9: met for implementation scope. The implementation diff is limited to `moifold.cabal`, `test/Main.hs`, and the new indexed module, with the existing compatibility module inspected as compatibility-only. No `golden/` fixtures, event schemas, replay code, daemon loops, runtime command rendering, dry-run output paths, roadmap files, or merge artifacts were changed. `orchestrator/state.json` is dirty with active round metadata for `round-006`; selection/state roadmap identity matches the active bundle.

### Decision
**APPROVED**

### Evidence
Changed/untracked paths inspected: `moifold.cabal`, `test/Main.hs`, `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability/Indexed.hs`, `orchestrator/state.json`, and round artifacts under `orchestrator/rounds/round-006/`.

The compatibility facade has no forbidden indexed/workflow imports. The new indexed module imports the indexed workflow API and `Workflow.Types`, delegates behavior to `MoifoldSpec`, and is not on the daemon compatibility path through `CodexWatcher.Domain.PrReview.Watcher -> CodexWatcher.Workflow.Moifold.PrReview.Mergeability`.

`watcher-core-test` output included the focused passes:
- `PASS indexed workflow PR-review mergeability clean matches compatibility from golden lifecycle`
- `PASS indexed workflow PR-review mergeability clean keeps merge effect pre-commit`
- `PASS indexed workflow PR-review mergeability clean rejects mismatched commit like facade`
- `PASS workflow mergeability planned transition keeps merge effect pre-commit`
- `PASS workflow PR-review mergeability law observe and plan agree`
- `PASS workflow PR-review mergeability law direct and generic replay match`
- `PASS workflow PR-review mergeability law facade observation matches public path`

Roadmap identity matches selection and state:
- `roadmap_id`: `2026-05-07-00-workflow-kernel-indexing`
- `roadmap_revision`: `rev-001`
- `roadmap_dir`: `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001`
- `roadmap_item_id`: `item-006-indexed-pr-review-slice`
