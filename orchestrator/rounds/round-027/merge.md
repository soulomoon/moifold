### Squash Commit
- Title: Add terminal and observation law assertions
- Summary: Round 027 strengthens the workflow facade extraction law coverage in `test/Main.hs` for DocsMigration and the PR-review checking indexed bridge. It adds assertions for indexed/unindexed observation parity, planned-event/apply consistency, replay determinism, terminal-state closure, and wrong-phase permission rejection while leaving runtime behavior, event codecs, golden fixtures, package boundaries, roadmap files, and compatibility facades unchanged.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction` at `27f346a7af7c5aefa9f18fe72e55254acdb5f22a`; `HEAD...codex/workflow-facade-extraction` is `0 0`. `origin` does not advertise a `codex/workflow-facade-extraction` ref, so there was no remote base ref to refresh.
- Merge ordering satisfied: yes. `selection.md` declares `depends_on_round_ids: []`, `merge_after_item_ids: []`, `parallel_group: null`, and the review is explicitly `APPROVED`.
- Pending dependencies: none. No pending merge rounds are recorded in `orchestrator/state.json`, and no scheduler dependency blockers are declared for this round.

### Follow-Up Notes
The approved implementation diff is limited to `test/Main.hs` plus orchestrator active-round metadata in `orchestrator/state.json`; this merge note is the only merger-authored file. Review evidence reports passing `cabal build watcher-core-test`, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`. No git merge, commit, or implementation edits were performed by the merger.
