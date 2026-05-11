### Squash Commit
- Title: Add IssueFanout app-server launch coverage
- Summary: Adds focused watcher-core coverage for the app-server-backed IssueFanout child implementer launch path. The approved round covers endpoint-backed `thread/start` launches, request ids starting at `8000`, launch workdir `cwd`, developer instruction context, persisted config/event/finalized manifest thread ids, child command rendering, retryable clone failure classification, fallback child-start classification ordering, and selected app-server failure formatting.

### Merge Readiness
- Base branch freshness: confirmed. `HEAD`, `codex/workflow-facade-extraction`, and their merge-base are all `c9b3a259d70efe15ab45b5cdcb0c1d02fa0d62c3` before the uncommitted round changes.
- Merge ordering satisfied: yes. `orchestrator/rounds/round-125/selection.md` declares no `depends_on_round_ids` and no `merge_after_item_ids`; the selection was serial with no concurrent batch.
- Pending dependencies: none.

### Follow-Up Notes
This round is coverage only. It does not migrate the production `IssueFanout` import, change production behavior, remove or deprecate the `CodexWatcher.AppServerClient` facade, alter public facade exposure, or complete milestone/package-boundary cleanup.
