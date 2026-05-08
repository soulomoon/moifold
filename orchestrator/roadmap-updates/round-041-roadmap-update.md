### Source Round
- Round id: round-041
- Merged commit: f8061c2
- Evidence: `orchestrator/rounds/round-041/selection.md`,
  `orchestrator/rounds/round-041/plan.md`,
  `orchestrator/rounds/round-041/implementation-notes.md`,
  `orchestrator/rounds/round-041/review.md`,
  `orchestrator/rounds/round-041/review-record.json`,
  `orchestrator/rounds/round-041/merge.md`, and merged commit `f8061c2`.

### Roadmap Change
- Roadmap id: 2026-05-09-00-external-package-extraction
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/roadmap.md`

### Rationale
Round 041 completed `direction-006-github-package-layout` for milestone 002 by
adding the standalone `agent-workflow-github` package descriptor, wiring it into
`cabal.project`, and extending package-boundary assertions so the GitHub adapter
package is validated independently while the existing
`moifold:agent-workflow-github` internal sublibrary remains available for
current moifold consumers.

The approved round evidence records package-specific build and check
validation, GitHub source-boundary scans, descriptor dependency scans,
`cabal build all`, `cabal test watcher-core-test`, and whitespace validation.
The review and merge artifacts also confirm that the round did not rewire
moifold consumers, remove compatibility facades, change event schemas or golden
fixtures, add CI/source distribution artifacts, prepare release notes, upload
packages, or move/rename modules.

This is a status-only roadmap update. The active revision remains valid because
the merged round does not change future coordination semantics, milestone
dependencies, parallel lanes, release-gate rules, or roadmap-wide boundaries.
Milestone 002 remains in progress because
`direction-007-moifold-local-consumer-wiring` remains pending.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
