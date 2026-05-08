### Squash Commit
- Title: Extract generic daemon failure projection into workflow core
- Summary: Round 031 adds an ownership-neutral daemon failure projection to `agent-workflow-core`, routes the moifold daemon compatibility wrapper through it, and strengthens focused daemon projection tests plus recursive boundary scans so concrete daemon lifecycle, runtime ownership, filesystem/process behavior, healthcheck, repair, and concrete watcher event/state policy remain in moifold.

### Merge Readiness
- Approved decision: APPROVED in `orchestrator/rounds/round-031/review.md` and `orchestrator/rounds/round-031/review-record.json`.
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; `HEAD`, `codex/workflow-facade-extraction`, and `orchestrator/round-031-next-framework-slice` all resolve to `c260035e4d716410dc3f21038cc2d4f394d110d6`, with `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reporting `0 0`.
- Merge ordering satisfied: yes. `depends_on_round_ids`, `merge_after_item_ids`, and `parallel_group` are empty; controller state has `stage: merge` and `merge_ready: true` for `item-031-daemon-core-boundary`.
- Pending dependencies: none.
- Review validations: `cabal build all` passed; `cabal test watcher-core-test` passed; `git diff --check` passed; `git diff --cached --check` passed; direct `rg` scan over `agent-workflow-core/src` found no forbidden concrete daemon/runtime ownership imports or tokens; cabal boundary inspection confirmed `agent-workflow-core` still exposes `CodexWatcher.Workflow.Daemon.Core` and depends only on `base`, `bytestring`, and `text`.

### Follow-Up Notes
The squash should preserve the narrow boundary: `WorkflowObservedDaemonTickFailure` remains parameterized and generic, while `DaemonObservedTransactionFailure`, `DaemonOptions`, compatibility writes, event-log files, concrete `WatcherEvent`/`SomeWatcherState` wrappers, runtime/process/filesystem behavior, child-daemon lifecycle, healthcheck, and repair stay outside `agent-workflow-core`.

Merge caveat: this merger role did not run git merge, stage, or commit. The worktree is intentionally dirty with the reviewed round implementation and artifacts; this note only adds `orchestrator/rounds/round-031/merge.md`.
