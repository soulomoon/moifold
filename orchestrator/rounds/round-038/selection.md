### Selected Extraction
- Milestone: Define Package Identity And Release Contract
- Milestone id: milestone-001-package-identity-release-contract
- Direction id: direction-003-compatibility-and-deprecation-policy
- Extracted item id: item-038-compatibility-deprecation-policy
- Extracted item summary: Define the preferred imports, compatibility facade status, deprecation readiness, and removal gates for the future `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates, including source-backed guidance for `CodexWatcher.AppServerClient` and other moifold-owned compatibility wrappers before any facade removal or package layout migration.
- Roadmap id: 2026-05-09-00-external-package-extraction
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001

### Boundaries
- In scope: artifact-only compatibility and deprecation policy for the three workflow package candidates; mapping current compatibility facades and wrapper imports to preferred package/module imports; documenting what evidence is required before deprecation warnings, import migration, or removal can be considered; confirming how the package readiness report, package identity/versioning contract, and release metadata policy constrain compatibility promises.
- Out of scope: removing wrappers or compatibility files, adding deprecation pragmas, migrating production imports, editing Cabal descriptors, moving source files, renaming modules, changing package layout, changing event schemas or golden fixtures, running or uploading source distributions, publishing packages, creating release announcements, production code changes, roadmap edits, `orchestrator/state.json`, `plan.md`, implementation notes, review artifacts, and merge artifacts.
- Concurrent batch context: none; the active roadmap default lane is serial, controller state allows one active round, and milestone 001 must finish this compatibility/deprecation policy before milestone 002 standalone package layout begins.

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
Milestone 001 has no milestone dependencies and remains in progress after round 037. Direction 001 is complete via round 036, merged as `56b5a02`, and records final external candidate names, versioning expectations, namespace policy, and compatibility limits. Direction 002 is complete via round 037, merged as `bad28e9`, and records release metadata, changelog, release-note, metadata truth, and descriptor-time requirements.

Direction 003 is now the next dependency-ready item because its precondition is a current package ownership report, and the active documentation already records the package extraction readiness map, compatibility facade status, and package ownership split. It should run now because the roadmap explicitly keeps milestone 002 pending until milestone 001 is complete, and standalone package layout work needs a reviewable compatibility/deprecation policy before later rounds expose package candidates to downstream users or touch descriptors, imports, source layout, validation artifacts, docs, or release gates.
