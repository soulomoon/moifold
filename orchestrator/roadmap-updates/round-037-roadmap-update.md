### Source Round
- Round id: round-037
- Merged commit: bad28e9
- Evidence: `orchestrator/rounds/round-037/selection.md`,
  `orchestrator/rounds/round-037/plan.md`,
  `orchestrator/rounds/round-037/implementation-notes.md`,
  `orchestrator/rounds/round-037/review.md`,
  `orchestrator/rounds/round-037/merge.md`, and merged commit `bad28e9`.

### Roadmap Change
- Roadmap id: 2026-05-09-00-external-package-extraction
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed:
  `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/roadmap.md`

### Rationale
Round 037 completed `direction-002-release-metadata-policy` for milestone 001 by
adding a source-backed release metadata policy for the future
`agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`
package candidates. The merged work records metadata requirements,
package-specific wording constraints, changelog and release-note gates,
metadata truth rules, and descriptor-time checks, while preserving the roadmap
boundaries against descriptor migration, source movement, generated artifacts,
package upload, and publication approval.

This is a status-only roadmap update. The active revision remains valid because
the merged round does not change future coordination semantics, milestone
dependencies, parallel lanes, release-gate rules, or roadmap-wide boundaries.
Milestone 001 remains in progress because
`direction-003-compatibility-and-deprecation-policy` is still pending.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
