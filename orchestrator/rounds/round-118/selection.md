### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-118-observe-appserver-interpreter-coverage`
- Extracted item summary: Add focused coverage for `src/CodexWatcher/Cli/Command/Observe.hs` execute-mode app-server interpreter construction and dry-run fallback behavior before any `CodexWatcher.AppServerClient` import migration.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: focused watcher-core test coverage for `observeOnce` or the smallest testable observe-command seam needed to prove execute mode requires an app-server endpoint, constructs the executor from the configured `AppServerEndpoint` with `defaultAppServerClientOptions`, and dry-run mode uses the null `AppServerInterpreter` fallback without requiring an endpoint; assertions should preserve existing observe parsing and daemon failure/output behavior where touched; required watcher-core test-suite metadata for any new test module is allowed.
- Out of scope: production import migration from `CodexWatcher.AppServerClient`; migration of `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Cli/Command/IssueFanout.hs`, or test-policy/support imports; changes to `CodexWatcher.AppServerClient`, direct owner client/transport modules, app-server protocol, endpoint parser, daemon workflow behavior, runtime compatibility files, fixtures, docs, package descriptors beyond required test metadata, public API, public facade exposure, Cabal exposure, deprecation, removal, release/publication, milestone completion, or terminal completion.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress after rounds 113, 115, and 117 migrated `RunnerGuard.hs`, `Cli/Command/AppServerProbe.hs`, and `Healthcheck.hs` off `CodexWatcher.AppServerClient`. The current remaining production source users are `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports.

`Cli/Command/Observe.hs` is the smallest remaining source surface: its facade use is limited to `appServerInterpreterFromEndpoint`, `defaultAppServerClientOptions`, and the dry-run `AppServerInterpreter` fallback. However, the accepted round-105 readiness evidence classifies it as a timeout/fallback candidate and says a whole-file import move should wait until observe execute/dry-run interpreter coverage exists. Current tests exercise `parseDaemonObservation` and broader workflow execution behavior, but they do not isolate the observe command's execute-mode endpoint requirement or dry-run interpreter fallback as a focused gate.

This round should add that missing evidence and stop there. If reviewed coverage proves the observe command behavior is protected, a later round can select a narrow import-only migration for `Cli/Command/Observe.hs`. This selection does not approve public facade deprecation or removal, Cabal exposure cleanup, package descriptor cleanup beyond test metadata, other importer migration, milestone completion, release approval, or terminal completion.
