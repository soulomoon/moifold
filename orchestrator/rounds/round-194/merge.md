### Squash Commit
- Title: Round 194: Migrate runtime compatibility fixture ID imports
- Summary: Migrate `test/RuntimeCompatibilityFixtureSpec.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. The approved diff is import-only for the selected runtime compatibility fixture spec, preserving fixture JSON, repair-state checks, healthcheck reader boundaries, daemon-state assertions, planning graph assertions, PASS labels, and aggregate wiring.

### Merge Readiness
- Base branch freshness: confirmed against the observable local base. `HEAD`, `codex/workflow-facade-extraction`, and their merge-base are all `353922ec54e9eff3e7fe416debd6a656121856af`; no `origin/codex/workflow-facade-extraction` ref is present or advertised by `origin`, so remote freshness is not separately asserted.
- Merge ordering satisfied: yes. `review.md` and `review-record.json` approve `direction-011i-runtime-compatibility-fixture-core-ids-import`; the active state records `merge_ready: true`, `pending_merge_rounds: []`, `depends_on_round_ids: []`, `merge_after_item_ids: []`, and `parallel_group: null`.
- Pending dependencies: none.

### Follow-Up Notes
Remaining `CodexWatcher.Core.Ids` users in `test/FacadeImportPolicySpec.hs`, `test/Main.hs`, `src/CodexWatcher/Core/Ids.hs`, and `moifold.cabal` are out of scope for this round and remain for later selected roadmap items. This merge should not be treated as public facade removal, Cabal exposure removal, compatibility-file cleanup, milestone completion, or terminal closeout approval.
