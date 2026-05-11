### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-111-runner-guard-active-turn-inspection-coverage`
- Extracted item summary: Add focused RunnerGuard active app-server turn inspection behavior coverage so the remaining `RunnerGuard.hs` `CodexWatcher.AppServerClient` importer has the first blocker from round-110 satisfied before any later import-only split is selected.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: focused watcher-core test coverage for `src/CodexWatcher/RunnerGuard.hs` active app-server turn inspection; controlled app-server response/test-support code needed to drive `checkRunnerGuard` from event logs containing active turn states; assertions that `thread/read` is requested for the active thread with `RequestId 1` and `includeTurns = True`; assertions for materialization-pending missing turns across the configured stale threshold; assertions that `threadSystemError`, missing active turn, failed turn, completed-without-output, blank output, and completed-but-unobserved output map to the intended `LaunchRepairThread` summaries/details; assertions that app-server read or parse failures include stable `formatAppServerClientFailure` text in `runnerGuardProblemDetails`; required watcher-core test-suite metadata for any new test module.
- Out of scope: any `RunnerGuard.hs` import migration from `CodexWatcher.AppServerClient` to direct owner modules; migration of any other `CodexWatcher.AppServerClient` importer; production behavior changes; app-server protocol, endpoint parsing, session, timeout, fallback, command rendering, repair-launch request sequence, prompt text, event-schema, runtime compatibility, healthcheck, repair, replay, restart, dry-run, docs, fixture, package descriptor, public API, public facade exposure, Cabal exposure, deprecation, removal, release/publication, milestone-completion, or terminal-completion changes.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress after rounds 106 through 109 moved the lower-risk turn-classifier `CodexWatcher.AppServerClient` imports. Round 110 then evaluated the remaining `RunnerGuard.hs` importer and explicitly recommended that no later RunnerGuard import-only split is safe until focused RunnerGuard active app-server turn inspection coverage lands first.

This is the smallest next valuable extraction because it addresses the exact blocker identified by the last completed round without selecting the blocked import migration. The selected coverage targets the densest unprotected RunnerGuard behavior surface: active-thread `thread/read`, materialization-pending fallback, `threadSystemError`, latest-turn lookup, turn-completion classification, stale-threshold decisions, and user-visible app-server failure text.

The round must preserve `CodexWatcher.AppServerClient` as an exposed public compatibility facade and must not imply direct import migration, public deprecation, Cabal exposure removal, facade removal, milestone completion, or terminal completion.
