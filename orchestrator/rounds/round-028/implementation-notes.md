### Changes Made
- `agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs`: added `failWorkflow`, a pure DSL failure constructor over the existing `WorkflowM` `Either Text` representation, so failure short-circuiting can be tested without granting IO authority or changing transition lowering.
- `test/Main.hs`: extended the existing `workflowFacadeExtractionTests` DSL block with focused coverage for `WorkflowM` pure/no-effect behavior, sequential/applicative/monadic effect accumulation order, failure short-circuiting, phase-changing `advance` construction, and moifold plus DocsMigration pre/post commit projection parity against `workflowPlanTransition` / `moifoldPlannedTransitionFromEffects`.

### Tests
- `test/Main.hs`: `workflowDslWorkflowMAccumulationLaws` verifies pure values add no effects, sequential `emit` order is preserved, Applicative and Monad composition accumulate left-to-right, and `failWorkflow` short-circuits before later effects.
- `test/Main.hs`: `workflowDslAdvanceBuildsPhaseChangingTransition` verifies `advance` constructs a typed phase-changing `Transition` while preserving the user value, event, and planned effect partition.
- `test/Main.hs`: `workflowDslMoifoldProjectionParity` verifies DSL transition accessors match both `moifoldPlannedTransitionFromEffects` and `workflowPlanTransition @MoifoldSpec` for mixed pre/post moifold effects.
- `test/Main.hs`: `workflowDslDocsMigrationProjectionParity` verifies DSL transition accessors match `workflowPlanTransition @DocsMigration.DocsMigrationSpec` for the DocsMigration all-post-commit effect path.
- Command: `cabal test watcher-core-test`
  Result: failed first with `-Wunused-do-bind` in the new failure short-circuit test; fixed by binding the discarded `failWorkflow` result explicitly.
- Command: `cabal test watcher-core-test`
  Result: passed. `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `cabal build all`
  Result: passed.
- Command: `git diff --check`
  Result: passed with no output.
- Command: `git diff --cached --check`
  Result: passed with no output; no staged changes were present.

### Notes
No real moifold or DocsMigration workflow transitions were ported to the DSL. No event codecs, golden fixtures, daemon/runtime/transaction logic, adapter modules, roadmap files, `selection.md`, or `plan.md` were edited. `orchestrator/state.json` was already modified in the worktree and was left untouched.
