### Source Round
- Round id: round-034
- Merged commit: 11692a5
- Evidence: `orchestrator/rounds/round-034/selection.md`,
  `orchestrator/rounds/round-034/plan.md`,
  `orchestrator/rounds/round-034/implementation-notes.md`,
  `orchestrator/rounds/round-034/review.md`,
  `orchestrator/rounds/round-034/review-record.json`,
  `orchestrator/rounds/round-034/merge.md`, and the squash commit `11692a5`.

### Roadmap Change
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/roadmap.md`

### Rationale
Round 034 completed `milestone-005-extraction-readiness` direction
`direction-010-api-freeze-and-docs` for extracted item
`item-034-api-freeze-docs`. The approved and merged work added the implemented
internal API-freeze page and aligned the framework README plus the workflow
spec, pure DSL, event-log and transaction, Codex adapter, GitHub adapter, and
correctness-model navigation docs with the current source-backed framework
surfaces.

The review evidence records passing docs-only whitespace and scope checks,
direct comparison against the exposed `agent-workflow-core`,
`agent-workflow-codex`, and `agent-workflow-github` module lists, source-token
inspection for the documented core/Codex/GitHub API surfaces, and comparison
against `orchestrator/project-contract.md` and the active roadmap non-goals.
The work kept moifold issue/PR lifecycle policy, prompt and schema policy,
runtime/process/filesystem ownership, healthcheck, repair, compatibility
snapshots and file names, concrete daemon loops, publication, deprecation, and
compatibility-facade removal outside the reusable framework contract.

This update marks direction 010 complete. It does not complete milestone 005,
because `direction-011-package-readiness-report` remains pending. It also does
not change future milestone definitions, sequencing, parallel lanes, roadmap
metadata, or active revision activation, so the active rev-001 roadmap remains
the correct coordination surface for the next selection.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
