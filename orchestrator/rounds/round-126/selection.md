### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-126-issue-fanout-appserverclient-import-convergence`
- Extracted item summary: Move only `src/CodexWatcher/Cli/Command/IssueFanout.hs` from the public `CodexWatcher.AppServerClient` compatibility facade to direct Codex app-server owner imports, preserving the app-server-backed child implementer launch behavior covered by round-125.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: production import-only convergence in `src/CodexWatcher/Cli/Command/IssueFanout.hs`; replace the `CodexWatcher.AppServerClient` facade import with direct owner imports for the existing app-server client and transport symbols used by IssueFanout; preserve code bodies, endpoint-backed `thread/start` launch behavior, request ids starting at `8000`, launch workdir `cwd`, developer instruction context, persisted manifest thread ids, child command rendering, retryable clone failure classification, fallback child-start classification ordering, and selected app-server failure formatting.
- Out of scope: tests/support imports, public facade exposure, `CodexWatcher.AppServerClient` changes, direct owner client/transport/protocol changes, Cabal/API cleanup, package descriptors, docs, fixtures, runtime compatibility files, behavior changes, public deprecation/removal, release approval, milestone completion, terminal completion, or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains the active import-convergence lane. Round 125 added focused watcher-core coverage for the app-server-backed `IssueFanout.hs` child implementer launch path at merged commit `8efbab4`, satisfying the focused behavior-evidence precondition for an import-only decision.

The live scan still shows `src/CodexWatcher/Cli/Command/IssueFanout.hs` importing `CodexWatcher.AppServerClient`, while the remaining facade imports are test-policy or test-support surfaces. This makes the IssueFanout import-only move the smallest next valuable extraction: it can reduce the last production facade dependency without touching tests/support imports, public facade exposure, Cabal/API cleanup, docs, package descriptors, or removal gates.

This selection does not imply facade deprecation or removal, public API cleanup, test-support migration, milestone completion, or terminal completion.
