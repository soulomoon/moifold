### Selected Extraction
- Milestone: Exact Removal Or Terminal Hold
- Milestone id: `milestone-004-exact-removal-or-hold`
- Direction id: `direction-009-terminal-decision-report`
- Extracted item id: `round-082-terminal-decision-report`
- Extracted item summary: Produce an artifact-only terminal decision report for the facade-removal-readiness family, recording kept, deferred, deprecated, removed, and blocked surface sets for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission` without performing removal or implying that prior defer/hold decisions approved removal.
- Roadmap id: `2026-05-10-00-facade-removal-readiness`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001`

### Boundaries
- In scope: Round-local terminal decision artifact for the four selected facades; evidence review from rounds 075-081; explicit final sets for kept, deferred, deprecated, removed, and blocked surfaces; explanation that no exact removal surface is currently approved; validation command log appropriate for an artifact-only terminal report.
- Out of scope: Production code edits, test edits, documentation edits, package descriptor edits, roadmap edits, `orchestrator/state.json` edits, import migrations, deprecation pragmas, public deprecation wording, Cabal exposed-module removal, facade module deletion, runtime compatibility files, event schema changes, healthcheck, repair, release decisions, publication decisions, `CodexWatcher.Workflow.Types`, and `CodexWatcher.Workflow.Execution`.
- Concurrent batch context: none; active state keeps `max_parallel_rounds` at 1, and direction 008 is not dependency-ready because no milestone-003 evidence names an exact approved removal surface.

### Scheduler Fields
```json
{
  "depends_on_round_ids": ["round-075", "round-076", "round-077", "round-078", "round-079", "round-080", "round-081"],
  "merge_after_item_ids": [
    "round-075-import-scan-refresh",
    "round-076-behavior-owner-classification",
    "round-077-appserverclient-import-migration-readiness",
    "round-078-core-ids-split-import-migration",
    "round-079-eventlog-permission-readiness-hold",
    "round-080-public-deprecation-readiness-decision",
    "round-081-cabal-exposure-decision"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestones 001 through 003 are complete, so milestone 004 is the next dependency-ready milestone. Direction 008 requires milestone-003 approval naming an exact module or exposure entry for removal. That precondition is not satisfied: round 080 approved artifact-only public deprecation `defer` for all four selected facades, and round 081 approved artifact-only Cabal exposure `defer` for all four selected facades. Both rounds explicitly approved no public deprecation signal, Cabal exposure removal, public API change, package descriptor change, facade deletion, or future exact removal by implication.

The lawful next extraction is therefore direction 009. The report should close the family by preserving the exact blockers instead of converting defer or hold evidence into removal approval. It should state the removed-surface set explicitly as empty unless the worker finds reviewed roadmap evidence, already present before this selection, that names an exact approved removal surface.
