### Squash Commit
- Title: Round 195: Classify remaining Core.Ids test imports
- Summary: Records artifact-only classification evidence for the two remaining test `CodexWatcher.Core.Ids` imports. `test/FacadeImportPolicySpec.hs` is classified as intentional facade-policy evidence, and `test/Main.hs` is classified as watcher-core-test aggregate/property wiring evidence. The round does not change production code, test code, fixtures, docs, Cabal files, roadmap files, or controller state.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction` at `4caf46ed6a0be00f5ef89f026239b12b77a940e1`; the round branch is at the same commit and the local base is an ancestor of `HEAD`. `origin` does not advertise `codex/workflow-facade-extraction`, so no remote freshness update was available.
- Merge ordering satisfied: yes; `depends_on_round_ids` and `merge_after_item_ids` are empty, `parallel_group` is null, and there are no pending merge rounds in state.
- Pending dependencies: none.

### Follow-Up Notes
Review approved the artifact-only classification in `orchestrator/rounds/round-195/review.md` and `orchestrator/rounds/round-195/review-record.json`. Cabal build/test baselines were intentionally skipped under the active verification contract because the reviewed diff is limited to round-local classification artifacts.
