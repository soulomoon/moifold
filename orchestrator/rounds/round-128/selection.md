### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id (`milestone_id`): `milestone-003-import-convergence-package-boundaries`
- Direction id (`direction_id`): `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id (`extracted_item_id`): `round-128-daemon-eventlog-audit-direct-owner-import-convergence`
- Extracted item summary: Move only `src/CodexWatcher/Daemon.hs` off the mixed `CodexWatcher.Workflow.EventLog` compatibility facade for daemon audit helper usage, using the existing direct `CodexWatcher.Workflow.Audit` owner import while preserving daemon observed-tick, audit, transaction, replay, event-commit, compatibility-write, and public-export behavior.
- Roadmap id (`roadmap_id`): `2026-05-11-00-highest-value-cleanup`
- Roadmap revision (`roadmap_revision`): `rev-001`
- Roadmap dir (`roadmap_dir`): `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: production import convergence in `src/CodexWatcher/Daemon.hs`; replace the remaining exact `CodexWatcher.Workflow.EventLog` facade import and its audit-only qualified uses with direct owner references from `CodexWatcher.Workflow.Audit`; keep existing direct event commit ownership through `CodexWatcher.Workflow.EventLog.Commit.Core`; preserve daemon audit labels, daemon recommendations, observed transaction failure formatting, dry-run and execute transaction behavior, replay behavior, append order, compatibility writes, and exported API shape.
- Out of scope: `src/CodexWatcher/Workflow/DocsMigration.hs`, tests and test-support facade imports, `CodexWatcher.Workflow.EventLog` or `CodexWatcher.Workflow.Permission` facade modules, public facade exposure, `moifold.cabal`, package descriptors, docs, runtime compatibility files, event JSON `type` fields, golden fixture shapes, daemon behavior changes, large-module decomposition, Workflow.Permission migration, public deprecation/removal, Cabal exposure removal, release approval, milestone completion, terminal completion, or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and the active roadmap keeps milestone 003 and direction 012 in progress after round 127. Round 127 removed the DocsMigration production `CodexWatcher.Workflow.EventLog` facade import, leaving `src/CodexWatcher/Daemon.hs` as the remaining production exact EventLog facade importer; test, test-support, docs, public facade, and Cabal exposure references remain intentionally out of scope.

This is the smallest next valuable direction-012 extraction because `Daemon.hs` uses the facade only for audit helpers while it already imports `CodexWatcher.Workflow.Audit` and direct event commit ownership. The round-104 readiness artifact explicitly names Daemon as a later convergence candidate once daemon audit and transaction behavior are verified, and the current focused workflow execution coverage exercises daemon observed audit projection, transaction failure audit labels, and dry-run/execute transaction parity. That makes a narrow import-only Daemon convergence slice a better next serial round than large-module decomposition, runtime compatibility cleanup gates, public deprecation/removal, Cabal exposure work, or a broad test-policy migration.

This selection does not approve facade removal, public deprecation, package descriptor cleanup, runtime compatibility-file cleanup, remaining test/support import migration, milestone completion, terminal completion, or public compatibility removal.
