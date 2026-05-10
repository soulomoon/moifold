### Source Round
- Round id: round-075
- Merged commit: 066952b
- Evidence: `orchestrator/rounds/round-075/implementation-notes.md`, `orchestrator/rounds/round-075/review.md`, `orchestrator/rounds/round-075/review-record.json`, and `orchestrator/rounds/round-075/merge.md`

### Roadmap Change
- Roadmap id: 2026-05-10-00-facade-removal-readiness
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/roadmap.md`

### Rationale
Round 075 was approved and merged as the artifact-only import scan refresh for
`milestone-001-current-facade-evidence` and
`direction-001-import-scan-refresh`. The roadmap now marks direction 001
complete via commit `066952b` and marks milestone 001 in progress.

The milestone remains open because round 075 did not complete the separate
behavior-owner classification required by `direction-002-behavior-owner-classification`.
The accepted evidence records current local import counts, Cabal exposure,
documentation references, replacement mappings, protecting checks,
downstream/operator inventory limits, and blocker classes for
`CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
`CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.

This update does not approve or perform migration, deprecation, Cabal exposure
changes, public facade removal, runtime compatibility-file cleanup, event-schema
changes, healthcheck or repair behavior changes, publication, release, or
package upload. The prior terminal compatibility-surface hold remains
non-approval for removal.

### State Activation
- Requires state.json roadmap metadata update: no
- Proposed revision remains: rev-001
- New roadmap_dir when applicable: n/a
