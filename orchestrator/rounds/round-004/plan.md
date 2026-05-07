### Goal
Introduce a parallel indexed `WorkflowSpec` API in `agent-workflow-core` without changing the existing compatibility `WorkflowSpec` facade, moifold event/state representations, event schemas, golden logs, daemon result shapes, dry-run output, action ordering, or current facade behavior.

### Approach
Add a new exposed core module beside `CodexWatcher.Workflow.Spec`, tentatively `CodexWatcher.Workflow.Indexed.Spec`, that owns the indexed API. Keep `CodexWatcher.Workflow.Spec` and `src/CodexWatcher/Workflow/Types.hs` as compatibility surfaces for existing `MoifoldSpec` code.

The indexed module should define a separate class and type family surface, not a replacement for the existing class. Its associated types should make state, event, observation, and effect plans index-aware, with transitions carrying source and target indices. It should also expose existential wrappers for crossing unindexed boundaries in later rounds.

The first implementation slice should be API-first and parity-tested. Do not rewrite `WatcherEvent`, `SomeWatcherState`, `EventReplayResult`, daemon tick result records, codecs, fixture files, CLI output rendering, or execution ordering. Any moifold-specific bridge needed for tests should be narrow and local to the existing facade/test surface, with the compatibility path remaining the source of truth.

Worker fan-out is not used. The roadmap marks this item as `Parallel safe: no`, `orchestrator/state.json` records `worker_mode: none`, and the implementation touches a shared API boundary plus its single integrated test surface.

### Steps
1. Add `agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`.
2. In the new module, define an indexed class such as `IndexedWorkflowSpec spec` with associated types for the workflow index kind, indexed state, indexed event, indexed observation, indexed observed tick, indexed effect, indexed effect plan, indexed replay result, and indexed error.
3. Define indexed transition records that preserve the existing pre-commit/post-commit split, with event/source/target indices visible in the type and with effect plans still ordered exactly as the existing facade expects.
4. Define existential wrappers for indexed states, events, observations, effects, effect plans, transitions, observed ticks, and replay results. The wrappers should expose label/projection helpers only where needed for tests, and should not depend on moifold-specific types.
5. Add helper functions equivalent to the compatibility facade's `workflowPlanObservation` and transition-label helpers for the indexed API. Keep names distinct from the compatibility facade to avoid accidental import ambiguity.
6. Expose `CodexWatcher.Workflow.Indexed.Spec` from the `agent-workflow-core` library stanza in `moifold.cabal`. Do not add new dependencies to `agent-workflow-core`.
7. Update boundary coverage in `test/Main.hs` so the new indexed module is required in the core exposure assertion and still rejected by the existing forbidden import, forbidden concrete token, and dependency guards.
8. Add focused indexed-spec tests in `test/Main.hs` under the existing workflow facade extraction checks:
   - `workflowIndexedSpecModuleKeepsCoreBoundary`: the new module exposes the indexed class, indexed transition type, and existential wrappers while importing no moifold-specific modules.
   - `workflowIndexedSpecExistentialsPreserveLabels`: a small test-only indexed spec can wrap and label a state, event, observation, effect plan, and transition through the existential API without losing source/target index evidence needed by callers.
   - `workflowIndexedSpecCompatibilityParityForMergeability`: for the existing PR-review mergeability slice, compare the current compatibility path with a narrow indexed test adapter and assert the same committed event, next state label, effect plan, and replay result. Use the current `WatcherEvent` and `SomeWatcherState` values through wrappers; do not replace or reshape them.
9. Keep the current facade tests intact, especially DocsMigration and PR-review mergeability law coverage, so existing behavior remains pinned while the indexed API is introduced.
10. Before review, inspect the diff to confirm there are no changes to `CodexWatcher.EventLog.Types`, golden fixtures, daemon result records, dry-run rendering, runtime command rendering, action ordering logic, roadmap files, `orchestrator/state.json`, implementation notes, review files, or merge files.

### Verification
Run the exact baseline commands from the active verification bundle:

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check`

Focused indexed-spec checks are the new assertions added to `watcher-core-test`:

- The indexed spec module remains generic and exposed from `agent-workflow-core`.
- Existential wrappers preserve labels and typed transition boundaries.
- The PR-review mergeability indexed adapter and current compatibility path emit the same event, next state label, effect plan, and replay result.

The round passes only if the full `watcher-core-test` suite still covers existing golden replay, package-boundary, workflow-facade, daemon, execution, dry-run, and action-ordering behavior without changing their expected outputs.
