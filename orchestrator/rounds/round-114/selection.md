### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-114-appserver-probe-command-coverage`
- Extracted item summary: Add focused test coverage for `src/CodexWatcher/Cli/Command/AppServerProbe.hs` app-server command behavior so its explicit `CodexWatcher.AppServerClient` import can be considered for a later import-only migration without guessing about request shape, request ids, timeout options, smoke-thread behavior, smoke-turn behavior, or failure formatting.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: test-only coverage for `probeAppServer` behavior in `src/CodexWatcher/Cli/Command/AppServerProbe.hs`; coverage may add or extend focused watcher-core test modules and narrow test support for an endpoint-backed fake app-server; verify initialize, optional `thread/read`, smoke `thread/start`, smoke `turn/start`, request id progression, configured workdir/prompt text, success output, and user-visible `formatAppServerClientFailure` text for selected failure or parse-failure cases; update only required watcher-core test-suite metadata if a new test module is added.
- Out of scope: any production import migration; changes to `src/CodexWatcher/Cli/Command/AppServerProbe.hs`; changes to `CodexWatcher.AppServerClient`, direct owner client/transport modules, app-server protocol, endpoint parser, public facade exposure, package descriptors outside required test-suite metadata, docs, fixtures, runtime compatibility files, healthcheck, automatic loop, issue fanout, PR review launch, other `CodexWatcher.AppServerClient` importers, Cabal exposed-module cleanup, public deprecation, public API removal, release/publication, milestone completion, or terminal completion.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress after round 113. The active roadmap records that `RunnerGuard.hs` has moved off `CodexWatcher.AppServerClient`, while remaining source users still include `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Healthcheck.hs`, `Cli/Command/AppServerProbe.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports.

The round-105 readiness artifact classifies `Cli/Command/AppServerProbe.hs` as one of the smallest explicit-import candidates, but not as a safe mechanical migration. It specifically names initialize, `thread/read`, `thread/start`, `turn/start`, fixed timeout, endpoint options, smoke-thread behavior, smoke-turn behavior, and failure formatting as gates before a later migration. Current coverage includes protocol/client primitives in `test/AppServerSpec.hs` and CLI parser coverage in `test/CliSpec.hs`, but the command-level `probeAppServer` request sequence and output/failure behavior are not isolated as a focused gate.

This is the smallest next valuable extraction because it adds the missing evidence for a single explicit importer without touching production code. If accepted, a later round can decide whether an import-only `AppServerProbe` migration is ready; this round itself must not imply migration, deprecation, public facade removal, Cabal exposure cleanup, package-boundary cleanup beyond any required test metadata, milestone completion, or terminal completion.
