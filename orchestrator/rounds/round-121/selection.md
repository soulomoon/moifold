### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-121-automatic-loop-appserver-interpreter-coverage`
- Extracted item summary: Add focused coverage for `src/CodexWatcher/AutomaticLoop/Runner.hs` execute/dry-run app-server interpreter construction and retry/fallback behavior before any `CodexWatcher.AppServerClient` import migration.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: focused watcher-core test coverage for `AutomaticLoop/Runner.hs`; the smallest testable seam needed to prove `runAutomaticLoop` or its runner-local construction path uses the configured `AppServerEndpoint` with `defaultAppServerClientOptions` in execute-capable loop execution; assertions that dry-run behavior does not perform live app-server traffic while preserving existing loop behavior; assertions preserving automatic-loop retry/fallback classification for app-server transport failures and fatal replay/unexpected-start-plan failures; required watcher-core test-suite metadata for any new test module is allowed.
- Out of scope: production import migration from `CodexWatcher.AppServerClient`; migration of `Domain/PrReview/LaunchCli.hs`, `AutomaticLoop/Runner.hs`, `Cli/Command/IssueFanout.hs`, or test-policy/support imports; changes to `CodexWatcher.AppServerClient`, direct owner client/transport modules, app-server protocol, endpoint parser, daemon-loop behavior, startup-thread refresh policy, issue-planning fanout, PR-review handoff, runtime compatibility files, fixtures, docs, package descriptors beyond required test metadata, public API, public facade exposure, Cabal exposure, deprecation, removal, release/publication, milestone completion, or terminal completion.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains the highest-value ready lane after round 120. The remaining production `CodexWatcher.AppServerClient` users are `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/AutomaticLoop/Runner.hs`, and `src/CodexWatcher/Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports. The public compatibility facade must remain exposed and unchanged.

`AutomaticLoop/Runner.hs` is the smallest remaining source surface: its live facade dependency is limited to `appServerInterpreterFromEndpoint`, `defaultAppServerClientOptions`, and the `AppServerEndpoint` type used by the automatic-loop runner path. However, the accepted round-105 readiness evidence classified it as a `timeout/fallback source candidate` and said even the small whole-file import move should wait for automatic-loop execute/dry-run and retry/fallback assertions. Current tests preserve retry classification and broader loop behavior, but there is no focused gate for the runner's endpoint-backed interpreter construction versus dry-run behavior.

This round should add that missing evidence and stop there. If reviewed coverage proves the automatic-loop runner behavior is protected, a later round can select a narrow import-only migration for `AutomaticLoop/Runner.hs`. Higher-risk remaining users in PR-review launch and issue fanout still sit on child thread launch, command rendering, request-id progression, and `formatAppServerClientFailure` paths, so they stay out of scope for later focused gates. This selection is not public deprecation or removal, does not approve Cabal exposure cleanup or package descriptor changes beyond test metadata, and does not complete milestone 003.
