### Squash Commit
- Title: Add indexed WorkflowSpec compatibility bridge
- Summary: This round adds an additive `WorkflowSpecIndexedBridge` in `agent-workflow-core`, migrates the DocsMigration and representative PR-review checking indexed adapters through that bridge, and adds focused source-scan and workflow regression coverage proving labels, replay projection, terminal checks, validation, permissions, and effect labels remain aligned with the existing unindexed specs.

### Merge Readiness
- Base branch freshness: confirmed. The round branch and local `codex/workflow-facade-extraction` are both at `a6e5722` with `0 0` left/right divergence. `origin` does not currently advertise `codex/workflow-facade-extraction`, so remote freshness could not be compared.
- Merge ordering satisfied: yes. Scheduler fields declare `depends_on_round_ids: []`, `merge_after_item_ids: []`, `parallel_group: null`, and this round has no earlier merge dependency.
- Pending dependencies: none. `review.md` and `review-record.json` both approve the round, and the reviewer found no plan, boundary, fixture, daemon/runtime, codec, roadmap, selection, or implementation-note blockers.

### Follow-Up Notes
The approved diff is limited to the bridge API, the two planned adapter migrations, focused tests, and controller state metadata. Squash merge should not include any additional implementation edits beyond the already-reviewed round diff.
