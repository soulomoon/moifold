### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-164-event-log-repair-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/EventLogRepair.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to direct GitHub-id and agent-id owner imports for its existing `IssueNumber`, `PrNumber`, and `TurnId` uses, preserving event-log repair planning and repaired-event construction while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/EventLogRepair.hs` to replace `CodexWatcher.Core.Ids (IssueNumber (..), PrNumber (..), TurnId (..))` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), PrNumber (..))` and `CodexWatcher.Workflow.Agent.Ids (TurnId (..))`; preserve `EventLogRepairPlan`, `repairFailureBlockStateJson`, `repairIssueImplementEventLog`, deterministic repair rules, inserted/dropped event construction, replay validation, and existing error text.
- Out of scope: other `Core.Ids` users including PR-review loop/launch/workflow modules, issue-planning loop/fanout modules, issue-implementation classifier/loop/watcher/workflow modules, daemon/healthcheck/runtime/event-log modules, CLI modules, tests except if narrowly required to keep validation compiling, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file production migration should run serially after round 163.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 163 migrated `src/CodexWatcher/Domain/PrReview/Protocol.hs` while production `CodexWatcher.Core.Ids` imports still remain. The active roadmap permits narrow split-import migration slices, and the operator steering asks for concrete migration or removal-enabling code work instead of another readiness-only gate while direct-owner import migrations are available. No exact reviewed gate currently permits public facade removal, Cabal exposure cleanup, or runtime compatibility removal.

The live import scan for this worktree still shows `src/CodexWatcher/EventLogRepair.hs` importing `CodexWatcher.Core.Ids (IssueNumber (..), PrNumber (..), TurnId (..))`. Those identifiers already have direct owners: `IssueNumber` and `PrNumber` are exported by `CodexWatcher.Workflow.GitHub.Ids`, while `TurnId` is exported by `CodexWatcher.Workflow.Agent.Ids`; `CodexWatcher.Core.Ids` only reexports those owner modules. Keeping this round to an import-only production migration should preserve event-log repair behavior and replay semantics while reducing another concrete internal dependency on the compatibility facade.
