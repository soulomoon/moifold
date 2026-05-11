### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-107-issue-planning-turn-classifier-appserverclient-import-convergence`
- Extracted item summary: Move the single `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs` source importer from the public `CodexWatcher.AppServerClient` compatibility facade to the direct owner `CodexWatcher.Workflow.Agent.Codex.Client` for `AppServerTurn` only, preserving issue-planning turn classification for running, failed, missing-output, issue-request, planning-graph, invalid-payload, and structured outcome cases.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: the import line in `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`; behavior-preserving compile fixes directly required by that import move; focused validation that `classifyIssuePlanningTurn`, `classifyTurnCompletion`, missing-output blocking, issue/subissue request parsing, planning-graph parsing, invalid issue-creation payload classification, and structured blocked/incomplete/complete outcome classification still behave the same.
- Out of scope: changing issue-planning observation constructors, planning graph or issue request parsing, structured-output semantics, endpoint parsing, app-server protocol, session handling, timeout, fallback, command rendering, failure formatting, prompt behavior, event schemas, runtime compatibility, healthcheck, repair, replay, restart, dry-run behavior, package descriptors, docs, fixtures, public APIs, Cabal exposed modules, or public compatibility facade exposure; migrating any other `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, or `CodexWatcher.Workflow.Permission` importer; deprecation, removal, release/publication, milestone-completion, or terminal-completion claims.
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
Milestone 003 remains dependency-ready because milestone 001 is complete, but it is not complete. Round 103 closed direction 011's current single-domain `Core.Ids` queue, round 104 completed readiness evidence for the mixed `Workflow.EventLog` and `Workflow.Permission` bridge facades, round 105 completed `CodexWatcher.AppServerClient` readiness evidence, and round 106 completed one narrow direction 010 import move in `src/CodexWatcher/Turn/Classifier/Common.hs`.

The next smallest high-value extraction is the remaining direction 010 turn-classifier source candidate in `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`. A current scan still shows `CodexWatcher.AppServerClient` imports in source and test files, but this module uses the facade only for the `AppServerTurn` type consumed by `classifyIssuePlanningTurn`; endpoint/session, timeout/fallback, command-rendering, failure-formatting, public API, and package-descriptor surfaces are not part of the selected change. The direct owner module is already exposed by `agent-workflow-codex`, and the existing watcher-core coverage exercises issue-planning turn classification through issue/subissue request payloads, planning graph payloads, structured outcomes, missing output, blocked observations, and indexed workflow/event-log planning paths.

This remains lawful before milestone 004 because it continues the active import-convergence milestone after the roadmap's readiness evidence and the first narrow AppServerClient import move. It is smaller and less risky than endpoint/session, command-rendering, timeout/fallback, `Core.Ids` combined-user, or mixed `Workflow.EventLog`/`Workflow.Permission` bridge migrations, and it reduces one more production compatibility-facade import without changing public exposure. The round must preserve `CodexWatcher.AppServerClient` as an available public facade and must not imply Cabal exposure removal, deprecation, facade removal, milestone completion, or terminal completion.
