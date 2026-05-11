### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-120-issue-planning-loop-appserverclient-import-convergence`
- Extracted item summary: Move only `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` from the public `CodexWatcher.AppServerClient` compatibility facade to direct Codex app-server owner imports, preserving planning system-error retry/blocking behavior and planner app-server request behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: a narrow production import-only migration in `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`; replace the `CodexWatcher.AppServerClient` import with direct-owner imports for only the app-server turn type currently used by `planningSystemErrorObservation`; preserve planner-thread initialization, request id progression, dry-run synthetic planner thread behavior, planned app-server request/result behavior, active-turn reads, systemError retry/blocking behavior, command failure formatting for snapshot commands, and all code bodies; run focused planning turn-classifier and planning systemError retry/blocking coverage plus import scans, package/facade/direct-owner/protocol diff guards, `watcher-core-test`, `cabal build all`, whitespace checks, and JSON checks.
- Out of scope: code-body or behavior changes in `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`; changes to `CodexWatcher.AppServerClient`, direct owner client/transport/protocol modules, `CodexWatcher.Domain.IssuePlanning.TurnClassifier`, planner thread request construction, app-server protocol parsing, endpoint parser, runtime compatibility files, fixtures, docs, package descriptors, public API, public facade exposure, Cabal exposure, deprecation, removal, release/publication, migration of `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/AutomaticLoop/Runner.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, test-policy/support imports, milestone completion, or terminal completion.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds: 1`, so this selection opens one round only.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains the highest-value ready lane: `CodexWatcher.AppServerClient` production users still remain while the public compatibility facade must stay exposed and unchanged. Rounds 113, 115, 117, and 119 already migrated `RunnerGuard.hs`, `Cli/Command/AppServerProbe.hs`, `Healthcheck.hs`, and `Cli/Command/Observe.hs`; the remaining production source users are `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, and `Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports.

`Domain/IssuePlanning/Loop.hs` is the smallest dependency-ready extraction now. The live symbol-use scan shows its remaining facade dependency is `AppServerTurn` for `planningSystemErrorObservation`; planner thread start and app-server request/result parsing already go through `WorkflowAgentCodex` direct owner APIs. Existing watcher-core coverage exercises issue-planning turn classification, active planner `thread/read` handling, systemError retry, and systemError retry-limit blocking, so this can be selected as an import-only migration rather than another coverage gate.

Higher-risk remaining users in PR review launch, automatic loop runner, and issue fanout still sit on endpoint/session startup, child command rendering, retry/fallback, or user-visible failure formatting and need their own focused gates or later import-only selections. This selection is not public deprecation or removal, does not approve Cabal exposure cleanup or package descriptor changes, and does not complete milestone 003.
