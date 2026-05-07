### Changes Made
- `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability.hs`: restored the compatibility-only facade. It now exports only `PrReviewMergeabilityObservation(..)` and `observePrReviewMergeability`, and no longer imports `Workflow.Types`, `Workflow.Observation`, or `Workflow.Indexed.Spec`.
- `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability/Indexed.hs`: added the PR-review mergeability indexed adapter in a sibling module. It owns the indexed wrapper types, phase markers, replay result wrapper, and `IndexedWorkflowSpec PrReviewMergeabilityIndexedSpec` instance, delegating to `MoifoldSpec` and the existing planned-transition helpers.
- `moifold.cabal`: exposed `CodexWatcher.Workflow.Moifold.PrReview.Mergeability.Indexed` beside the compatibility mergeability module.
- `test/Main.hs`: moved indexed PR-review mergeability imports to the new `.Indexed` module, preserved the golden-backed lifecycle parity checks, and kept the mismatched clean-commit guard against both the facade and indexed paths.

### Tests
- `test/Main.hs`: verifies golden PR-6 lifecycle replay into `PrReview/WaitingMergeability`, clean mergeability transition parity, pre-commit merge effect ordering and dry-run report preservation, replay parity, and mismatched clean commit failure parity.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.

### Notes
The revised module split removes the failed cycle by keeping `CodexWatcher.Domain.PrReview.Watcher -> CodexWatcher.Workflow.Moifold.PrReview.Mergeability` on the compatibility path and placing the indexed adapter in `CodexWatcher.Workflow.Moifold.PrReview.Mergeability.Indexed`, which is not imported by the watcher. The first build after the split exposed a missing `ObservedPolicyTick(..)` field import in the new module; that was fixed before rerunning the required build and test commands.

`orchestrator/state.json` is still dirty in this worktree, but it was not edited during this implementation pass.
