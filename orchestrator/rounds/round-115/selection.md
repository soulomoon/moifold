### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-115-appserver-probe-appserverclient-import-convergence`
- Extracted item summary: Move only `src/CodexWatcher/Cli/Command/AppServerProbe.hs` from the public `CodexWatcher.AppServerClient` compatibility facade to direct Codex client and transport owner imports, now that round 114 added focused command-level app-server probe coverage.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: a narrow production import-only migration in `src/CodexWatcher/Cli/Command/AppServerProbe.hs`; replace the `CodexWatcher.AppServerClient` import with direct-owner imports for `AppServerClientOptions`, `defaultAppServerClientOptions`, `formatAppServerClientFailure`, `parseThreadStartThreadId`, `parseTurnStartTurnId`, and `sendOneAppServerRequest`; preserve `probeAppServer` behavior, request ids, timeout options, optional `thread/read`, smoke `thread/start`, smoke `turn/start`, output text, and failure formatting; run the focused AppServerProbe coverage from round 114 plus `watcher-core-test`, `cabal build all`, target import scans, descriptor/facade diff checks, and whitespace checks.
- Out of scope: migration of any other `CodexWatcher.AppServerClient` source, test, or test-support importer; changes to `CodexWatcher.AppServerClient`, direct owner client/transport modules, app-server protocol, endpoint parser, CLI parser, command behavior, timeout/fallback/session semantics, test coverage, fixtures, docs, package descriptors, public API, public facade exposure, Cabal exposure, deprecation, removal, release/publication, milestone completion, or terminal completion.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress after round 114. The active roadmap records that `RunnerGuard.hs` has already moved off `CodexWatcher.AppServerClient`, while remaining source users still include `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Healthcheck.hs`, `Cli/Command/AppServerProbe.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports.

Round 114 satisfied the focused `probeAppServer` command coverage gate named by the direction 010 readiness evidence: command-level `initialize`, optional `thread/read`, smoke `thread/start`, smoke `turn/start`, request ids, selected params, success output, and selected JSON-RPC/decode failure formatting now have endpoint-backed tests. That makes `Cli/Command/AppServerProbe.hs` the smallest next safe import-convergence candidate: the round can move only import ownership while relying on the new focused coverage to guard command behavior.

This selection is not public deprecation or removal. The public `CodexWatcher.AppServerClient` facade must remain exposed and unchanged, package descriptors must remain unchanged, other source and test importers stay for later gated rounds, and milestone 003 remains open until the remaining users and policy evidence are handled.
