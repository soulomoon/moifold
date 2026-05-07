### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

- Command: `cabal test watcher-core-test`
  Result: pass. The suite built and ran `watcher-core-test`; Cabal reported `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.` Output included the new `PASS indexed workflow existentials preserve labels and typed transition boundaries` and `PASS indexed workflow PR-review mergeability adapter matches compatibility facade` assertions, plus existing golden replay, event codec, facade, daemon, dry-run, and action-ordering checks.

- Command: `git diff --check`
  Result: pass. No whitespace errors reported.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported.

- Command: `rg -n "CodexWatcher.Workflow.Indexed.Spec" moifold.cabal`
  Result: pass. `moifold.cabal:41` exposes `CodexWatcher.Workflow.Indexed.Spec` from the `agent-workflow-core` library stanza.

- Command: `rg -n "^import |type family WorkflowIndex|class IndexedWorkflowSpec|data IndexedPlannedTransition|data SomeIndexedWorkflowState|data SomeIndexedWorkflowEvent|data SomeIndexedWorkflowObservation|data SomeIndexedWorkflowEffect|data SomeIndexedWorkflowEffectPlan|data SomeIndexedPlannedTransition|data SomeIndexedWorkflowObservedTick|data SomeIndexedWorkflowReplayResult" agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`
  Result: pass. The new module imports only `Data.Kind (Type)` and `Data.Text (Text)` and defines `WorkflowIndex`, `IndexedWorkflowSpec`, `IndexedPlannedTransition`, and state/event/observation/effect/effect-plan/transition/observed-tick/replay-result existential wrappers.

- Command: `rg -n "^import .*CodexWatcher|^import .*Moifold|^import .*WatcherEvent|^import .*SomeWatcherState|^import .*Aeson|^import .*GitHub|^import .*AppServer|^import .*Interpreter|^import .*Runtime" agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`
  Result: pass. No matches; the indexed core module does not import moifold lifecycle types, GitHub adapters, app-server transport, runtime interpreters, or Aeson.

- Command: `rg -n "SomeWatcherState|WatcherEvent|EventReplayResult|DaemonObservation|SomeEffect|MoifoldSpec" agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`
  Result: pass. No matches; the new core module does not depend on compatibility facade concrete types.

- Command: `rg -n "workflowIndexedSpecModuleKeepsCoreBoundary|workflowIndexedSpecExistentialsPreserveLabels|workflowIndexedSpecCompatibilityParityForMergeability|indexed workflow existentials preserve labels and typed transition boundaries|indexed workflow PR-review mergeability adapter matches compatibility facade" test/Main.hs`
  Result: pass. `test/Main.hs` registers the module-boundary test at line 6184, the existential/typed-boundary test at line 6215, the PR-review mergeability parity test at line 6216, and defines/asserts those checks at lines 6267, 7821, 7856, 7881, and 7930.

- Command: `git diff --name-only -- src/CodexWatcher/EventLog src/CodexWatcher/EventLogRepair.hs src/CodexWatcher/Daemon.hs src/CodexWatcher/DaemonLoop.hs src/CodexWatcher/DaemonLoop src/CodexWatcher/ActionExecutor.hs src/CodexWatcher/Workflow/Types.hs agent-workflow-core/src/CodexWatcher/Workflow/Spec.hs agent-workflow-core/src/CodexWatcher/Workflow/Daemon/Core.hs golden`
  Result: pass. No output; the round does not change event schema/event-log, daemon, dry-run/action executor, compatibility facade, daemon core, or golden fixture files.

### Plan Compliance
- Step 1, add `agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`: met. The new module exists and builds.
- Step 2, define an indexed class with index-aware associated types: met. `IndexedWorkflowSpec` defines associated state, event, observation, observed tick, effect, effect plan, replay result, and error types, with source/target parameters on transition-bearing types.
- Step 3, define indexed transitions preserving pre-commit/post-commit split: met. `IndexedPlannedTransition` carries an indexed event plus separate pre-commit and post-commit effect plans.
- Step 4, define existential wrappers without moifold-specific dependencies: met. Existential wrappers are present for state, event, observation, effect, effect plan, planned transition, observed tick, and replay result; focused `rg` checks found no compatibility concrete types in the core module.
- Step 5, add indexed helper functions with distinct names: met. The module exposes `indexedWorkflowPlanObservation`, transition label helpers, effect-plan label helpers, and `someIndexed...` projection helpers.
- Step 6, expose the module from `agent-workflow-core` without new dependencies: met. The Cabal diff adds only the exposed-module line for `CodexWatcher.Workflow.Indexed.Spec`.
- Step 7, update boundary coverage: met. `workflowIndexedSpecModuleKeepsCoreBoundary` is registered in `workflowFacadeExtractionTests`, checks the new module, and the core Cabal exposure assertion includes the module.
- Step 8, add focused indexed-spec tests: met. The suite includes module-boundary coverage, existential label/typed transition-boundary coverage, and PR-review mergeability compatibility parity coverage.
- Step 9, keep current facade tests intact: met. `watcher-core-test` still passes existing workflow facade, DocsMigration, PR-review mergeability, golden replay, daemon, dry-run, and action-ordering checks.
- Step 10, inspect diff for forbidden behavioral changes: met for the integrated implementation. The only implementation files are the new indexed module, Cabal exposure, and tests. There are no diffs under event schema/event-log files, golden fixtures, daemon/dry-run/action-ordering files, or the existing compatibility facade. `orchestrator/state.json` contains the active review-round controller state that was already present for this review stage; I did not edit it.

### Decision
**APPROVED**

### Evidence
The integrated round introduces a parallel indexed API in `agent-workflow-core` while keeping compatibility behavior pinned. `CodexWatcher.Workflow.Indexed.Spec` is exposed by `moifold.cabal`, imports only `Data.Kind` and `Data.Text`, defines the indexed class, typed transition, and existential wrappers, and contains no `WatcherEvent`, `SomeWatcherState`, `EventReplayResult`, `DaemonObservation`, `SomeEffect`, or `MoifoldSpec` references.

The regression suite covers the new indexed API and existing behavior. `watcher-core-test` passed with explicit PASS lines for indexed existential label/type-boundary preservation and PR-review mergeability parity, while existing golden event-log, event codec, facade, daemon, dry-run, and action-ordering assertions remained green. Source-level diff checks found no changes to event schema/golden/daemon/dry-run/action-ordering/facade paths.
