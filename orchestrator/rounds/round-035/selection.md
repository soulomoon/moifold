### Selected Extraction
- Milestone: Prepare External Extraction Readiness
- Milestone id: milestone-005-extraction-readiness
- Direction id: direction-011-package-readiness-report
- Extracted item id: item-035-package-readiness-report
- Extracted item summary: Produce the package extraction readiness report for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, including import-graph evidence, dependency ownership, compatibility-facade mapping, validation commands, remaining blockers, and only narrowly justified Cabal or package-boundary cleanup needed to make the report truthful.
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001

### Boundaries
- In scope: an extraction readiness artifact under `docs/agentic-workflow-framework/` or an equivalent existing framework-doc surface; source-backed import graphs and dependency ownership evidence for the three `agent-workflow-*` libraries; compatibility-facade and deprecation-readiness mapping; explicit remaining blockers; validation commands for package-boundary confidence; minimal Cabal, exposed-module, or package-boundary cleanup only when the report demonstrates a concrete extraction-readiness gap.
- Out of scope: package publication, external release setup, broad compatibility facade removal, event schema or golden fixture changes, moving moifold issue/PR lifecycle policy into framework packages, daemon/runtime ownership migration, healthcheck or repair migration, prompt/schema policy changes, speculative API redesign, roadmap mutations, `plan.md`, implementation notes, merge notes, reviews, and `state.json`.
- Concurrent batch context: none; controller state allows one active round, and direction 011 is serial if it edits Cabal or public module exports.

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
Milestone 005 is dependency-ready because milestone 002 completed through round 029, milestone 003 completed through round 031, and milestone 004 completed through round 033. Round 034 completed `direction-010-api-freeze-and-docs` as `11692a5`, satisfying direction 011's precondition that the API-freeze direction be complete or explicitly scoped before package-readiness work begins.

The active roadmap now records milestone 005 as pending only on `direction-011-package-readiness-report`. This selection should run now because the framework contract, DSL, generic runtime contracts, adapter APIs, and API-freeze docs are all in place, but the repo still needs concrete extraction-readiness evidence before any package split or publication decision. Keeping this round report-first preserves the roadmap non-goals while still allowing small, evidence-driven Cabal or boundary cleanup if the import graph shows a real readiness blocker.
