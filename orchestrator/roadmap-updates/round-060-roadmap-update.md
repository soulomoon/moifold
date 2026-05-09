### Source Round
- Round id: `round-060`
- Merged commit: `329e827`
- Evidence: `orchestrator/rounds/round-060/selection.md`, `orchestrator/rounds/round-060/core-ids-split-import-evidence.md`, `orchestrator/rounds/round-060/implementation-notes.md`, `orchestrator/rounds/round-060/review.md`, `orchestrator/rounds/round-060/review-record.json`, and `orchestrator/rounds/round-060/merge.md`.

### Roadmap Change
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`

### Rationale
Round 060 was approved and merged as the evidence-only completion of `direction-009-core-ids-split-import-evidence` under `milestone-005-import-facade-follow-up-evidence`. Its accepted evidence records the current `CodexWatcher.Core.Ids` facade shape, a refreshed recursive combined-facade import scan, split `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` usage, package-boundary exposure assertions, ownership grouping, and conservative migration risks.

The roadmap now marks only direction 009 complete via round 060 and records milestone 005 progress. The milestone itself remains pending because `direction-010-app-server-client-migration-readiness`, `direction-011-event-log-concrete-helper-boundary`, and `direction-012-workflow-permission-public-api-review` remain unfinished. This update does not authorize deprecation, removal, migration, Cabal exposure changes, production import rewrites, runtime compatibility changes, package publication, upload, or release.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
