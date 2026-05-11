### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-104-eventlog-permission-bridge-split-readiness`
- Extracted item summary: Refresh and record exact readiness evidence for the mixed `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` compatibility facades, separating reusable direct-owner candidates from concrete moifold bridge helpers and test-policy evidence before any import convergence, public API, Cabal exposure, or removal work.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: artifact-only readiness evidence for `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission`; current exact import scans over `src`, `app`, `test`, and standalone package candidates; classification of direct-owner reusable core/audit uses versus product-owned moifold wrapper or permission-policy helpers; identification of the focused golden replay, old-log parsing, event JSON `type`, transition/replay parity, wrapper behavior, permission soundness, phase-validation, state/effect validation, public API, and downstream evidence needed before later convergence or public-surface work.
- Out of scope: production, test, app, package descriptor, fixture, docs, roadmap, controller-state, public API, event-schema, golden-log, permission, replay, audit, runtime compatibility, healthcheck, repair, command-output, prompt, behavior, or public exposure changes; `AppServerClient` or `Core.Ids` import convergence; direct import migration; Cabal exposed-module changes; public deprecation, migration, facade removal, release/publication, milestone-completion, or terminal-completion claims.
- Concurrent batch context: none; active state is serial with `max_parallel_rounds: 1`, and this selection opens one evidence/readiness round only.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 009 supplied the accepted selected-facade import inventory. Direction 011's current single-domain `Core.Ids` queue is closed by the accepted round-103 evidence and roadmap update, while milestone 003 remains in progress. The next smallest high-value extraction in the same milestone is therefore direction 012 readiness for the two remaining mixed workflow bridge facades.

The current scan still shows `CodexWatcher.Workflow.EventLog` as a mixed surface with 2 `src` imports and 8 `test` imports, and `CodexWatcher.Workflow.Permission` as a test-policy surface with 7 `test` imports and no production or app imports. Round 097 already identified the core risk: `Workflow.EventLog` combines reusable event-log/audit exports with concrete moifold wrappers, and `Workflow.Permission` combines reusable permission-core exports with concrete moifold policy helpers. A focused readiness artifact is needed before any later import-convergence slice can distinguish safe direct-owner candidates from product-owned bridge behavior.

This selection is higher value than starting milestone 004 large-module decomposition because it continues the active import-convergence milestone after the `Core.Ids` queue closure and produces the exact bridge evidence required before public facade, Cabal exposure, or removal decisions. The round must keep both compatibility facades exposed and supported, must not change behavior, and must not imply deprecation, removal, milestone completion, or terminal completion.
