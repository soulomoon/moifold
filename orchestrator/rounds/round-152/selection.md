### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-152-appserver-probe-spec-agent-id-direct-owner-migration`
- Extracted item summary: Migrate `test/AppServerProbeSpec.hs` from the `CodexWatcher.Core.Ids` compatibility facade to the direct agent-id owner for its `ThreadId` use, preserving probe command coverage and leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `test/AppServerProbeSpec.hs` to replace `CodexWatcher.Core.Ids (ThreadId (..), unThreadId)` with the direct owner import `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), unThreadId)`; preserve existing app-server probe command tests and existing `CodexWatcher.Workflow.Agent.Codex.Transport` ownership for `AppServerEndpoint`.
- Out of scope: no test-body rewrites, helper moves, production changes, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, `CodexWatcher.AppServerClient` facade/Cabal/docs cleanup, milestone completion, terminal completion, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file import migration should run serially after round 151.

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
Round 151 completed exact source/app/test `CodexWatcher.AppServerClient` import convergence, but public facade, Cabal exposure, docs, and policy references remain gated and unapproved for removal. Selecting public `AppServerClient` facade, Cabal, or docs removal now would skip the roadmap gates.

Milestone 003 is still in progress through other compatibility surfaces. The live scan shows `test/AppServerProbeSpec.hs` imports `CodexWatcher.Core.Ids` only for `ThreadId` and `unThreadId`, whose direct owner is `CodexWatcher.Workflow.Agent.Ids`. This is a concrete, behavior-preserving migration under direction 011, not a readiness-only gate, and it keeps the family moving toward clean compatibility removal without weakening public compatibility promises.
