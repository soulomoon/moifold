### Selected Extraction
- Milestone: Define Package Identity And Release Contract
- Milestone id: milestone-001-package-identity-release-contract
- Direction id: direction-001-package-names-and-versioning
- Extracted item id: item-036-package-names-versioning-contract
- Extracted item summary: Define the external package identity contract for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`: final or explicitly provisional package names, initial version policy, module namespace policy, semantic-versioning expectations, and compatibility analysis for current module/package names before any descriptor or layout migration.
- Roadmap id: 2026-05-09-00-external-package-extraction
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001

### Boundaries
- In scope: package identity and versioning policy artifacts; source-backed compatibility analysis for current module names and package names; release-contract text needed to let later metadata and layout rounds avoid guessing package identity.
- Out of scope: package descriptor migration, source tree movement, module renames, package publication, release metadata beyond identity/versioning policy, compatibility facade removal, event schema or golden fixture changes, CI changes, docs/examples beyond the identity contract needed for handoff, production code, `plan.md`, roadmap edits, and `orchestrator/state.json`.
- Concurrent batch context: none; the active roadmap default lane is serial, controller state allows one active round, and this identity direction must precede metadata, package layout, validation, docs, and release-gate work.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [],
  "merge_after_item_ids": [],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 001 has no milestone dependencies and is the first pending milestone in the active `strategy-backlog` roadmap. Direction 001 is dependency-ready because its precondition is the completed package extraction readiness report, which round 035 added and merged as commit `61e6a2b`.

This extraction should run now because the roadmap's global sequencing requires stable package identity and release policy before package descriptors, source layout, validation artifacts, public docs, or release decisions. Keeping round 036 focused on package names, versioning, module namespace policy, and compatibility analysis gives later metadata and layout rounds a reviewable contract without authorizing code movement or publication.
