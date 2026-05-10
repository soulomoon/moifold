### Source Round
- Round id: round-076
- Merged commit: 606ad40
- Evidence: `orchestrator/rounds/round-076/implementation-notes.md`, `orchestrator/rounds/round-076/review.md`, `orchestrator/rounds/round-076/review-record.json`, and `orchestrator/rounds/round-076/merge.md`

### Roadmap Change
- Roadmap id: 2026-05-10-00-facade-removal-readiness
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/roadmap.md`

### Rationale
Round 076 was approved and merged as the artifact-only behavior-owner
classification for `milestone-001-current-facade-evidence` and
`direction-002-behavior-owner-classification`. The roadmap now marks direction
002 complete via commit `606ad40`.

Because round 075 already completed `direction-001-import-scan-refresh`, both
candidate directions in milestone 001 are now complete. The roadmap therefore
marks `milestone-001-current-facade-evidence` complete while preserving the
active roadmap id and revision.

The accepted evidence classifies `CodexWatcher.AppServerClient` and
`CodexWatcher.Core.Ids` as pure reexport convenience facades, and
`CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` as mixed
surfaces with concrete moifold behavior bridges. This is descriptive readiness
evidence only.

This update does not approve or perform migration, deprecation, Cabal exposure
changes, public facade removal, runtime compatibility-file cleanup, event-schema
changes, healthcheck or repair behavior changes, publication, release, or
package upload. The prior terminal compatibility-surface hold remains
non-approval for removal.

### State Activation
- Requires state.json roadmap metadata update: no
- Proposed revision remains: rev-001
- New roadmap_dir when applicable: n/a
