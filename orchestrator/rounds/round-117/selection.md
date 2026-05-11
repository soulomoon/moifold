### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-117-healthcheck-appserverclient-import-convergence`
- Extracted item summary: Move only `src/CodexWatcher/Healthcheck.hs` from the public `CodexWatcher.AppServerClient` compatibility facade to direct Codex client and transport owner imports, now that round 116 added focused endpoint-backed Healthcheck thread inspection coverage.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: a narrow production import-only migration in `src/CodexWatcher/Healthcheck.hs`; replace the `CodexWatcher.AppServerClient` import with direct-owner imports for only the currently used app-server client and transport symbols; preserve all `runHealthcheck`, `checkAppServerThread`, request id `9001`, `includeTurns = True`, timeout, latest-turn reporting, skip behavior, and failure-formatting behavior; run focused Healthcheck endpoint-backed coverage from round 116 plus import scans, package/facade/direct-owner/protocol diff guards, `watcher-core-test`, `cabal build all`, and whitespace/JSON checks.
- Out of scope: code-body or behavior changes in `src/CodexWatcher/Healthcheck.hs`; changes to `CodexWatcher.AppServerClient`, direct owner client/transport modules, app-server protocol, healthcheck report shape, runtime compatibility files, tests, fixtures, docs, package descriptors, public API, public facade exposure, Cabal exposure, deprecation, removal, release/publication, other `CodexWatcher.AppServerClient` importers, milestone completion, or terminal completion.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress with `CodexWatcher.AppServerClient` source users still present. Round 115 removed `Cli/Command/AppServerProbe.hs` from the remaining source-user list, and round 116 satisfied the Healthcheck-specific endpoint-backed coverage gate for worker `thread/read`: request id `9001`, `includeTurns = True`, configured thread id, latest-turn fields, missing endpoint/thread-id skips, no request when no thread id is present, and JSON-RPC/decode failure formatting.

That makes `Healthcheck.hs` the smallest next dependency-ready import-convergence slice. The selected round should only change import ownership in one production file and rely on the newly accepted Healthcheck coverage to guard the app-server behavior contracts. Higher-risk remaining users in `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs` stay for later gated rounds.

This selection is not public deprecation or removal. The public `CodexWatcher.AppServerClient` facade must remain exposed and unchanged, package descriptors must remain unchanged, test-policy/support imports remain out of scope, and milestone 003 remains open until remaining users and policy evidence are handled.
