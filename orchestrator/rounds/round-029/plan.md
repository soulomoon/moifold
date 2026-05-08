### Goal
Port one real DocsMigration transition and one real moifold transition to the pure workflow DSL helpers, proving that the DSL-authored transitions preserve the existing event, next state, effect partitioning, replay, permission, action ordering, and dry-run behavior.

### Approach
Keep this round sequential and single-owner. The two selected ports touch different workflow modules, but they share the same DSL import surface and the same `test/Main.hs` parity harness, and the roadmap default lane is serial. Do not write `worker-plan.json`.

Use the existing `WorkflowM` / `Transition` / `advance` API from `agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs` as pure planning syntax only. Do not add `IO`, `liftIO`, interpreters, event-codec changes, golden fixture changes, or new generic moifold policy to the DSL.

For the DocsMigration proof, port the compact non-PR draft transition: `DocsMigrationTurnActive` plus `DocsMigrationDraftProduced` into `DocsMigrationDraftReady`, with `WriteDocsMigrationDraft` then `RunDocsMigrationValidation` as the planned post-commit effects. For the moifold proof, port one issue-planning projection transition, preferably `projectIssuePlanningTurnCompletedObservation`, from `IssuePlanningIndexedActiveTurn` to `IssuePlanningIndexedComplete`, because it is small, already covered by indexed projection tests, and has focused dry-run/execute parity coverage nearby.

Preserve the old compatibility behavior as the oracle in tests by comparing the new DSL-authored transition against the current `workflowObserve`, `workflowPlanTransition`, `legacyObservedPlannedTransition`, `moifoldPlannedTransitionFromEffects`, replay, permission, compile, partition, and dry-run surfaces.

### Steps
1. Inspect the existing transition code in `src/CodexWatcher/Workflow/DocsMigration.hs`, `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`, and the DSL law block in `test/Main.hs` before editing. Confirm the selected transitions are still the DocsMigration draft-produced transition and the issue-planning turn-completed projection; if either has drifted, choose the nearest single transition with the same narrow behavior and record that in implementation notes.
2. Add a small pure DocsMigration DSL helper in `src/CodexWatcher/Workflow/DocsMigration.hs` for the draft-produced transition. It should call `WorkflowDSL.advance` with `DocsMigrationDraftProduced draft summary`, `emit` the two existing effects in the existing order, and return the next state as the transition value. Wire only the selected `applyDocsMigrationEvent (DocsMigrationTurnActive ...) (DocsMigrationDraftProduced ...)` path through this helper by extracting `transitionValue` and the combined planned effects. Leave all other DocsMigration transitions, codecs, fixtures, transaction hooks, daemon code, and interpreter behavior unchanged.
3. Add a small pure moifold DSL helper in `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs` for the selected issue-planning projection. It should use the existing observed event and effects as inputs, call `WorkflowDSL.advance`, preserve the indexed source/target labels, and lower back to the existing `IssuePlanningIndexedProjection` shape. Wire only the selected projection path through this helper; do not rewrite `indexedWorkflowPlanTransition` for every issue-planning transition.
4. Keep any production helper APIs local unless tests need to call them directly. If an export is required for focused parity assertions, export only the selected helper and keep its type tied to the selected transition so the round does not become a general transition DSL migration.
5. Extend `test/Main.hs` near the existing workflow DSL and workflow law assertions with focused parity tests for the DocsMigration port:
   - DSL transition event equals `DocsMigrationDraftProduced draft summary`.
   - DSL transition value equals the old `DocsMigrationDraftReady config draft` next state.
   - DSL pre/post effects equal `workflowPlanTransition @DocsMigrationSpec event effects`, including the all-post-commit partition.
   - replaying the same event sequence reaches the same state/effect history as before.
   - `workflowValidateEffects` and `workflowEffectAllowed` accept the selected active-state effects and still reject a wrong-state draft write.
   - compiled action ordering and `dryRunDocsMigrationCompiledEffectPlan` reports remain unchanged and execute no interpreter actions.
6. Extend `test/Main.hs` with focused parity tests for the moifold issue-planning port:
   - The DSL-authored projection event, final state, source label, target label, and effect plan match the old compatibility projection oracle for the same state and observation.
   - `workflowReplayEvents @MoifoldSpec` over the resulting event path still reaches the same terminal issue-planning state.
   - `workflowValidateEffects @MoifoldSpec`, `workflowEffectAllowed @MoifoldSpec`, and the existing phase-action validation agree with the old effect plan.
   - Compiled moifold action ordering and dry-run reporting match the existing issue-planning indexed daemon dry-run compatibility expectations for the selected transition.
7. Wire the new assertions into `workflowFacadeExtractionTests` so `cabal test watcher-core-test` runs them. Prefer test-local comparison helpers in `test/Main.hs` if needed; do not add broad test frameworks or unrelated fixture churn.
8. Review the final diff and confirm it is limited to the selected production helpers, their minimal imports/exports, and focused tests. Confirm there are no edits to roadmap files, `selection.md`, review artifacts, merge notes, implementation notes, golden fixtures, event schemas, compatibility facade removal, or `orchestrator/state.json`.

### Verification
Run focused validation first, then the roadmap baseline:

1. `cabal test watcher-core-test`
2. `cabal build all`
3. `git diff --check`

If staging occurs later in the round, also run:

4. `git diff --cached --check`

Reviewers should additionally inspect that `agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs` still has no concrete moifold, DocsMigration, Codex, GitHub, daemon, runtime, codec, or interpreter authority beyond the existing pure `WorkflowSpec` dependency, and that no `orchestrator/rounds/round-029/worker-plan.json` exists.
