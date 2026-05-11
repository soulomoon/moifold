### Squash Commit
- Title: Add Healthcheck app-server thread coverage
- Summary: Adds endpoint-backed watcher-core test coverage for the Healthcheck app-server thread inspection path. The approved round verifies the `thread/read` request shape, request id `9001`, `includeTurns = True`, configured thread id, successful latest-turn reporting, skipped cases for missing endpoint or missing thread id, and JSON-RPC/decode failure formatting while leaving production, package, protocol, and roadmap files unchanged.

### Merge Readiness
- Base branch freshness: confirmed locally. The base checkout is `codex/workflow-facade-extraction` at `130a768` before committing the squash; no upstream branch is configured and no `origin/codex/workflow-facade-extraction` ref was available for remote freshness comparison.
- Merge ordering satisfied: yes. `depends_on_round_ids` and `merge_after_item_ids` are empty, `pending_merge_rounds` is empty, and round state is at merge with `merge_ready = true`.
- Pending dependencies: none.

### Follow-Up Notes
The integrated round from `7d50656` is approved and ready for a squash commit on `codex/workflow-facade-extraction` using the title above. The timeout path remains an intentional non-goal for this round because the production timeout is hard-coded to five seconds and a timing-sensitive test was not required for the evidence gate.
