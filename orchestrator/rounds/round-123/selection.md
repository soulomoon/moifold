### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-123-pr-review-launch-appserverclient-coverage`
- Extracted item summary: Add focused watcher-core coverage for `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` endpoint-backed PR-review worker/reviewer thread launch, child launch command rendering, and app-server failure formatting before any `CodexWatcher.AppServerClient` import migration.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: focused test coverage for `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`; exercise endpoint-backed `preparePrReviewWatcherLaunch` or the narrow launch path that starts the worker and reviewer threads; assert `thread/start` requests use request ids `9000` and `9001`, preserve worker/reviewer role developer instructions, update the launch plan thread ids, and format selected app-server JSON-RPC/decode failures through `formatAppServerClientFailure`; cover `prReviewWatcherChildArgs` command rendering for host, port, optional path, poll seconds, state paths, workdir, execute/loop flags, and pid file when practical; add only required watcher-core test metadata or test support.
- Out of scope: production import migration from `CodexWatcher.AppServerClient`; code-body or behavior changes in `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`; changes to `CodexWatcher.AppServerClient`, direct owner client/transport/protocol modules, endpoint parsing, app-server protocol, child daemon ownership, runtime compatibility files, fixtures, docs, app code, package descriptors beyond required test metadata, public API, public facade exposure, Cabal exposure, deprecation, removal, release/publication, migration of `src/CodexWatcher/Cli/Command/IssueFanout.hs`, or test-policy/support imports, milestone completion, or terminal completion.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains the highest-value active lane: after round 122, live production `CodexWatcher.AppServerClient` users are down to `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` and `src/CodexWatcher/Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports. The public compatibility facade must remain exposed and unchanged.

`Domain/PrReview/LaunchCli.hs` is the smallest next valuable extraction, but it is not safe to select as an import-only migration yet. Its facade use still covers PR-review child watcher startup, endpoint-backed worker/reviewer `thread/start` calls, fixed request-id progression, child command rendering, and `formatAppServerClientFailure` paths. A focused coverage round is the narrowest useful step because it creates the behavior gate needed for a later import-only migration without changing production behavior.

`Cli/Command/IssueFanout.hs` stays out of scope for a later gate because its remaining surface is broader: child thread launch, command rendering, request-id progression, workdir setup command retry, child readiness/completion detection, and app-server failure formatting. This selection does not approve any public deprecation or removal, Cabal/API exposure cleanup, package descriptor cleanup beyond test metadata, milestone completion, release approval, terminal completion, or public compatibility removal.
