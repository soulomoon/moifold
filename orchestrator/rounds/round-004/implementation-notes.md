### Changes Made
- `agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`: added the parallel indexed workflow API with typed source/target transition records, pre-commit/post-commit effect-plan split, existential wrappers, label helpers, and observation planning helpers.
- `moifold.cabal`: exposed `CodexWatcher.Workflow.Indexed.Spec` from the `agent-workflow-core` library without adding dependencies.
- `test/Main.hs`: added boundary coverage for the new core module, existential label/type-boundary checks, and a narrow PR-review mergeability indexed adapter that delegates through the compatibility facade.

### Tests
- `test/Main.hs`: `workflowIndexedSpecModuleKeepsCoreBoundary` verifies the new module remains generic, exposed, and covered by the core boundary guards.
- `test/Main.hs`: `workflowIndexedSpecExistentialsPreserveLabels` verifies existential wrappers preserve state, event, observation, effect-plan, transition, observed-tick, and replay labels across typed source/target boundaries.
- `test/Main.hs`: `workflowIndexedSpecCompatibilityParityForMergeability` verifies the indexed PR-review mergeability adapter matches the current compatibility path for committed event, next state label, effect plan, and replay result.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.

### Notes
No blockers. The implementation does not change `WatcherEvent`, `SomeWatcherState`, event codecs, golden fixtures, daemon result records, dry-run rendering, runtime command rendering, or action ordering. Existing `orchestrator/state.json` and round files were already dirty/untracked in this worktree; this round only adds the implementation notes under `round-004`.
