### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-009-facade-import-scan-refresh`
- Extracted item id: `round-097-facade-import-scan-refresh`
- Extracted item summary: Refresh the current import and exposure inventory for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission` across `src`, `app`, `test`, package descriptors, docs, and standalone package candidates after the completed test-split and runtime-compatibility evidence rounds, without changing imports or public surfaces.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: round-local evidence that records current selected-facade import users, Cabal exposed-module entries, docs references, standalone package-candidate references, obvious direct-owner replacement candidates, and blockers for later `AppServerClient`, `Core.Ids`, `Workflow.EventLog`, and `Workflow.Permission` import-convergence slices.
- Out of scope: production import edits; test import edits; Cabal exposure changes; public deprecation or removal; runtime compatibility file migration, deletion, rename, or cleanup classification; healthcheck, repair, replay, restart, prompt, or event-schema behavior changes; large-module decomposition; roadmap edits; controller state edits; release approval; milestone completion claims.
- Concurrent batch context: none; active state is serial with `max_parallel_rounds: 1`, and this selection opens a single evidence round before any import-convergence implementation slice.

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
Milestone 001 is complete, so `milestone-003-import-convergence-package-boundaries` is dependency-ready under the active roadmap. The selected direction is the smallest valuable extraction in that milestone because it is evidence-only and is the required precondition for later `AppServerClient`, `Core.Ids`, `Workflow.EventLog`, and `Workflow.Permission` import-convergence work.

Round 096 completed the current selected healthcheck read/non-read contract evidence under milestone 002, but the active roadmap still keeps milestone 002 in progress and explicitly does not approve runtime compatibility cleanup classification, migration, deletion, public deprecation, or removal. That means milestone 005 and final removal gates are not ready for selection, while milestone 003 can lawfully proceed because it depends only on the completed test-topology inventory.

Refreshing the facade import scan now keeps the cleanup family moving without guessing from stale counts recorded before the recent test-module splits and fixture rounds. The round should produce current, reviewable evidence for where compatibility facades are still used and why, while preserving public facade availability and leaving all actual import migrations to later selected directions.
