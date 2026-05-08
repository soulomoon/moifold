### Source Round
- Round id: round-040
- Merged commit: 8f81c1e
- Evidence: `orchestrator/rounds/round-040/selection.md`,
  `orchestrator/rounds/round-040/plan.md`,
  `orchestrator/rounds/round-040/implementation-notes.md`,
  `orchestrator/rounds/round-040/review.md`,
  `orchestrator/rounds/round-040/review-record.json`,
  `orchestrator/rounds/round-040/merge.md`, and merged commit `8f81c1e`.

### Roadmap Change
- Roadmap id: 2026-05-09-00-external-package-extraction
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/roadmap.md`

### Rationale
Round 040 completed `direction-005-codex-package-layout` for milestone 002 by
adding the standalone `agent-workflow-codex` package descriptor, wiring it into
`cabal.project`, and extending package-boundary assertions so the Codex adapter
package is validated independently while the existing
`moifold:agent-workflow-codex` internal sublibrary remains available for current
moifold consumers.

The approved round evidence records package-specific build and check
validation, Codex source-boundary scans, descriptor dependency scans,
`cabal build all`, `cabal test watcher-core-test`, and whitespace validation.
The review and merge artifacts also confirm that the round did not add the
standalone GitHub descriptor, rewire moifold consumers, remove compatibility
facades, change event schemas or golden fixtures, add CI/source distribution
artifacts, prepare release notes, or upload packages.

This is a status-only roadmap update. The active revision remains valid because
the merged round does not change future coordination semantics, milestone
dependencies, parallel lanes, release-gate rules, or roadmap-wide boundaries.
Milestone 002 remains in progress because `direction-006-github-package-layout`
and `direction-007-moifold-local-consumer-wiring` remain pending.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
