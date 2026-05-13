### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-171-moifold-pr-review-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/Workflow/Moifold/PrReview.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct owner imports for its existing `CommitSha`, `ReviewThreadId`, `ThreadId`, and `TurnId` uses, preserving PR-review workflow observation behavior while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/Workflow/Moifold/PrReview.hs` to replace `CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), ThreadId, TurnId)` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId (..))` and `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`; preserve unresolved-review-thread observation, review-feedback observation, fix-verification observation, event construction, decisions, summaries, error text, and function bodies.
- Out of scope: other PR-review modules; issue-planning, issue-implementation, CLI, daemon, healthcheck, event-log, runner-guard, runtime compatibility, and test import migrations; parser, renderer, serialization, prompt, command-output, fixture, state-machine, or behavior changes; package descriptor cleanup; public facade deletion or deprecation; Cabal exposed-module changes; docs or policy-string edits; `CodexWatcher.Core.Ids` facade changes; broader `Core.Ids` migration; runtime compatibility cleanup; milestone completion; terminal completion; release approval; or public compatibility removal.
- Concurrent batch context: none; `max_parallel_rounds` is 1 and this is a single-file serial production import-convergence slice.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 170 migrated `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`. The live production import scan still shows `src/CodexWatcher/Workflow/Moifold/PrReview.hs:17` importing `CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), ThreadId, TurnId)`.

This slice follows operator steering by selecting concrete removal-enabling code work instead of another readiness-only or removal-gate-only round. The selected file is a bounded production owner-import migration: its `Core.Ids` import is limited to GitHub-owned `CommitSha` and `ReviewThreadId` plus agent-owned `ThreadId` and `TurnId`; the direct owner modules already expose those names, and the main library already depends on the direct owner packages. No constructors, parsers, renderers, command-output formatting, runtime compatibility files, package descriptors, docs, or public facade exposure need to change for the selected scope. Public facade exposure and all deprecation/removal gates remain explicitly out of scope.
