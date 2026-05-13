### Changes Made
- `test/WorkflowEventLogSpec.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. No assertions, fixtures, PASS labels, aggregate wiring, event JSON expectations, or replay behavior were changed.

### Tests
- `test/WorkflowEventLogSpec.hs`: covered by `cabal test watcher-core-test`; the spec compiled and the full `watcher-core-test` suite passed.
- `rg -n "CodexWatcher.Core.Ids" test/WorkflowEventLogSpec.hs`: exited 1 with no output, which is the expected no-match result.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff -- test/WorkflowEventLogSpec.hs`: inspected; the diff is limited to removing the facade import and adding the two direct owner imports.

### Notes
No constructor or import-name adjustment beyond the planner-specified direct imports was needed.
