### Squash Commit
- Title: Add AutomaticLoop runner app-server coverage
- Summary: This round adds focused watcher-core coverage for the automatic-loop runner's app-server behavior before any later `CodexWatcher.AppServerClient` import migration. The new tests exercise `runAutomaticLoop` execute mode against a configured endpoint-backed app-server, prove the matching dry-run path sends no live endpoint traffic, and preserve retry/fallback classification for transport, decode/replay, and unexpected-start-plan failures. The implementation stays coverage-only, with only watcher-core test wiring and test-suite metadata added.

### Merge Readiness
- Base branch freshness: confirmed locally against `codex/workflow-facade-extraction` at `32a54bad7d4c0fde4cb30f21102c4fcf068b9c91`; remote refresh was attempted but failed because the SSH fetch connection closed.
- Merge ordering satisfied: yes. `depends_on_round_ids` and `merge_after_item_ids` are empty, `parallel_group` is null, and `max_parallel_rounds` is 1.
- Pending dependencies: none.

### Follow-Up Notes
Review decision is approved in `orchestrator/rounds/round-121/review.md` and `review-record.json`. The recorded validation passed the focused GHCi check, `cabal test watcher-core-test`, `cabal build all`, diff checks, scope guards, and worker-plan absence check. No production import migration was made; `src/CodexWatcher/AutomaticLoop/Runner.hs` has no diff.
