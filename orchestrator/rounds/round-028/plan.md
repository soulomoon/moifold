### Goal
Tighten the pure `WorkflowM` / `Transition` / `advance` DSL surface in `agent-workflow-core` and add focused `watcher-core-test` law coverage proving that DSL-authored transitions preserve effect accumulation order, phase-changing transition construction, and `PlannedTransition` pre/post commit projections before real workflow transitions are ported to the DSL.

### Approach
Keep this round sequential and narrowly scoped to the DSL core slice selected for `item-028-dsl-core-ergonomics-laws`. The implementation should make additive API refinements in `agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs` only when the tests need clearer, generic access to the existing pure planning data; it must not port DocsMigration, moifold, daemon, transaction, codec, fixture, or adapter behavior to the DSL.

Use the existing `workflowFacadeExtractionTests` area in `test/Main.hs` as the focused test surface. Extend the current DSL assertions near `workflowDslPrReviewFeedbackMatchesStateMachine` and `workflowDslTransitionLowersToPlannedTransition` instead of creating a separate broad suite. The tests should compare DSL lowering against `workflowPlanTransition` / existing planned-transition helpers so the round proves parity with current `PlannedTransition` semantics rather than asserting a duplicated implementation detail.

No worker fan-out is justified for this round. The controller allows only one active round, the selected write scope is small, and the likely edits are coupled across one core module and one test section.

### Steps
1. Inspect `CodexWatcher.Workflow.DSL` and the two existing DSL tests in `test/Main.hs` to identify any minimal additive helpers needed for law-style assertions, such as accessors or constructors that expose existing `Transition` data without granting IO authority or changing `PlannedTransition`.
2. Add or refine only generic DSL helpers in `agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs`. Preserve `WorkflowM` as pure planning syntax over `Either Text (a, WorkflowEffectPlan spec)`, keep `advance` lowering through `workflowPlanTransition`, and do not introduce `IO`, concrete moifold imports, event codecs, runtime interpreters, or adapter dependencies.
3. Extend focused `watcher-core-test` coverage in `test/Main.hs` for `WorkflowM` accumulation laws:
   - `pure` contributes no effects and preserves the returned value.
   - sequential `emit` calls append effect plans in program order.
   - Applicative and Monad composition preserve left-to-right effect ordering.
   - a failed `WorkflowM` result short-circuits without appending later effects.
4. Add focused transition-construction coverage proving `advance` can construct a phase-changing `Transition spec domain from to a` while preserving the user value, event, and accumulated effect plan.
5. Strengthen pre/post commit projection parity tests for both existing partition styles:
   - moifold effects with mixed pre/post commit actions compare `transitionPlannedTransition`, `transitionPreCommitEffects`, `transitionPostCommitEffects`, and combined `transitionEffects` against `moifoldPlannedTransitionFromEffects` or `workflowPlanTransition @MoifoldSpec`.
   - DocsMigration effects compare the same accessors against `workflowPlanTransition @DocsMigration.DocsMigrationSpec`, covering the all-post-commit path without changing DocsMigration transitions.
6. Keep package-boundary coverage intact: if the DSL module gains exports, ensure `moifold.cabal` remains limited to the existing `agent-workflow-core` ownership and that source-scan tests continue to reject moifold, Codex, GitHub, daemon, runtime, and codec imports from core.
7. Do not edit roadmap files, `selection.md`, review artifacts, `state.json`, event golden fixtures, event codecs, daemon/transaction logic, adapter modules, or concrete workflow transition implementations.

### Verification
Run the roadmap baseline checks after implementation:

1. `cabal test watcher-core-test`
2. `cabal build all`
3. `git diff --check`

If changes are staged by a later phase, also run:

4. `git diff --cached --check`

Reviewers should additionally inspect that `agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs` still has no concrete moifold/Codex/GitHub/runtime/codec imports, that all new DSL tests are called from `workflowFacadeExtractionTests`, and that no golden fixtures or event schema behavior changed.
