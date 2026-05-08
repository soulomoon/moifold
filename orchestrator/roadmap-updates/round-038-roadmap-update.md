### Source Round
- Round id: round-038
- Merged commit: 2574fa3
- Evidence: `orchestrator/rounds/round-038/selection.md`,
  `orchestrator/rounds/round-038/plan.md`,
  `orchestrator/rounds/round-038/implementation-notes.md`,
  `orchestrator/rounds/round-038/review.md`,
  `orchestrator/rounds/round-038/review-record.json`,
  `orchestrator/rounds/round-038/merge.md`, and merged commit `2574fa3`.

### Roadmap Change
- Roadmap id: 2026-05-09-00-external-package-extraction
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/roadmap.md`

### Rationale
Round 038 completed `direction-003-compatibility-and-deprecation-policy` for
milestone 001 by adding the approved artifact-only compatibility and
deprecation policy for the future `agent-workflow-core`,
`agent-workflow-codex`, and `agent-workflow-github` package candidates. The
merged work records preferred-import guidance, compatibility facade status,
deprecation-readiness gates, removal gates, compatibility-file preservation
rules, moifold-owned runtime/event/file boundaries, and release-note
constraints while preserving the roadmap boundaries against wrapper removal,
compatibility-file migration, deprecation pragmas, import migration, descriptor
migration, source movement, generated artifacts, package upload, and
publication approval.

This is a status-only roadmap update. The active revision remains valid because
the merged round does not change future coordination semantics, milestone
dependencies, parallel lanes, release-gate rules, or roadmap-wide boundaries.
With directions 001, 002, and 003 complete, milestone 001 now satisfies its
completion signal: package names, versioning policy, license/source metadata,
maintainer/repository metadata, changelog/release-note policy, compatibility
and deprecation posture, and explicit upload authorization rules are recorded
and reviewable.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
