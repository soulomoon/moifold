### Changes Made
- `src/CodexWatcher/Workflow/Execution.hs`: replaced the `CodexWatcher.Core.Ids (RequestId)` compatibility-facade import with the direct owner import `CodexWatcher.Workflow.Agent.Ids (RequestId)`.
- `orchestrator/rounds/round-099/implementation-notes.md`: recorded the scoped import-convergence change and verification evidence for the round.

### Tests
- `test/WorkflowExecutionSpec.hs`: covered by `cabal test watcher-core-test`; existing workflow execution checks still pass, including request-id progression, legacy dry-run parity, action partitioning, and checked execution behavior.
- Full package build: `cabal build all` passed with no package descriptor or `cabal.project` edits.

### Notes
No behavior, request-id threading, constructor, parser, renderer, command output, dry-run output, action-order, public facade exposure, package descriptor, roadmap, selection, plan, review, merge, or controller-state change was made by this implementation.
