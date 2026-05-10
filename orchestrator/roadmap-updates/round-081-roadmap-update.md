### Source Round
- Round id: `round-081-cabal-exposure-decision`
- Merged commit: `ecfb67a`
- Evidence: `orchestrator/rounds/round-081/selection.md`, `orchestrator/rounds/round-081/cabal-exposure-decision.md`, `orchestrator/rounds/round-081/review.md`, `orchestrator/rounds/round-081/review-record.json`, and `orchestrator/rounds/round-081/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-10-00-facade-removal-readiness`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/roadmap.md`; `orchestrator/roadmap-updates/round-081-roadmap-update.md`

### Rationale
Round 081 completed `direction-007-cabal-exposure-decision` as an approved
artifact-only Cabal exposure decision. The approved decision records all four
selected facades as `defer`: `CodexWatcher.AppServerClient`,
`CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and
`CodexWatcher.Workflow.Permission` remain exposed in `moifold.cabal` for now.

The merged round approved no exposed-module removal, Cabal/package descriptor
change, public API change, documentation change, deprecation wording, removal,
facade deletion, runtime compatibility change, event schema change,
healthcheck or repair change, import migration, roadmap state change, or
release/publication change. The evidence therefore justifies a status-only
update in the active `rev-001` bundle: mark direction 007 complete and mark
milestone 003 complete because both public decision-gate directions, 006 and
007, are complete. Milestone 004 remains pending because no exact removal or
terminal decision report has been selected or approved.

No new roadmap revision is proposed because the result changes progress status
and carries blockers forward without changing roadmap scope, sequencing,
boundaries, or coordination rules.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
