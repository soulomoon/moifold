### Selected Extraction
- Milestone: Define Package Identity And Release Contract
- Milestone id: milestone-001-package-identity-release-contract
- Direction id: direction-002-release-metadata-policy
- Extracted item id: item-037-release-metadata-policy
- Extracted item summary: Define the release metadata policy for the future `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates, covering license, maintainer, category, synopsis, description, source-repository, changelog, release-note, and metadata truth requirements before any package descriptor migration.
- Roadmap id: 2026-05-09-00-external-package-extraction
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001

### Boundaries
- In scope: release metadata policy artifacts and source-backed requirements for the three workflow package candidates; confirmation of how the round-036 package identity and versioning contract constrains metadata; changelog and release-note requirements needed by later descriptor, docs, validation, and release-gate rounds.
- Out of scope: editing Cabal package descriptors, moving source files, renaming modules, changing package layout, running or uploading source distributions, publishing packages, creating release announcements, removing compatibility facades, changing event schemas or golden fixtures, production code changes, roadmap edits, `orchestrator/state.json`, `plan.md`, implementation notes, review artifacts, and merge artifacts.
- Concurrent batch context: none; the active roadmap default lane is serial, controller state allows one active round, and this release metadata policy should follow the completed package identity direction before standalone package layout or validation work begins.

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
Milestone 001 has no milestone dependencies and remains in progress after round 036. Direction 001 is complete via round 036, merged as `56b5a02`, and records stable package names, initial pre-1.0 versioning expectations, current module namespace policy, and release-gate limits for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`.

Direction 002 is now dependency-ready because its precondition is stable package names or an explicit provisional record, and round 036 made the package names final for the external candidates. It should run now because the roadmap requires package identity and release policy to be explicit before physical package movement, `cabal check`, source distribution validation, public docs, changelog/release notes, or release-gate decisions. Keeping round 037 focused on metadata requirements gives later descriptor and validation rounds a reviewable source of truth without authorizing descriptor edits or publication.
