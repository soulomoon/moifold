### Source Round
- Round id: round-039
- Merged commit: 68f2195
- Evidence: `orchestrator/rounds/round-039/selection.md`,
  `orchestrator/rounds/round-039/plan.md`,
  `orchestrator/rounds/round-039/implementation-notes.md`,
  `orchestrator/rounds/round-039/review.md`,
  `orchestrator/rounds/round-039/review-record.json`,
  `orchestrator/rounds/round-039/merge.md`, and merged commit `68f2195`.

### Roadmap Change
- Roadmap id: 2026-05-09-00-external-package-extraction
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/roadmap.md`

### Rationale
Round 039 completed `direction-004-core-package-layout` for milestone 002 by
adding the standalone `agent-workflow-core` package descriptor and local
project wiring while preserving the existing core source layout and retained
internal sublibrary. The approved review evidence records package-specific
build and check validation, boundary scans, package-boundary assertions,
`cabal build all`, `cabal test watcher-core-test`, and whitespace checks.

This is a status-only roadmap update. The active revision remains valid because
the merged round does not change future coordination semantics, milestone
dependencies, parallel lanes, release-gate rules, or roadmap-wide boundaries.
Milestone 002 is now in progress rather than complete because
`direction-005-codex-package-layout`, `direction-006-github-package-layout`, and
`direction-007-moifold-local-consumer-wiring` remain pending.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
