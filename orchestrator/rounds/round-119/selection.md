### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-119-observe-appserverclient-import-convergence`
- Extracted item summary: Move only `src/CodexWatcher/Cli/Command/Observe.hs` from the public `CodexWatcher.AppServerClient` compatibility facade to direct Codex app-server owner imports, relying on the accepted round-118 observe command coverage gate.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: a narrow production import-only migration in `src/CodexWatcher/Cli/Command/Observe.hs`; replace the `CodexWatcher.AppServerClient` import with direct-owner imports for only the app-server endpoint interpreter and default client options currently used by `observeOnceExecutor`; preserve execute-mode endpoint requirement, dry-run null interpreter fallback, planner `turn/start` traffic, stdout/stderr/exit behavior, parsing behavior, and all code bodies; run the focused round-118 `ObserveCommandSpec` coverage plus import scans, package/facade/direct-owner/protocol diff guards, `watcher-core-test`, `cabal build all`, and whitespace/JSON checks.
- Out of scope: code-body or behavior changes in `src/CodexWatcher/Cli/Command/Observe.hs`; changes to `CodexWatcher.ActionExecutor`, `CodexWatcher.AppServerClient`, direct owner client/transport/interpreter modules, app-server protocol, endpoint parser, daemon workflow behavior, runtime compatibility files, tests, fixtures, docs, package descriptors, public API, public facade exposure, Cabal exposure, deprecation, removal, release/publication, migration of `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Cli/Command/IssueFanout.hs`, test-policy/support imports, milestone completion, or terminal completion.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains the highest-value ready lane: `CodexWatcher.AppServerClient` source users still remain while the public compatibility facade must stay exposed and unchanged. Rounds 113, 115, and 117 already migrated `RunnerGuard.hs`, `Cli/Command/AppServerProbe.hs`, and `Healthcheck.hs`; after round 118 the remaining production source users are `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports.

`Cli/Command/Observe.hs` is now the smallest dependency-ready extraction because round 118 added and reviewed focused black-box `observeOnce` coverage for the exact behavior that had blocked this migration: execute mode without an endpoint fails with the required endpoint flag message, dry-run without an endpoint succeeds through the null interpreter fallback, and execute mode with a configured endpoint reaches the fake app-server session and planner `turn/start` traffic. That accepted gate lets this round be import-only instead of adding more coverage or changing behavior.

The selected round should only remove the Observe module's dependency on the compatibility facade and point the existing endpoint-backed interpreter symbols at their direct owner module. Higher-risk remaining users in PR review launch, issue-planning loop, automatic loop runner, and issue fanout still need their own gates or later import-only selections. This selection is not public deprecation or removal, does not approve Cabal exposure cleanup or package descriptor changes, and does not complete milestone 003.
