### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-112-runner-guard-repair-launch-sequence-coverage`
- Extracted item summary: Add focused RunnerGuard repair-launch request-sequence behavior coverage so the remaining `RunnerGuard.hs` `CodexWatcher.AppServerClient` importer has the follow-up blocker from round-110 satisfied before any later import-only split is selected.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: focused watcher-core test coverage for `src/CodexWatcher/RunnerGuard.hs` repair-launch request sequencing through `startRunnerGuardRepairThread`; controlled app-server response/test-support code needed to drive the actual RunnerGuard repair-launch path from a stale guard decision; assertions that the repair launch sends `thread/start` with `RequestId 1`, `thread/name/set` with `RequestId 2`, and `turn/start` with `RequestId 3`; assertions that the repair thread id, repair turn id, repair thread name, and repair prompt/request body are carried through the intended RunnerGuard launch path; assertions that launch, name-set, turn-start, and turn-start parse failures include stable `formatAppServerClientFailure` details where RunnerGuard currently reports them; required watcher-core test-suite metadata for any new or extended test module.
- Out of scope: any `RunnerGuard.hs` import migration from `CodexWatcher.AppServerClient` to direct owner modules; migration of any other `CodexWatcher.AppServerClient` importer; production behavior changes; app-server protocol, endpoint parsing, session, timeout, fallback, active-turn inspection behavior already covered by round-111, prompt text changes, event-schema, runtime compatibility, healthcheck, repair/restart policy, replay, dry-run, docs, fixture, package descriptor changes beyond test-suite metadata, public API, public facade exposure, Cabal exposure, deprecation, removal, release/publication, milestone-completion, or terminal-completion changes.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress after rounds 106 through 109 moved the lower-risk turn-classifier `CodexWatcher.AppServerClient` imports. Round 110 then evaluated the remaining `RunnerGuard.hs` importer and recorded two focused blockers before any later RunnerGuard import-only split: active app-server turn inspection first, and a smaller repair-launch request-sequence assertion afterward. Round 111 satisfied only the first blocker with endpoint-backed active-turn inspection coverage.

This is the smallest next valuable extraction because it addresses the remaining RunnerGuard blocker named by the accepted round-110 evidence and repeated in the active roadmap after round 111. The selected coverage targets the actual repair-launch sequence hidden behind the facade import: `thread/start`, `thread/name/set`, `turn/start`, request id progression, repair thread naming, turn id parsing, and user-visible failure formatting on the launch path.

The round must preserve `CodexWatcher.AppServerClient` as an exposed public compatibility facade and must not imply direct import migration, public deprecation, Cabal exposure removal, facade removal, milestone completion, or terminal completion.
