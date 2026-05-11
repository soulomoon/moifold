### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-106-turn-classifier-common-appserverclient-import-convergence`
- Extracted item summary: Move the single `src/CodexWatcher/Turn/Classifier/Common.hs` source importer from the public `CodexWatcher.AppServerClient` compatibility facade to the direct owner `CodexWatcher.Workflow.Agent.Codex.Client` for `AppServerTurn` only, preserving turn-completion and structured-output classification behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: the import line in `src/CodexWatcher/Turn/Classifier/Common.hs`; behavior-preserving compile fixes directly required by that import move; focused validation that `classifyTurnCompletion`, `parseStructuredTurnOutcome`, missing-output blocking, status normalization, and existing workflow turn-classifier coverage still behave the same.
- Out of scope: changing `AppServerTurn` constructors or fields; changing endpoint parsing, app-server protocol, session handling, timeout, fallback, command rendering, failure formatting, prompt behavior, event schemas, runtime compatibility, healthcheck, repair, replay, restart, dry-run behavior, package descriptors, docs, fixtures, public APIs, Cabal exposed modules, or public compatibility facade exposure; migrating any other `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, or `CodexWatcher.Workflow.Permission` importer; deprecation, removal, release/publication, milestone-completion, or terminal-completion claims.
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
Milestone 003 remains dependency-ready because milestone 001 is complete, but it is not complete. Round 103 closed direction 011's current single-domain `Core.Ids` queue, round 104 completed readiness evidence for the mixed `Workflow.EventLog` and `Workflow.Permission` bridge facades, and round 105 completed readiness evidence for `CodexWatcher.AppServerClient` while explicitly leaving milestone 003 in progress.

The next smallest high-value extraction is the direction 010 source candidate named by round 105: `src/CodexWatcher/Turn/Classifier/Common.hs`. That module imports the compatibility facade only for `AppServerTurn` and its `appServerTurnStatus` / `appServerTurnOutput` fields. The direct owner module is already exposed by `agent-workflow-codex`, and the existing test surface exercises common turn completion, structured outcome parsing, status normalization, missing-output behavior, and downstream issue-planning, issue-implementation, PR-review, final-review, workflow-agent, and indexed-workflow classifiers.

This is lawful before milestone 004 because it continues the active import-convergence milestone after all three selected facade readiness fronts have current evidence. It is smaller and less risky than endpoint/session, command-rendering, timeout/fallback, or mixed bridge migrations, and it reduces one production compatibility-facade import without changing public exposure. The round must preserve `CodexWatcher.AppServerClient` as an available public facade and must not imply Cabal exposure removal, deprecation, facade removal, milestone completion, or terminal completion.
