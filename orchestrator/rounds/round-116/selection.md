### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-116-healthcheck-appserver-thread-inspection-coverage`
- Extracted item summary: Add focused endpoint-backed test coverage for the Healthcheck app-server thread inspection path before any `CodexWatcher.Healthcheck` import migration.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Test-only coverage for `src/CodexWatcher/Healthcheck.hs` app-server thread inspection behavior, including the `thread/read` request shape with request id `9001`, `includeTurns = True`, configured timeout behavior, successful latest-turn reporting, skipped cases for missing endpoint or missing thread id, and formatted JSON-RPC/decode failure reporting. Expected edit targets are `test/HealthcheckSpec.hs`, `test/Main.hs`, and only minimal test-support wiring if existing helpers need reuse.
- Out of scope: Production import changes, `CodexWatcher.Healthcheck` behavior changes, other `CodexWatcher.AppServerClient` importers, public facade exposure, Cabal/API/docs cleanup, deprecation, removal, release decisions, runtime compatibility-file changes, and milestone completion.
- Concurrent batch context: none; `max_parallel_rounds` is 1 and this selection is a serial evidence gate for a later Healthcheck import-only migration.

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
Round 115 migrated `Cli/Command/AppServerProbe.hs` off `CodexWatcher.AppServerClient`, leaving `Healthcheck.hs` and several lifecycle/command surfaces as source users. `Healthcheck.hs` is not yet a safe import-only target because it owns a live app-server `thread/read` path with request id, `includeTurns`, timeout, latest-turn reporting, and failure-formatting contracts, while current `HealthcheckSpec` coverage focuses on analyzer and report-shape logic rather than endpoint-backed app-server behavior. A small Healthcheck evidence round is dependency-ready now because the shared endpoint-backed fake app-server support exists from earlier direction-010 rounds, it does not require production changes, and it creates the missing gate needed before selecting a later `Healthcheck.hs` direct-owner import migration.
