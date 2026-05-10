### Squash Commit
- Title: Add daemon-state compatibility fixtures
- Summary: Adds focused checked-in fixtures and watcher-core assertions for the current active and stopped `daemon-state.json` compatibility shapes. The round locks exact JSON fixture shapes, snapshot-reader tolerance, representative compatibility writer output, and existing healthcheck, repair, and restart source boundaries without changing production behavior or approving any compatibility-file rename, deletion, migration, deprecation, or removal.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction` at `c312420`; the round branch `orchestrator/round-091-highest-value-cleanup-slice` is also at `c312420`, and both ancestry checks pass. `origin` does not advertise `codex/workflow-facade-extraction`, so no remote freshness check was available for that branch name.
- Merge ordering satisfied: yes. `orchestrator/state.json` records `stage: merge`, active `round-091`, `pending_merge_rounds: []`, `max_parallel_rounds: 1`, `merge_ready: true`, and the review artifacts approve `round-091-daemon-state-compatibility-fixtures`.
- Pending dependencies: none. The active round declares `depends_on_round_ids: []` and `merge_after_item_ids: []`.

### Follow-Up Notes
This merge prepares only the selected daemon-state fixture slice. It does not approve broader runtime compatibility cleanup, public deprecation, Cabal exposure removal, facade removal, schema migration, compatibility-file deletion or rename, release approval, or terminal roadmap completion.
