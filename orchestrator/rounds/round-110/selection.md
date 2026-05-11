### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-110-runner-guard-appserverclient-gate-evidence`
- Extracted item summary: Produce artifact-only readiness evidence for the remaining `src/CodexWatcher/RunnerGuard.hs` `CodexWatcher.AppServerClient` importer, proving the exact runner-guard repair-thread and active-turn behavior gates needed before any later direct-owner import split.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: a round-local evidence artifact for `src/CodexWatcher/RunnerGuard.hs`; current import and symbol-use scans for its `CodexWatcher.AppServerClient` dependency; mapping those symbols to direct owner modules; existing runner-guard test and behavior coverage inventory; explicit gate findings for repair-thread launch, `thread-name/set`, `turn/start`, request-id progression, active-thread read, thread-read materialization pending, `threadSystemError`, latest-turn lookup, turn-completion classification, stale-turn decisions, and `formatAppServerClientFailure` text; a final yes/no recommendation on whether a later import-only split is safe and, if not, which focused behavior test must land first.
- Out of scope: production, test, app, package descriptor, fixture, docs, public API, app-server protocol, endpoint parsing, session behavior, timeout behavior, fallback behavior, command rendering, failure formatting, prompt text, event-schema, runtime compatibility, healthcheck, repair, replay, restart, dry-run behavior, or Cabal exposure changes; direct import migration in `RunnerGuard.hs` or any other file; migration of `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Healthcheck.hs`, `Cli/Command/AppServerProbe.hs`, `Cli/Command/Observe.hs`, `Cli/Command/IssueFanout.hs`, or test-policy imports; public deprecation, facade removal, release/publication, milestone-completion, or terminal-completion claims.
- Concurrent batch context: none; active controller state is serial with `max_parallel_rounds: 1`, and this selection opens one artifact-only gate-evidence round only.

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
Milestone 003 remains dependency-ready because milestone 001 is complete, but it is still in progress. Round 105 recorded `CodexWatcher.AppServerClient` readiness evidence, and rounds 106 through 109 consumed the low-risk turn-classifier-only source candidates. The current active roadmap update now leaves only higher-risk source users in `RunnerGuard.hs`, `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Healthcheck.hs`, `Cli/Command/AppServerProbe.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`, plus test-policy imports.

`RunnerGuard.hs` is the smallest next high-value surface because round 105 classified it as an explicit-import candidate, but also recorded that migration is unsafe until runner-guard repair and active-turn behavior checks are selected. Its single facade import spans both client and transport owner surfaces: endpoint-backed repair-thread launch, `sendOneAppServerRequest`, thread-read parsing, materialization-pending fallback, system-error handling, latest-turn lookup, turn-start parsing, turn-completion classification, and user-visible failure formatting. A direct import move now would bypass the direction 010 gates for app-server protocol, session handling, fallback, and failure formatting.

This artifact-only gate round keeps the roadmap moving without forcing a risky import move. It should either prove that a later `RunnerGuard.hs` import-only split is behaviorally covered, or name the one focused runner-guard behavior test slice that must land first. The round must preserve `CodexWatcher.AppServerClient` as an exposed public compatibility facade and must not imply Cabal exposure removal, deprecation, facade removal, milestone completion, or terminal completion.
