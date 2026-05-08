### Selected Extraction
- Milestone: Stabilize Codex and GitHub Adapter Package APIs
- Milestone id: milestone-004-adapter-api-stabilization
- Direction id: direction-009-github-adapter-api
- Extracted item id: item-033-github-adapter-api
- Extracted item summary: Stabilize the GitHub adapter API surface for GitHub ids, remote metadata parsing, and command-rendering helpers in `agent-workflow-github`, with focused parser/rendering parity tests and recursive boundary scans that keep moifold state-machine, daemon, and lifecycle policy outside the adapter package.
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001

### Boundaries
- In scope: a narrow GitHub adapter API stabilization slice in `agent-workflow-github`, focused tests for touched GitHub id, remote metadata parser, healthcheck/parser parity, or command-rendering helper behavior, and recursive boundary checks proving the adapter does not import moifold state-machine, daemon, or lifecycle modules.
- Out of scope: Codex adapter API work already completed in round 032, extraction-readiness milestone 005 work, API freeze docs, package publishing, core workflow spec or DSL redesign, transaction or daemon runtime-contract changes, event schema or golden fixture changes, moving concrete moifold issue/PR lifecycle policy into adapter packages, compatibility facade removal without local proof, roadmap edits, implementation notes, merge notes, reviews, and `state.json`.
- Concurrent batch context: none; controller state allows one active round, round 032 already completed the Codex adapter slice, and this selection takes the remaining GitHub adapter direction before milestone 005 can begin.

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
Milestone 004 is dependency-ready because its declared dependency, milestone 001, is complete through round 027. Round 032 completed `direction-008-codex-agent-adapter-api` as `2f33153`, and the active roadmap now records milestone 004 as pending only on `direction-009-github-adapter-api`.

`direction-009-github-adapter-api` should run now because it is the remaining adapter API stabilization work blocking milestone 004 completion, and milestone 005 explicitly depends on milestone 004. The slice is round-sized if it stays on GitHub identifiers, remote metadata parsing, command rendering, healthcheck/parser parity, and recursive package-boundary evidence for `agent-workflow-github`, without pulling moifold state-machine, daemon, lifecycle, filesystem, process, or repair policy into the adapter package.
