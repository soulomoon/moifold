### Squash Commit
- Title: Move RunnerGuard to direct Codex app-server imports
- Summary: This round moves only `src/CodexWatcher/RunnerGuard.hs` off the public `CodexWatcher.AppServerClient` compatibility facade by importing the same app-server client symbols from `CodexWatcher.Workflow.Agent.Codex.Client` and transport symbols from `CodexWatcher.Workflow.Agent.Codex.Transport`. The production diff is import-only: no RunnerGuard behavior, request ids, repair prompts, failure formatting, app-server protocol usage, package descriptors, facade exposure, tests, docs, or other importers changed.

### Merge Readiness
- Base branch freshness: confirmed locally. `codex/workflow-facade-extraction` and `orchestrator/round-113-highest-value-cleanup-slice` both resolve to `8541cc5276a73c096653961e1295abb03c1f26c8`, and local ancestry checks pass both directions. Remote freshness could not be established because `origin` did not advertise `codex/workflow-facade-extraction` or `orchestrator/round-113-highest-value-cleanup-slice` via `git ls-remote --heads`.
- Merge ordering satisfied: yes. The active round has no `depends_on_round_ids`, no `merge_after_item_ids`, no parallel group, `worker_mode` is `none`, reviewer approval is recorded, and state has `merge_ready: true`.
- Pending dependencies: none.

### Follow-Up Notes
Changed paths are limited to the expected implementation, controller-state, and round-artifact paths: `src/CodexWatcher/RunnerGuard.hs`, `orchestrator/state.json`, and `orchestrator/rounds/round-113/*`. The remaining `CodexWatcher.AppServerClient` source and test-policy importers are intentionally left for later selected rounds, so direction 010 remains in progress after this squash.
