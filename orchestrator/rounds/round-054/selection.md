### Selected Extraction
- Milestone: Prove Replacement Paths And Behavior Gates
- Milestone id: `milestone-002-replacement-paths-and-behavior-gates`
- Direction id: `direction-003-import-replacement-readiness`
- Extracted item id: `round-054-import-replacement-readiness`
- Extracted item summary: Prove readiness for the selected public import facades by turning the round 052 inventory into recursive import scans, preferred replacement-path evidence, package-boundary assertions, and a keep/defer/remove-later classification without removing or deprecating any facade.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001`

### Boundaries
- In scope: tests, docs, and evidence artifacts that prove current import users, replacement modules, Cabal exposure, package-boundary expectations, and readiness classification for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`, and `CodexWatcher.Workflow.Permission`.
- Out of scope: removing wrappers, adding deprecation pragmas, changing public module exposure, broad production import rewrites not needed for evidence, runtime compatibility-file behavior gates, cleanup policy, roadmap expansion, and final removal approval.
- Concurrent batch context: none selected; the controller state allows one active round, and runtime behavior gates remain a separate dependency-ready milestone 002 direction after this import-readiness slice.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [
    "round-052",
    "round-053"
  ],
  "merge_after_item_ids": [],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 002 is now dependency-ready because milestone 001 completed the import-facade inventory in round 052 and the runtime compatibility-file inventory in round 053. The import-readiness direction is the smallest next valuable extraction because the roadmap already names the facade set and asks for recursive scan and package-boundary evidence before policy or removal. This round should produce readiness evidence and missing tests where needed while preserving every compatibility surface for later policy and gated-removal decisions.
