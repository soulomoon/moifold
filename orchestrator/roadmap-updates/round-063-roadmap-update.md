### Source Round
- Round id: `round-063`
- Merged commit: `b7d5eff`
- Evidence: `orchestrator/rounds/round-063/selection.md`, `orchestrator/rounds/round-063/workflow-permission-public-api-evidence.md`, `orchestrator/rounds/round-063/implementation-notes.md`, `orchestrator/rounds/round-063/review.md`, `orchestrator/rounds/round-063/review-record.json`, and `orchestrator/rounds/round-063/merge.md`.

### Roadmap Change
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`

### Rationale
Round 063 was approved and merged as the evidence-only completion of `direction-012-workflow-permission-public-api-review` under `milestone-005-import-facade-follow-up-evidence`. Its accepted evidence records public `CodexWatcher.Workflow.Permission` API exposure, Cabal exposure readback, repo-local import/reference inventory, concrete permission behavior parity from the focused workflow permission test, replacement guidance through `CodexWatcher.Workflow.Permission.Core`, and downstream/operator blockers before any later cleanup decision.

The roadmap now marks direction 012 complete via round 063 and marks milestone 005 complete because directions 009, 010, 011, and 012 are all complete. Milestone 006 remains pending because round 063 did not complete any runtime compatibility follow-up evidence direction. This update does not authorize deprecation, removal, migration, Cabal exposure changes, production import rewrites, runtime compatibility changes, package publication, upload, release, or public cleanup approval.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
