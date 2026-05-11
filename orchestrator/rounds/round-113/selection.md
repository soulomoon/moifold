### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-113-runner-guard-appserverclient-import-convergence`
- Extracted item summary: Move only `src/CodexWatcher/RunnerGuard.hs` from the public `CodexWatcher.AppServerClient` compatibility facade to the direct Codex client and transport owner modules, now that both RunnerGuard behavior blockers from round-110 have reviewed coverage.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: a narrow production import-only migration in `src/CodexWatcher/RunnerGuard.hs`; replace the `CodexWatcher.AppServerClient` import with direct-owner imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`; preserve all RunnerGuard behavior, exports, request ids, repair prompt text, stale-turn decisions, failure formatting, and app-server protocol usage; run the focused RunnerGuard coverage from rounds 111 and 112 plus `watcher-core-test`, `cabal build all`, import scans, descriptor/facade diff checks, and whitespace checks.
- Out of scope: migration of any other `CodexWatcher.AppServerClient` source or test importer; changes to `CodexWatcher.AppServerClient`, direct owner modules, app-server protocol, endpoint/session/fallback/timeout behavior, command rendering, repair/restart policy, healthcheck, runtime compatibility, fixtures, docs, package descriptors, public API, public facade exposure, Cabal exposure, deprecation, removal, release/publication, milestone completion, or terminal completion.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress with `CodexWatcher.AppServerClient` source users still present. The active roadmap records that round 110 mapped `RunnerGuard.hs` to direct owner modules but blocked a later import-only split until two focused behavior gates landed. Round 111 satisfied the active app-server turn inspection gate, and round 112 satisfied the repair-launch sequence gate, both with endpoint-backed RunnerGuard coverage and no production diff.

This is the smallest next valuable extraction because `RunnerGuard.hs` is the only source importer whose specific blockers are now satisfied. The selected work is a direct import convergence slice: it should only change where RunnerGuard imports the already-covered client and transport symbols from, while preserving the public compatibility facade for all external and remaining internal users.

The round must not imply deprecation, public facade removal, Cabal exposure cleanup, migration of other source users, milestone completion, or terminal completion. Remaining `CodexWatcher.AppServerClient` users such as `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Healthcheck.hs`, `Cli/Command/AppServerProbe.hs`, `Cli/Command/Observe.hs`, `Cli/Command/IssueFanout.hs`, and test-policy imports stay for later gated rounds.
