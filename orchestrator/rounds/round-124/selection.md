### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-124-pr-review-launch-appserverclient-import-convergence`
- Extracted item summary: Move only `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` from the public `CodexWatcher.AppServerClient` compatibility facade to direct Codex app-server owner imports, relying on the accepted round-123 PR-review launch coverage gate.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: a narrow production import-only migration in `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`; replace the open `CodexWatcher.AppServerClient` import with direct-owner imports for only the app-server client and transport symbols already used by the PR-review launch path; preserve worker/reviewer thread launch, request ids, refreshed launch-plan thread ids, child command rendering, failure formatting, and all code bodies; validate with the focused round-123 `PrReviewLaunchCliSpec.prReviewLaunchCliTests` coverage, target import scans, facade/direct-owner/protocol diff guards, `cabal test watcher-core-test`, `cabal build all`, whitespace checks, and JSON checks.
- Out of scope: code-body or behavior changes in `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`; changes to `CodexWatcher.AppServerClient`, direct owner client/transport/protocol modules, endpoint parsing, app-server protocol, child daemon ownership, runtime compatibility files, fixtures, docs, app code, package descriptors, public API, public facade exposure, Cabal exposure, deprecation, removal, release/publication, migration of `src/CodexWatcher/Cli/Command/IssueFanout.hs`, test-policy imports, test-support imports, milestone completion, or terminal completion.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains the highest-value active lane. After round 123, live production `CodexWatcher.AppServerClient` users are down to `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` and `src/CodexWatcher/Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports. The public compatibility facade must remain exposed and unchanged.

`Domain/PrReview/LaunchCli.hs` is now the smallest dependency-ready production extraction. Round 123 added and reviewed focused coverage for the exact behavior that blocked this migration: endpoint-backed PR-review worker/reviewer `thread/start` requests, fixed request-id progression, role-specific developer instructions, refreshed thread-id persistence, dry-run child command rendering, and selected JSON-RPC/decode failure formatting. That accepted gate lets this round be import-only instead of adding more coverage or changing behavior.

`Cli/Command/IssueFanout.hs` remains out of scope because its surface is broader and still needs focused coverage before migration: child thread launch, command rendering, request-id progression, workdir setup command retry, child readiness/completion detection, and app-server failure formatting. Test-policy and test-support imports also stay out of scope. This selection is not public deprecation or removal, does not approve Cabal/API exposure cleanup or package descriptor cleanup, and does not complete milestone 003.
