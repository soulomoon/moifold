# Worker Plan Schema

`worker-plan.json` is the planner-authored machine contract for worker fan-out.
The controller may schedule workers from this file, but it must not infer
worker ownership or dependency order from `plan.md` prose.

## `worker-plan.json`

```json
{
  "schema_version": "worker-plan-v1",
  "round_id": "round-001-example",
  "roadmap_id": "YYYY-MM-DD-00-example",
  "roadmap_revision": "rev-001",
  "roadmap_dir": "orchestrator/roadmaps/YYYY-MM-DD-00-example/rev-001",
  "milestone_id": "milestone-001-example",
  "direction_id": "direction-001-example",
  "extracted_item_id": "item-001-example",
  "workers": [
    {
      "worker_id": "worker-001",
      "summary": "Bounded worker assignment",
      "assignment_path": "orchestrator/rounds/round-001-example/workers/worker-001/assignment.md",
      "write_scope": ["src/example"],
      "depends_on_worker_ids": [],
      "blocks_integration": true,
      "verification_commands": ["cabal test example-test"]
    }
  ],
  "integration": {
    "summary": "Integrate worker outputs in the canonical round worktree",
    "depends_on_worker_ids": ["worker-001"],
    "verification_commands": ["cabal test example-test"],
    "integration_notes_path": "orchestrator/rounds/round-001-example/implementation-notes.md"
  }
}
```

Use `null` for `milestone_id` and `direction_id` only when the active roadmap
style is `legacy-flat`.

## Worker Record State

Controller-owned `state.json.worker_records` entries use this shape:

```json
{
  "worker-001": {
    "status": "pending",
    "branch": "orchestrator/round-001-example-worker-001",
    "worktree_path": "orchestrator/worktrees/round-001-example-worker-001",
    "assignment_path": "orchestrator/rounds/round-001-example/workers/worker-001/assignment.md",
    "implementation_notes_path": "orchestrator/rounds/round-001-example/workers/worker-001/implementation-notes.md",
    "handoff_path": "orchestrator/rounds/round-001-example/workers/worker-001/handoff.md",
    "depends_on_worker_ids": [],
    "resume_error": null
  }
}
```

Allowed worker statuses are:

- `pending`: assignment exists but work has not started
- `running`: worker branch/worktree has been launched
- `blocked`: worker needs recovery or user-visible blockage handling
- `complete`: worker handoff exists and is ready for integration
- `integrated`: worker output has been consumed by the integration implementer

The integration phase begins only after every `blocks_integration` worker is
`complete`. During integration, the round record uses `worker_mode:
"integrate"` and the controller launches the integration implementer in the
canonical round worktree. After integration writes the round-level
`implementation-notes.md`, the round advances to review.
