### Goal
Inventory the current unindexed and indexed workflow-spec surfaces and add a focused baseline that makes the first `WorkflowSpec` / `IndexedWorkflowSpec` parity laws visible for the existing moifold and DocsMigration implementations, without changing runtime behavior or public API shape.

### Approach
Keep this round sequential. The selected item is an inventory-and-law baseline, the active roadmap is on the serial lane, and the likely edits converge in the existing `workflowFacadeExtractionTests` area of `test/Main.hs`; splitting workers would create coordination overhead around the same assertions and fixture setup.

Use the existing workflow framework test cluster instead of introducing a new harness. Extend the source-scan coverage to inventory the public `WorkflowSpec` and `IndexedWorkflowSpec` class methods, the moifold `MoifoldSpec` facade, DocsMigration's dual spec instances, and the indexed moifold adapter modules. Add small law/parity assertions that exercise representative surfaces already present in the repo: labels and replay state projection through existential indexed wrappers, observed-transition parity, terminal checks, and permission/effect hook parity against the unindexed compatibility functions.

The implementation must reference `orchestrator/project-contract.md` for stable invariants: no event schema or golden fixture churn, no daemon/lifecycle ownership moves, no compatibility facade removal, and no package-boundary relaxation. Runtime code should only change if a compile failure exposes that the tests need a tiny exported helper; otherwise this round should be test/source-scan only.

### Steps
1. Inspect the current spec inventory before editing:
   - `agent-workflow-core/src/CodexWatcher/Workflow/Spec.hs`
   - `agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`
   - `src/CodexWatcher/Workflow/Types.hs`
   - `src/CodexWatcher/Workflow/DocsMigration.hs`
   - `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`
   - `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`
   - `src/CodexWatcher/Workflow/Moifold/PrReview/Checking/Indexed.hs`
   - `src/CodexWatcher/Workflow/Moifold/PrReview/Worker/Indexed.hs`
   - `src/CodexWatcher/Workflow/Moifold/PrReview/Reviewer/Indexed.hs`
   - `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability/Indexed.hs`
2. In `test/Main.hs`, add an inventory/source-scan assertion near `workflowSpecModuleKeepsCoreBoundary` and `workflowIndexedSpecModuleKeepsCoreBoundary` that fails if the baseline loses coverage for the key class hooks:
   - unindexed state, event, observation, replay, validation, effect enumeration, effect permission, terminal, and label hooks
   - indexed source/target labels, existential wrappers, replay-state projection, validation, effect permission, terminal, and label helpers
   - current concrete instances for `MoifoldSpec`, `DocsMigrationSpec`, and each moifold indexed adapter module
3. Add a focused unindexed-to-indexed DocsMigration law test covering one successful observation path and one terminal/permission path:
   - `workflowObserve` and `indexedWorkflowPlanObservation` produce the same event, final state, pre/post effect partition, and labels for the draft-produced transition
   - `workflowReplayEvents` and `indexedWorkflowReplayEvents` project the same replay state label after the same fixture events
   - `workflowIsTerminal` and `indexedWorkflowIsTerminal` agree for complete and non-terminal states
   - `workflowValidateEffects` / `workflowEffectAllowed` and the indexed validation hooks agree for an allowed active-state plan and a rejected ready-state plan
4. Add a focused moifold law baseline using an existing compact path, preferably PR-review mergeability because `workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions` already has representative state, observation, replay, permission, and dry-run setup:
   - assert the indexed mergeability projection exposes the same event label, source label, target label, pre/post effect labels, and terminal status as the unindexed facade for the selected transition
   - keep this as an assertion extension or a small sibling helper, not a broad rewrite of the existing compatibility tests
5. Register any new helper in `workflowFacadeExtractionTests` beside the current workflow spec and indexed spec entries. Keep helper names descriptive enough that a failure identifies which baseline moved.
6. Do not modify event codecs, golden fixtures, daemon routing, DocsMigration behavior, moifold transition behavior, roadmap files, selection artifacts, review artifacts, or `orchestrator/state.json`.

### Verification
Run the focused regression first:

```sh
cabal test watcher-core-test --test-option=--match --test-option='workflow facade extraction'
```

Then run the roadmap baseline checks:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
```

If the implementer stages changes before handoff, also run:

```sh
git diff --cached --check
```

Review the final diff manually to confirm it is limited to the round's test/source-scan baseline and does not alter runtime behavior, compatibility fixtures, roadmap files, `selection.md`, review artifacts, or `orchestrator/state.json`.
