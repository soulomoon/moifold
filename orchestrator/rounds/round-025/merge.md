### Squash Commit
- Title: Add workflow spec inventory and law baselines
- Summary: This round adds focused workflow facade extraction coverage in `test/Main.hs`: a source-scan inventory for current `WorkflowSpec` and `IndexedWorkflowSpec` hooks and concrete spec surfaces, a DocsMigration indexed/unindexed law baseline for draft replay, terminal checks, validation, and effect permissions, and stronger PR-review mergeability assertions for indexed labels, effects, plans, and terminal status. The approved diff is test/source-scan only and does not change runtime behavior, event codecs, golden fixtures, roadmap files, or public API shape.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; both the round branch and base branch resolve to `69a539e496fafd0caa668431a7eb28d7f6fdb390`. Remote freshness is not separately confirmable because `origin` has no `codex/workflow-facade-extraction` ref.
- Merge ordering satisfied: yes. Scheduler fields declare `depends_on_round_ids: []`, `merge_after_item_ids: []`, `parallel_group: null`, and `merge_ready: false`; the roadmap context keeps milestone 001 on the serial lane with no earlier declared blocker for this item.
- Pending dependencies: none. `review.md` and `review-record.json` mark the round approved after the focused workflow facade extraction test, full `watcher-core-test`, `cabal build all`, whitespace checks, package-boundary scan, and manual diff checks.

### Follow-Up Notes
The approved implementation is currently present as a worktree diff, not as a branch commit. Existing non-merge-note changes in this worktree include `orchestrator/state.json`, `test/Main.hs`, and the round artifact files; merge preparation only added this `merge.md`.
