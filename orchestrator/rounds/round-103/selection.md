### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-103-core-ids-remaining-blocker-readiness`
- Extracted item summary: Refresh and record the remaining `CodexWatcher.Core.Ids` import set after rounds 098 through 102, prove the previously accepted single-domain candidates are exhausted, and classify the remaining users as evidence-blocked combined users for later split-import or next-direction planning.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: artifact-only readiness evidence for `CodexWatcher.Core.Ids`; current exact import scans over `src`, `app`, `test`, and standalone package candidates; confirmation that the five round-097 single-domain candidates completed by rounds 098 through 102 no longer import the facade; classification of the remaining current users by file and blocker type; a concise recommendation on whether direction 011 has any safe next single-domain implementation slice.
- Out of scope: production, test, app, package descriptor, fixture, docs, roadmap, controller-state, public API, parser, renderer, command-output, prompt, runtime-config, event-schema, healthcheck, repair, replay, restart, dry-run, action-order, or runtime compatibility behavior changes; `AppServerClient`, `Workflow.EventLog`, or `Workflow.Permission` import convergence; Cabal exposed-module changes; public deprecation, migration, facade removal, release/publication, milestone-completion, or terminal-completion claims.
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
Milestone 003 remains dependency-ready because it depends only on the completed test-topology inventory, and direction 009 supplied the accepted selected-facade import inventory used for Core.Ids convergence. Direction 011 has now landed the known safe single-domain candidates from that inventory: `test/BoundaryPolicySpec.hs`, `src/CodexWatcher/Workflow/Execution.hs`, `src/CodexWatcher/Core/State.hs`, `app/Main.hs`, and `test/WorkflowDocsMigrationSpec.hs`.

A current exact `CodexWatcher.Core.Ids` import scan shows 39 remaining imports, grouped as `src`: 29 and `test`: 10, with no `app` or standalone package-candidate imports. The remaining imports are the combined/blocker class rather than the accepted single-domain class; moving them mechanically would require parser, renderer, prompt, output, runtime-config, fixture, command-behavior, event-log, or test-policy evidence depending on the file.

This is the smallest dependency-ready high-value extraction under direction 011 because it closes the stale blocker state before selecting riskier combined-user implementation work or moving to direction 012 bridge-split readiness. The round should produce reviewed evidence only; it must keep `CodexWatcher.Core.Ids` exposed and supported, and it must not imply public deprecation, Cabal exposure removal, facade removal, milestone completion, or terminal completion.
