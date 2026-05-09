### Source Round
- Round id: `round-061`
- Merged commit: `ef04cd3`
- Evidence: `orchestrator/rounds/round-061/selection.md`, `orchestrator/rounds/round-061/app-server-client-migration-readiness.md`, `orchestrator/rounds/round-061/implementation-notes.md`, `orchestrator/rounds/round-061/review.md`, `orchestrator/rounds/round-061/review-record.json`, and `orchestrator/rounds/round-061/merge.md`.

### Roadmap Change
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`

### Rationale
Round 061 was approved and merged as the evidence-only completion of `direction-010-app-server-client-migration-readiness` under `milestone-005-import-facade-follow-up-evidence`. Its accepted evidence records a refreshed `CodexWatcher.AppServerClient` selected-facade import count of 28, replacement module exposure for `CodexWatcher.Workflow.Agent.Codex.Client`, `Protocol`, and `Transport`, current compatibility facade exposure from `moifold.cabal`, current app-server behavior coverage, and caller grouping by client/parser, transport/session, protocol/request, and product-policy ownership.

The roadmap now marks only direction 010 complete via round 061 and records conservative milestone 005 progress. The milestone itself remains pending because `direction-011-event-log-concrete-helper-boundary` and `direction-012-workflow-permission-public-api-review` remain unfinished. This update does not authorize deprecation, removal, migration, Cabal exposure changes, production import rewrites, runtime compatibility changes, package publication, upload, or release.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
