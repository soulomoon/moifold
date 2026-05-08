### Changes Made
- `agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`: added the additive `WorkflowSpecIndexedBridge` record and exported delegate helpers for indexed initial/apply/observe/transition/replay/validation/permission/terminal/label/effect projection hooks.
- `src/CodexWatcher/Workflow/DocsMigration.hs`: migrated the `IndexedWorkflowSpec DocsMigrationSpec` hook bodies through the new bridge while keeping the existing public constructors, replay result projection, event codec, fixture contract, daemon helpers, and effect behavior unchanged.
- `src/CodexWatcher/Workflow/Moifold/PrReview/Checking/Indexed.hs`: migrated the representative moifold PR-review checking indexed adapter through the bridge without changing the adapter's public wrapper types.
- `test/Main.hs`: added source-scan coverage for the generic bridge API and its DocsMigration/PR-review checking migrations, and kept the existing parity assertions covering labels, replay projection, terminal status, validation, permission, and pre/post effect labels.

### Tests
- `test/Main.hs`: `workflowSpecIndexedBridgeSourceScans` verifies the bridge lives in `agent-workflow-core`, remains generic, and is used by DocsMigration plus the representative PR-review checking adapter.
- `test/Main.hs`: existing DocsMigration indexed workflow tests verify bridged draft/validation/blocked observations still match unindexed behavior for labels, replay, terminal semantics, validation, permission, fixture codec, and post-commit effect labels.
- `test/Main.hs`: existing PR-review checking indexed workflow tests now exercise the bridged adapter and still match `MoifoldSpec` behavior for labels, replay, validation, permission, and effect labels.

### Notes
Commands run:

- `cabal test watcher-core-test --test-options='--pattern workflow'` before edits: passed.
- `cabal test watcher-core-test --test-options='--pattern workflow'` after first bridge draft: failed to compile `agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs` because helper functions did not bring the bridge constructor constraints into scope and used record-dot syntax in a module without that extension.
- `cabal test watcher-core-test --test-options='--pattern workflow'` after tightening helper definitions: failed to compile `src/CodexWatcher/Workflow/DocsMigration.hs` because `PlannedTransition` still needed to be imported for the unindexed DocsMigration helper functions.
- `cabal test watcher-core-test --test-options='--pattern workflow'` after restoring the import: failed one source scan, `workflow spec inventory covers current moifold indexed adapters`, because the scan still required the old `indexedWorkflowReplayEvents events` spelling.
- `cabal test watcher-core-test --test-options='--pattern workflow'` after updating the source scan: passed.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; there were no staged changes.

Event codecs, golden fixtures, daemon/runtime behavior, roadmap files, `state.json`, `selection.md`, and `plan.md` were not intentionally changed. `orchestrator/state.json` was already modified when this implementation pass started and was left untouched.
