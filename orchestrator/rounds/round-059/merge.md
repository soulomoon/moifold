### Squash Commit
- Title: Expand compatibility cleanup roadmap
- Summary: Publish the approved artifact-only roadmap expansion for `2026-05-09-01-compatibility-surface-cleanup` by adding immutable revision `rev-002`. The revision keeps milestones 001-004 complete, adds import-facade, runtime compatibility, and external operator/downstream evidence milestones before gated removals, and preserves explicit reviewer approval requirements before any migration, deprecation, removal, package publication, upload, or release.

### Merge Readiness
- Base branch freshness: confirmed. `HEAD`, `codex/workflow-facade-extraction`, and their merge-base all resolve to `4ff0331f4c9de172975b2cf6fcf3f9840fcd9ef4`.
- Merge ordering satisfied: yes. `selection.md` declares no dependencies, no merge-after items, and no parallel group; `state.json` is serial with `max_parallel_rounds: 1` and no pending merge rounds.
- Pending dependencies: none.

### Follow-Up Notes
Review approved the artifact-only round. After squash merge, the controller can run the roadmap update step to activate `roadmap_revision` `rev-002` at `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`. Later cleanup remains blocked on the new evidence milestones and explicit reviewer approval for exact selected removal surfaces.
