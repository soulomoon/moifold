### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-098-boundary-policy-github-ids-import-convergence`
- Extracted item summary: Move the GitHub-only `test/BoundaryPolicySpec.hs` import from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct owner `CodexWatcher.Workflow.GitHub.Ids`, preserving the current boundary-policy assertions and leaving all public facade exposure unchanged.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: the single test import convergence in `test/BoundaryPolicySpec.hs` for the GitHub id types already classified by round 097 as GitHub-only (`BranchName`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`); preserving existing assertions, failure messages, and watcher-core test reachability; updating test-suite metadata only if the direct owner module is not already reachable.
- Out of scope: production code; app code; all combined `CodexWatcher.Core.Ids` users; `AppServerClient`, `Workflow.EventLog`, and `Workflow.Permission` convergence; constructor, parser, renderer, command-output, prompt, fixture, event-schema, runtime-state, healthcheck, repair, replay, or restart behavior changes; Cabal exposed-module changes for compatibility facades; deprecation, migration, removal, release, milestone-completion, or terminal-completion claims.
- Concurrent batch context: none; active state is serial with `max_parallel_rounds: 1`, and this selection opens one narrow import-convergence round only.

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
Milestone 003 is dependency-ready because it depends on the completed test-topology inventory, and round 097 completed the current facade import scan required before selecting concrete import-convergence work. The active roadmap says direction 009 is complete and direction 011 should start with safe single-domain `Core.Ids` users before combined users that need broader parser, renderer, prompt, output, runtime-config, and fixture evidence.

This is the smallest valuable next extraction under the pending milestone-003 directions. Round 097 accepted `test/BoundaryPolicySpec.hs` as a GitHub-only direct-owner candidate with observed use of `BranchName`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`, while `AppServerClient` source users remain blocked on app-server behavior evidence and `Workflow.EventLog` / `Workflow.Permission` require mixed bridge split-readiness evidence before public-surface action.

Selecting this test-only convergence slice reduces one compatibility-facade dependency without changing behavior or implying deprecation. It also creates a low-risk validation pattern for later `Core.Ids` convergence rounds while preserving the roadmap requirement that public compatibility facades stay exposed until exact removal gates are reviewed.
