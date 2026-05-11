### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-122-automatic-loop-runner-appserverclient-import-convergence`
- Extracted item summary: Move only `src/CodexWatcher/AutomaticLoop/Runner.hs` from the public `CodexWatcher.AppServerClient` compatibility facade to direct Codex app-server owner imports, relying on the accepted round-121 automatic-loop runner coverage gate.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: a narrow production import-only migration in `src/CodexWatcher/AutomaticLoop/Runner.hs`; replace the open `CodexWatcher.AppServerClient` import with direct-owner imports for only `AppServerEndpoint`, `appServerInterpreterFromEndpoint`, and `defaultAppServerClientOptions`; preserve `runAutomaticLoop`, dry-run behavior, execute-mode endpoint-backed interpreter construction, automatic-loop retry/fallback classification, startup-thread refresh policy, issue-planning fanout, PR-review handoff, and all code bodies; run the focused round-121 `AutomaticLoopRunnerSpec.automaticLoopRunnerTests` coverage plus import scans, package/facade/direct-owner/protocol diff guards, `cabal test watcher-core-test`, `cabal build all`, whitespace checks, and JSON checks.
- Out of scope: code-body or behavior changes in `src/CodexWatcher/AutomaticLoop/Runner.hs`; changes to `CodexWatcher.AppServerClient`, direct owner client/transport/interpreter/protocol modules, endpoint parsing, daemon-loop behavior, startup-thread refresh behavior, issue-planning fanout behavior, PR-review handoff behavior, runtime compatibility files, fixtures, docs, package descriptors, public API, public facade exposure, Cabal exposure, deprecation, removal, release/publication, migration of `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, or test-policy/support imports, milestone completion, or terminal completion.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains the highest-value ready lane after round 121. The live scan now shows the remaining production `CodexWatcher.AppServerClient` users are `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/AutomaticLoop/Runner.hs`, and `src/CodexWatcher/Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports. The public compatibility facade must remain exposed and unchanged.

`AutomaticLoop/Runner.hs` is now the smallest dependency-ready extraction. Round 121 added and reviewed focused coverage for the exact behavior that blocked this migration: execute mode uses the configured endpoint-backed app-server with default initialization traffic and planner `thread/start`/`turn/start`, dry-run sends no live endpoint traffic, and retry/fallback classification keeps app-server transport failures retryable while decode/replay and unexpected-start-plan failures remain fatal. That accepted gate lets this round be import-only instead of adding more coverage or changing behavior.

Higher-risk remaining users in PR-review launch and issue fanout still sit on child thread launch, command rendering, request-id progression, runtime command retry/completion detection, and `formatAppServerClientFailure` paths, so they stay out of scope for later focused gates. This selection is not public deprecation or removal, does not approve Cabal exposure cleanup or package descriptor changes, and does not complete milestone 003.
