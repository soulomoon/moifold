### Squash Commit
- Title: Inventory Haskell compatibility import facades
- Summary: Adds the evidence-only inventory for the selected public compatibility import facades: `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`, and `CodexWatcher.Workflow.Permission`. The round records facade shape, Cabal exposure, repo-local users, preferred replacement imports, protecting tests, scan evidence, and unresolved unknowns without changing production code, descriptors, roadmap/state files, imports, policy, runtime compatibility files, deprecation status, or removal status.

### Merge Readiness
- Base branch freshness: confirmed. Local `codex/workflow-facade-extraction` is an ancestor of `orchestrator/round-052-compatibility-cleanup-slice`; both currently resolve to `67d982351f2dd8313bc615a3b7483002d6e4e0bc`.
- Merge ordering satisfied: yes. Selection declares no `merge_after_item_ids`, and no concurrent batch or pending merge ordering blocker is recorded for this round.
- Pending dependencies: none. Selection declares no `depends_on_round_ids`, and review approved the evidence-only result.

### Follow-Up Notes
The controller can squash merge the round-local evidence artifacts. The direct remote fetch refspec for the named base branch was not available from `origin`, so freshness was confirmed against the local canonical base and round branch refs in this worktree. Future cleanup rounds should treat this inventory as evidence only; it does not approve facade deprecation, import rewrites, module removal, or runtime compatibility-file changes.
