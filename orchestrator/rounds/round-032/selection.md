### Selected Extraction
- Milestone: Stabilize Codex and GitHub Adapter Package APIs
- Milestone id: milestone-004-adapter-api-stabilization
- Direction id: direction-008-codex-agent-adapter-api
- Extracted item id: item-032-codex-agent-adapter-api
- Extracted item summary: Stabilize the Codex adapter API surface for typed agent roles, turn references, protocol clients, classifiers, and transport-facing helpers, with focused protocol/classifier tests and recursive boundary scans that keep moifold issue/PR policy outside `agent-workflow-codex`.
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001

### Boundaries
- In scope: a narrow Codex adapter API stabilization slice in `agent-workflow-codex`, focused tests for touched protocol, parser, classifier, typed-agent, turn-reference, or transport-facing helper behavior, and recursive boundary checks proving the adapter does not import moifold issue/PR lifecycle policy.
- Out of scope: GitHub adapter API stabilization, command-rendering changes, core workflow spec or DSL redesign, transaction or daemon runtime-contract changes, event schema or golden fixture changes, weakening classifier evidence or structured-output field requirements, moving moifold issue/PR lifecycle policy into adapter packages, compatibility facade removal, roadmap edits, implementation notes, merge notes, reviews, and `state.json`.
- Concurrent batch context: none; controller state allows one active round, and the roadmap permits a Codex/GitHub split only after a planner confirms disjoint write scopes. This selection starts with the Codex adapter direction as the first adapter stabilization slice.

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
Milestone 004 is dependency-ready because its declared dependency, milestone 001, is complete through round 027. Rounds 030 and 031 also completed milestone 003, so the previous runtime-contract lane is no longer blocking the next framework stabilization work after round 031.

`direction-008-codex-agent-adapter-api` should run now because adapter package APIs are the next pending roadmap surface before extraction readiness. Selecting the Codex adapter first keeps the round small and avoids inventing parallelism: the roadmap allows Codex and GitHub adapter work to split only after a planner proves disjoint ownership, and the current controller has `max_parallel_rounds` set to 1. The slice should preserve app-server protocol ownership in `agent-workflow-codex`, keep classifier evidence and structured-output requirements strong, and leave concrete moifold issue/PR lifecycle policy in the main library.
