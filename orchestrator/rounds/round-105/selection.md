### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-105-appserverclient-import-convergence-readiness`
- Extracted item summary: Refresh and record exact readiness evidence for `CodexWatcher.AppServerClient` import convergence, classifying current source and test importers by app-server client, transport/session, turn-classifier, command-rendering, timeout, fallback, and failure-formatting gates before any direct-owner import migration.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: artifact-only readiness evidence for `CodexWatcher.AppServerClient`; current exact import and reference scans over `src`, `app`, `test`, docs, package descriptors, and standalone package candidates; confirmation that the facade remains a public compatibility reexport of `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`; per-importer classification of source, test-policy, public-exposure, and documentation references; identification of the smallest later source-file migration candidates and the focused endpoint parsing, app-server protocol, session handling, command rendering, timeout, fallback, and failure-formatting checks required before migration.
- Out of scope: production, test, app, package descriptor, fixture, docs, roadmap, controller-state, public API, app-server protocol, endpoint parsing, session behavior, timeout behavior, fallback behavior, command rendering, failure formatting, prompt, event-schema, runtime compatibility, healthcheck, repair, replay, restart, or dry-run behavior changes; direct import migration; `Core.Ids`, `Workflow.EventLog`, or `Workflow.Permission` import convergence; Cabal exposed-module changes; public deprecation, migration, facade removal, release/publication, milestone-completion, or terminal-completion claims.
- Concurrent batch context: none; active state is serial with `max_parallel_rounds: 1`, and this selection opens one readiness evidence round only.

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
Milestone 003 remains dependency-ready because it depends only on the completed test-topology inventory, but it is not complete. Round 103 closed direction 011's current single-domain `Core.Ids` queue while leaving broader blocker-class work for later split-import or bridge-readiness slices. Round 104 completed direction 012 readiness evidence for `Workflow.EventLog` and `Workflow.Permission`, and the approved roadmap update explicitly kept milestone 003 in progress. Direction 010 has no recorded status in the active roadmap, so it is the next lawful import-convergence front before moving to milestone 004 large-module decomposition.

The existing round-097 inventory records `CodexWatcher.AppServerClient` as a pure public compatibility reexport with 19 imports: 12 under `src`, 7 under `test`, none under `app`, and none under the standalone package candidates. It also records every current source importer as `blocked/needs later evidence`, with required gates around endpoint parsing, app-server protocol, session initialization, timeout and fallback handling, command rendering, and failure formatting. A direct source migration would therefore skip the direction's own preconditions; the smallest high-value extraction is to refresh that evidence, classify the live importer set, and name the narrowest later implementation candidates with their exact verification gates.

This selection keeps the roadmap's evidence-first cleanup style. It preserves `CodexWatcher.AppServerClient` exposure and support, avoids behavior changes, and does not imply deprecation, Cabal exposure removal, facade removal, milestone completion, or terminal completion.
