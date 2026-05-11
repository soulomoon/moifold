### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-125-issue-fanout-appserverclient-coverage`
- Extracted item summary: Add focused watcher-core coverage for `src/CodexWatcher/Cli/Command/IssueFanout.hs` app-server-backed child implementer launch behavior before any `CodexWatcher.AppServerClient` import migration.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: focused test coverage for the smallest IssueFanout launch paths needed to guard child thread launch, rendered child command arguments, request-id progression, workdir setup command retry, child readiness/completion detection, and selected app-server failure formatting.
- Out of scope: production import migration from `CodexWatcher.AppServerClient`; code-body or behavior changes in `src/CodexWatcher/Cli/Command/IssueFanout.hs`; changes to app-server client/transport/protocol modules, runtime compatibility files, fixtures, docs, app code, package descriptors beyond required test metadata, public facade exposure, Cabal/API exposure, test-policy/support import migration, public deprecation/removal, milestone completion, release approval, terminal completion, or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains the active import-convergence lane. Round 124 moved `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` off the public `CodexWatcher.AppServerClient` facade at `fc2700a`; the roadmap update at `182dbf8` keeps milestone 003 and direction 010 in progress.

The current live scan shows the only remaining production source user is `src/CodexWatcher/Cli/Command/IssueFanout.hs`, while test-policy/test-support imports, public facade exposure, Cabal/API cleanup, and docs remain outside production import convergence. IssueFanout is broader and riskier than the prior import-only slices because it spans child thread launch, command rendering, request-id sequencing, workdir setup retry, readiness/completion detection, and app-server failure formatting. A focused coverage gate is therefore the smallest valuable next extraction; a later round can decide whether the import-only migration is safe from that evidence.

This selection does not imply facade deprecation or removal, public API cleanup, test-support migration, milestone completion, or terminal completion.
