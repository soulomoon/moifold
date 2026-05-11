### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-127-docs-migration-eventlog-direct-owner-import-convergence`
- Extracted item summary: Move only `src/CodexWatcher/Workflow/DocsMigration.hs` from the mixed `CodexWatcher.Workflow.EventLog` compatibility facade to direct event-log and audit owner imports, preserving DocsMigration replay, fixture, audit, daemon-parity, transaction, and permission behavior covered by the focused DocsMigration tests.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: production import convergence in `src/CodexWatcher/Workflow/DocsMigration.hs`; replace the `CodexWatcher.Workflow.EventLog` facade import with direct owner imports for the existing generic event-log, replay, fixture-contract, and audit symbols used by DocsMigration; make only the minimal type-spelling adjustments required by direct-owner audit types; preserve DocsMigration event labels, fixture contract, replay failure formatting, daemon audit reports, dry-run/execute transaction behavior, permission validation, and public exports.
- Out of scope: `src/CodexWatcher/Daemon.hs`, test/support facade imports, `CodexWatcher.Workflow.EventLog` or `CodexWatcher.Workflow.Permission` facade changes, moifold wrapper behavior, event JSON `type` fields, golden fixture shape changes, direct-owner module behavior, package descriptors, public API/Cabal exposure cleanup, docs, runtime compatibility files, public deprecation/removal, release approval, milestone completion, terminal completion, or public compatibility removal.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds: 1`, so this selection opens one round only.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and the round-126 post-merge scan shows the `CodexWatcher.AppServerClient` production import-convergence lane has reached a natural pause: remaining AppServerClient hits are public facade/Cabal exposure, tests/test-support, and docs/policy references.

Direction 011 is not the next smallest high-value choice because round 103 closed the easy `Core.Ids` single-domain queue; later `Core.Ids` work needs split-import or bridge-readiness evidence around parser/renderer, replay, prompt/loop-policy, runtime compatibility, or test-policy surfaces. Direction 012 is the better next dependency-ready slice because round 104 already classified `src/CodexWatcher/Workflow/DocsMigration.hs` as the clearest source direct-owner candidate once DocsMigration replay/audit behavior gates are respected.

This extraction is smaller than a daemon split or public facade cleanup: it touches one production module, keeps both compatibility facades exposed, leaves tests/support policy imports intact, and relies on existing focused DocsMigration coverage for replay/detail failures, fixture contracts, daemon audit labels and reports, dry-run versus execute parity, transaction behavior, and permission soundness. It produces concrete import-convergence evidence after AppServerClient production convergence without claiming milestone completion or removal approval.
