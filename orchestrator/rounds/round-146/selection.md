### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-146-workflow-agent-spec-appserverturn-direct-owner-migration`
- Extracted item summary: Move only `test/WorkflowAgentSpec.hs` off the `CodexWatcher.AppServerClient` compatibility facade by importing `AppServerTurn (..)` from `CodexWatcher.Workflow.Agent.Codex.Client`, preserving the workflow agent role and turn-classifier assertions.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/WorkflowAgentSpec.hs` import-only migration for `AppServerTurn (..)`, with focused validation that the selected file no longer imports `CodexWatcher.AppServerClient` and still reaches the existing workflow agent role, worker/reviewer turn-classifier, and app-server turn-read assertions.
- Out of scope: production code; test bodies; helper modules; test-suite wiring; package descriptors; docs/policy text; public `CodexWatcher.AppServerClient` facade implementation, exports, or Cabal exposure; direct owner module exports; `test/TestSupport/Workflow.hs`; `test/WorkflowEventLogSpec.hs`; `test/WorkflowIndexedSpec.hs`; `test/WorkflowExecutionSpec.hs`; `test/Main.hs`; `test/FacadeImportPolicySpec.hs`; runtime compatibility files; deprecation; public API removal; package descriptor cleanup; milestone completion; release approval; terminal completion; or public compatibility removal.
- Concurrent batch context: none; state has `max_parallel_rounds: 1`, and this round is a serial import-convergence slice after rounds 140-145.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [],
  "merge_after_item_ids": [],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress after round 145 removed `test/WorkflowDocsMigrationSpec.hs` from the remaining `CodexWatcher.AppServerClient` facade importers. The current live AppServerClient scan still lists `test/WorkflowAgentSpec.hs`, and the selected file uses the facade for `AppServerTurn` values in workflow agent role and turn-classifier assertions.

This selects a concrete behavior-preserving direct-owner migration instead of another readiness-only gate, matching current steering and the accepted round 140-145 pattern. The direct owner evidence is already present: `CodexWatcher.Workflow.Agent.Codex.Client` exports `AppServerTurn (..)`, while `CodexWatcher.AppServerClient` remains only a public compatibility reexport of the direct client and transport owners. This one-file migration can therefore stay import-only without changing app-server protocol behavior, request rendering, workflow assertions, public facade exposure, Cabal metadata, docs, or policy references.

The selected slice should run before public facade or Cabal cleanup because it removes another concrete remaining workflow test facade importer while keeping `test/TestSupport/Workflow.hs`, broader workflow specs, `test/Main.hs`, policy parity owners, docs/policy references, package exposure, and public compatibility removal gates intact for later exact selections.
