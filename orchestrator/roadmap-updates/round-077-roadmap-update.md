### Source Round
- Round id: round-077
- Merged commit: a37f71a
- Evidence: `orchestrator/rounds/round-077/implementation-notes.md`, `orchestrator/rounds/round-077/review.md`, `orchestrator/rounds/round-077/review-record.json`, and `orchestrator/rounds/round-077/merge.md`

### Roadmap Change
- Roadmap id: 2026-05-10-00-facade-removal-readiness
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/roadmap.md`

### Rationale
Round 077 was approved and merged as the behavior-neutral internal import
migration slice for `milestone-002-internal-import-migration` and
`direction-003-appserverclient-import-migration`. The roadmap now marks
direction 003 complete via commit `a37f71a` and marks milestone 002 in progress.

The accepted evidence shows that selected explicit `CodexWatcher.AppServerClient`
imports were moved to direct owner modules: endpoint-only imports now use
`CodexWatcher.Workflow.Agent.Codex.Transport`, client-value imports now use
`CodexWatcher.Workflow.Agent.Codex.Client`, and `test/AppServerSpec.hs` exercises
the app-server behavior checks through direct owner imports. The compatibility
facade remains live and unchanged.

The milestone remains open because `direction-004-core-ids-split-import-migration`
and `direction-005-eventlog-permission-readiness` remain pending. Round 077
recorded 13 remaining broad/deferred `CodexWatcher.AppServerClient` imports;
that deferred inventory is migration-readiness evidence only and is not removal,
deprecation, Cabal exposure, or public API approval.

This update does not approve or perform facade removal, deprecation, Cabal
exposure changes, docs or release wording, runtime compatibility-file cleanup,
event-schema changes, healthcheck or repair behavior changes, publication,
release, or package upload. The prior terminal compatibility-surface hold
remains non-approval for removal.

### State Activation
- Requires state.json roadmap metadata update: no
- Proposed revision remains: rev-001
- New roadmap_dir when applicable: n/a
