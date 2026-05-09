### Selected Extraction
- Milestone: Write Cleanup Policy From Evidence
- Milestone id: `milestone-003-evidence-backed-cleanup-policy`
- Direction id: `direction-005-import-facade-cleanup-policy`
- Extracted item id: `round-056-import-facade-cleanup-policy`
- Extracted item summary: Write the evidence-backed cleanup policy for the six selected Haskell import facades using the round 052 inventory and round 054 replacement-readiness evidence, including preferred imports, keep/defer/remove-later classifications, and gates for any future deprecation or removal.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001`

### Boundaries
- In scope: policy documentation and project-contract alignment for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`, and `CodexWatcher.Workflow.Permission`; citations to current source scans, Cabal exposure, preferred replacement imports, protecting tests, missing evidence, and conservative readiness classifications.
- Out of scope: deprecation pragmas, import rewrites, Cabal exposed-module changes, facade removal, runtime compatibility-file policy, runtime file migration or removal, roadmap expansion, terminal cleanup, and any claim that this selection approves removal.
- Concurrent batch context: none; the active controller is in serial mode and the runtime compatibility cleanup policy remains a later sibling extraction under `direction-006-runtime-compatibility-cleanup-policy`.

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
Milestones 001 and 002 are complete, so milestone 003 is the next dependency-ready milestone. The import-facade policy direction has complete evidence from round 052's selected-facade inventory and round 054's replacement-readiness artifact, while the roadmap still forbids deprecation or removal until later gated cleanup. Selecting the import-facade policy first gives the planner a bounded policy-from-evidence task over a known six-module surface and preserves the roadmap rule that runtime compatibility-file policy, follow-up discovery, and final removals remain separate later work.
