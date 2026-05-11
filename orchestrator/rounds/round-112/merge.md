### Squash Commit
- Title: Add RunnerGuard repair-launch sequence coverage
- Summary: Adds endpoint-backed `RunnerGuard` test coverage for `startRunnerGuardRepairThread`, proving the repair launch sends `thread/start`, `thread/name/set`, and `turn/start` in order with request ids `1`, `2`, and `3`. The tests also assert the repair thread id, repair turn id, repair thread name, repair cwd, developer instructions, repair prompt contents, and stable formatted failures for launch, name-set, turn-start, and turn-start parse failures.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; both the round branch and local base resolve to `a45ecb9e1b6fef373938724616c8a538a1f026c3`, and the local base is an ancestor of `HEAD`. Remote freshness could not be refreshed because `origin` does not advertise `codex/workflow-facade-extraction`.
- Merge ordering satisfied: yes. `pending_merge_rounds` is empty, `merge_after_item_ids` is empty, and the active round is in `stage: "merge"` with `merge_ready: true`.
- Pending dependencies: none. `depends_on_round_ids` is empty, `parallel_group` is null, and `worker_mode` is `none`.

### Follow-Up Notes
Review approved the round, and `review-record.json` records decision `approved`.

No `orchestrator/rounds/round-112/worker-plan.json` exists.

Changed paths are limited to `test/RunnerGuardSpec.hs`, `orchestrator/state.json`, and round-112 artifacts. The production diff guard for `RunnerGuard.hs`, `AppServerClient.hs`, Codex client, transport, and protocol files is empty.

Validation evidence recorded by implementation and review:
- `printf 'RunnerGuardSpec.runnerGuardActiveTurnInspectionTests\n:quit\n' | cabal repl watcher-core-test` passed.
- `cabal test watcher-core-test` passed.
- `cabal build all` passed.
- `git diff --check` passed.
- `git diff --cached --check` passed.
