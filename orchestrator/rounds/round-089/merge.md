### Squash Commit
- Title: Record runtime owner healthcheck contract
- Summary: Round `round-089-runtime-owner-healthcheck-contract` locks the current `runtime-owner.json` healthcheck contract with focused runtime-owner JSON assertions, a source-policy healthcheck field-path assertion, and a narrow compatibility-policy note. The approved diff preserves the existing lease-shaped runtime-owner producer, existing healthcheck reader behavior, file names, scripts, fixtures, and production code while recording that this is contract evidence only, not cleanup or removal approval.

### Merge Readiness
- Base branch freshness: confirmed. `git merge-base HEAD codex/workflow-facade-extraction`, `git rev-parse HEAD`, and `git rev-parse codex/workflow-facade-extraction` all returned `8f9b6d1b53bb8c49be63acd174b52f1d8d2be21e`.
- Merge ordering satisfied: yes. `orchestrator/state.json` lists `pending_merge_rounds: []`; the active round has `depends_on_round_ids: []` and `merge_after_item_ids: []`; selection recorded no concurrent batch context and `max_parallel_rounds: 1`.
- Pending dependencies: none.

### Follow-Up Notes
Review approved the round after `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`. The merger re-ran the required `git diff --check` and it passed.

Later rounds must still treat runtime-owner compatibility cleanup as gated work. This round does not approve a healthcheck behavior change, fixture campaign, operator/downstream inventory completion, script change, schema migration, file rename/deletion, deprecation, facade removal, or public cleanup.
