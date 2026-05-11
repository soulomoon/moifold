### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-108-issue-implement-turn-classifier-appserverclient-import-convergence`
- Extracted item summary: Move the single `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` source importer from the public `CodexWatcher.AppServerClient` compatibility facade to the direct owner `CodexWatcher.Workflow.Agent.Codex.Client` for `AppServerTurn` only, preserving issue-plan, implementation, and final-review turn classification behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: the import line in `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`; behavior-preserving compile fixes directly required by that import move; focused validation that `classifyIssuePlanTurn`, `classifyIssueImplementationTurn`, `classifyIssueFinalReviewTurn`, `classifyTurnCompletion`, missing-output blocking, structured blocked/incomplete/complete outcomes, expected-commit validation, PR-number completion, reviewer-thread completion, malformed JSON handling, and final-review clean/rework/blocked/incomplete cases still behave the same.
- Out of scope: changing issue-implementation observation constructors, issue-plan JSON parsing, implementation structured-output semantics, final-review schema semantics, reviewer prompt version policy, endpoint parsing, app-server protocol, session handling, timeout, fallback, command rendering, failure formatting, prompt behavior, event schemas, runtime compatibility, healthcheck, repair, replay, restart, dry-run behavior, package descriptors, docs, fixtures, public APIs, Cabal exposed modules, or public compatibility facade exposure; migrating any other `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, or `CodexWatcher.Workflow.Permission` importer; deprecation, removal, release/publication, milestone-completion, or terminal-completion claims.
- Concurrent batch context: none; active controller state is serial with `max_parallel_rounds: 1`, and this selection opens one narrow implementation round only.

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
Milestone 003 remains dependency-ready because milestone 001 is complete, but it is still in progress. Round 103 closed direction 011's current single-domain `Core.Ids` queue, round 104 completed readiness evidence for the mixed `Workflow.EventLog` and `Workflow.Permission` bridge facades, round 105 completed `CodexWatcher.AppServerClient` readiness evidence, round 106 moved the common turn classifier off the facade, and round 107 moved the issue-planning turn classifier off the facade.

The next smallest high-value extraction is the remaining direction 010 issue-implementation turn-classifier source candidate in `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`. The current scan still shows `CodexWatcher.AppServerClient` imports in source and test files, but this module uses the facade only for the `AppServerTurn` type consumed by issue-plan, implementation, and final-review classifier entry points. Endpoint/session, timeout/fallback, command-rendering, failure-formatting, public API, and package-descriptor surfaces are not part of the selected change. The direct owner module is already exposed by `agent-workflow-codex`, and the existing watcher-core coverage exercises issue-implementation classifier behavior through plan completion, implementation completion/incomplete/blocked outcomes, PR and reviewer-thread completion paths, final-review clean/rework/blocked/incomplete decisions, expected commit validation, missing output, malformed JSON, and indexed workflow/event-log paths.

This remains lawful before milestone 004 because it continues the active import-convergence milestone after the roadmap's readiness evidence and the first two narrow AppServerClient import moves. It is smaller than the remaining PR-review classifier candidate and less risky than endpoint/session, command-rendering, timeout/fallback, `Core.Ids` combined-user, or mixed `Workflow.EventLog`/`Workflow.Permission` bridge migrations. It reduces one more production compatibility-facade import without changing public exposure. The round must preserve `CodexWatcher.AppServerClient` as an available public compatibility facade and must not imply Cabal exposure removal, deprecation, facade removal, milestone completion, or terminal completion.
