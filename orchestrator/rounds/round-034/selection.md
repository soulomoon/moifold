### Selected Extraction
- Milestone: Prepare External Extraction Readiness
- Milestone id: milestone-005-extraction-readiness
- Direction id: direction-010-api-freeze-and-docs
- Extracted item id: item-034-api-freeze-docs
- Extracted item summary: Align the framework documentation with the implemented `WorkflowSpec`, DSL, event-log, transaction, daemon, Codex adapter, and GitHub adapter surfaces, explicitly recording the stable framework contract versus moifold-owned lifecycle policy before any package-readiness report or Cabal/package cleanup.
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001

### Boundaries
- In scope: documentation-only API freeze work under `docs/agentic-workflow-framework/`, with minimal README or `docs/correctness-model.md` navigation updates only if they improve access to the implemented contract; direct evidence that docs distinguish implemented APIs from design goals; verification against `orchestrator/project-contract.md` and the active roadmap non-goals.
- Out of scope: direction 011 package-readiness report, Cabal/package-boundary cleanup, public module export changes, compatibility facade removal, package publishing, production code changes, event schema or golden fixture changes, roadmap mutations, implementation notes, merge notes, reviews, and `state.json`.
- Concurrent batch context: none; controller state allows one active round, and direction 011 requires the API freeze direction to be complete or explicitly scoped before the package-readiness report can run.

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
Milestone 005 is dependency-ready because milestone 002 completed through round 029, milestone 003 completed through round 031, and milestone 004 completed through round 033. The active roadmap now leaves only extraction-readiness work pending.

`direction-010-api-freeze-and-docs` should run before `direction-011-package-readiness-report` because direction 011 names API freeze completion or explicit scoping as a precondition. Selecting the docs/API-freeze slice first gives the next round a bounded artifact-only scope: make the documented framework contract match the code proven by prior rounds, keep the docs thesis-first, and preserve the roadmap's non-goals around publication, event compatibility, moifold lifecycle ownership, and compatibility facades.
