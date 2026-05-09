### Source Round
- Round id: `round-056`
- Merged commit: `8a6bcf6`
- Evidence: `orchestrator/rounds/round-056/review-record.json`, `orchestrator/rounds/round-056/review.md`, `orchestrator/rounds/round-056/import-facade-cleanup-policy.md`, and `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.

### Roadmap Change
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/roadmap.md`

### Rationale
Round 056 was approved as the import-facade cleanup policy round for `direction-005-import-facade-cleanup-policy` and merged as `8a6bcf6`. Its policy artifact and the updated compatibility deprecation policy record preferred reusable-package imports, refreshed selected-facade import counts, Cabal exposure, keep/defer classifications, protecting tests, and the missing gates before future deprecation or removal for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`, and `CodexWatcher.Workflow.Permission`.

This completes the import-facade cleanup policy direction for milestone 003, but the milestone remains pending because `direction-006-runtime-compatibility-cleanup-policy` is still open. The approved evidence explicitly leaves runtime compatibility-file policy, compatibility-file migration or removal, runtime behavior changes, roadmap expansion, and removal approval untouched.

This is a status-only update. It keeps roadmap revision `rev-001` active and does not create a new revision because no future coordination semantics changed.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
