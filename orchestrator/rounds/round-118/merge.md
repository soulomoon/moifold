### Squash Commit
- Title: Add Observe command app-server coverage
- Summary: This round adds black-box `observeOnce` coverage for Observe command app-server interpreter behavior before any `AppServerClient` import migration. The tests cover execute-mode failure when no app-server endpoint is configured, dry-run success through the null-interpreter fallback without requiring an endpoint, and configured-endpoint fake app-server traffic for execute mode. The round wires the new coverage into `watcher-core-test` through `test/Main.hs` and `moifold.cabal` test metadata while keeping production code, import migration surfaces, app-server protocol/client/transport code, runtime compatibility files, fixtures, docs, and public API exposure untouched.

### Merge Readiness
- Base branch freshness: confirmed. Local base `codex/workflow-facade-extraction` is an ancestor of `orchestrator/round-118-highest-value-cleanup-slice`.
- Merge ordering satisfied: yes. `depends_on_round_ids` and `merge_after_item_ids` are empty, `pending_merge_rounds` is empty, and the approved round is in merge stage with `merge_ready: true`.
- Pending dependencies: none.

### Follow-Up Notes
Review decision is APPROVED. This round is ready for the controller or maintainer to squash merge with the title above. A later round may select the actual Observe import migration, but this merge artifact does not approve facade deprecation, public API removal, Cabal exposure cleanup, runtime compatibility-file changes, milestone completion, release approval, or terminal completion.
