### Checks Run
- Command: `cabal test watcher-core-test`
  Result: pass. The suite rebuilt and completed with `Test suite watcher-core-test: PASS`; the output included the new DSL checks:
  `workflow DSL WorkflowM accumulates effects left-to-right and short-circuits failures`,
  `workflow DSL advance builds a phase-changing transition with value, event, and effects`,
  `workflow DSL moifold projections match planned transition partitioning`, and
  `workflow DSL DocsMigration projections match all-post-commit planned transition partitioning`.

- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

- Command: `git diff --check`
  Result: pass. No whitespace errors reported.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported.

- Command: `rg -n "^(import|import qualified)" agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs`
  Result: pass. The DSL module imports only `CodexWatcher.Workflow.Spec` and `Data.Text`.

- Command: `rg -n "CodexWatcher\\.(Issue|Pr|GitHub|Daemon|Runtime|Watcher)|Data\\.Aeson|System\\.|IO|WatcherEvent|SomeWatcherState|moifold|GitHub" agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs`
  Result: pass. No forbidden concrete moifold, Codex, GitHub, daemon, runtime, codec, filesystem, or watcher-state imports/tokens were found in the DSL module.

- Command: `rg -n "CodexWatcher\\.Workflow\\.DSL|agent-workflow-core|exposed-modules|other-modules" moifold.cabal`
  Result: pass. `CodexWatcher.Workflow.DSL` remains exposed from `agent-workflow-core`; no package ownership changes were made.

- Command: `git diff -- moifold.cabal`
  Result: pass. No cabal file changes.

- Command: `rg -n "workflowDslWorkflowMAccumulationLaws|workflowDslAdvanceBuildsPhaseChangingTransition|workflowDslMoifoldProjectionParity|workflowDslDocsMigrationProjectionParity|workflowDslPrReviewFeedbackMatchesStateMachine|workflowDslTransitionLowersToPlannedTransition" test/Main.hs`
  Result: pass. The new DSL law/parity tests are wired into `workflowFacadeExtractionTests` next to the existing DSL tests.

- Command: `git diff --name-only --diff-filter=AMDR`
  Result: pass. Changed tracked files are limited to `agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs`, `test/Main.hs`, and controller active-round metadata in `orchestrator/state.json`.

### Plan Compliance
- Step 1, inspect DSL and existing DSL tests: met. The implementation extended the existing DSL test area in `test/Main.hs` and added only one minimal helper in `CodexWatcher.Workflow.DSL`.

- Step 2, add only generic DSL helpers and preserve pure planning syntax: met. `failWorkflow :: Text -> WorkflowM spec domain phase a` is a pure `Left` constructor over the existing `Either Text (a, WorkflowEffectPlan spec)` representation. `advance` still lowers through `transitionFromPlan` and `workflowPlanTransition`; no `IO`, concrete moifold, Codex, GitHub, runtime, codec, daemon, or adapter imports were added.

- Step 3, cover `WorkflowM` accumulation laws: met. `workflowDslWorkflowMAccumulationLaws` checks `pure`, sequential `emit`, Applicative ordering, Monad ordering, and failure short-circuiting before later effects.

- Step 4, cover phase-changing `advance`: met. `workflowDslAdvanceBuildsPhaseChangingTransition` constructs a typed `Transition MoifoldSpec 'PrReview 'CheckingReviews 'FixingReviews Text` and verifies value, event, effects, and planned transition projection.

- Step 5, strengthen pre/post commit projection parity for moifold and DocsMigration: met. `workflowDslMoifoldProjectionParity` compares DSL projections against both `moifoldPlannedTransitionFromEffects` and `workflowPlanTransition @MoifoldSpec`; `workflowDslDocsMigrationProjectionParity` compares against `workflowPlanTransition @DocsMigration.DocsMigrationSpec` for the all-post-commit path.

- Step 6, keep package-boundary coverage intact: met. `moifold.cabal` is unchanged, `CodexWatcher.Workflow.DSL` remains in `agent-workflow-core`, forbidden-import inspection found no concrete ownership leaks, and `watcher-core-test` passed the recursive package-boundary checks.

- Step 7, do not edit roadmap files, round planning inputs, golden fixtures, codecs, daemon/transaction logic, adapter modules, or concrete workflow transitions: met for implementation scope. The code diff touches only the DSL module and focused tests. `orchestrator/state.json` is present in the worktree diff as controller active-round/review metadata used to resolve this review; no roadmap files, `selection.md`, `plan.md`, implementation notes, golden fixtures, codecs, daemon/transaction logic, adapter modules, or concrete workflow transition implementations changed.

### Decision
**APPROVED**

### Evidence
The integrated round result matches the selected item `item-028-dsl-core-ergonomics-laws`: it adds a pure DSL failure helper and focused law/parity coverage without moving any concrete workflow transition to the DSL. The new tests prove effect accumulation order, failure short-circuiting, phase-changing transition construction, and planned pre/post commit projection parity for both moifold and DocsMigration specs.

The active roadmap verification baseline passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`. Manual package-boundary inspection also passed: `CodexWatcher.Workflow.DSL` imports only the generic workflow spec module plus `Data.Text`, and `moifold.cabal` was not changed.

Project-contract invariants remain intact. Event schemas, golden fixtures, replay/codecs, dry-run rendering, daemon/runtime/transaction behavior, adapters, compatibility facades, and concrete lifecycle policy were not changed. Workflow core still models pure planning data and does not gain direct IO authority.
