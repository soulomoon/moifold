### Squash Commit
- Title: Stabilize Codex agent adapter API boundaries
- Summary: Approved round `round-032` for `item-032-codex-agent-adapter-api` stabilizes the `agent-workflow-codex` adapter surface with an additive `agentTurnStartRef` helper, focused app-server parser checks, typed turn-reference request coverage, and stronger recursive boundary scans that keep moifold issue/PR lifecycle policy out of the Codex adapter package.

### Merge Readiness
- Approved decision: `APPROVED` in `orchestrator/rounds/round-032/review.md` and `decision: approved` in `orchestrator/rounds/round-032/review-record.json`.
- Exact validations from review: `cabal build all` passed; `cabal test watcher-core-test` passed; `git diff --check` passed; `git diff --cached --check` passed; direct `rg` boundary scan for forbidden lifecycle/source tokens under `agent-workflow-codex/src` passed with no matches; direct `rg` forbidden lifecycle import scan under `agent-workflow-codex/src` passed with no matches.
- Base branch freshness: confirmed against the local `codex/workflow-facade-extraction` base; `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reported `0 0`, and `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` succeeded.
- Merge ordering satisfied: yes. `depends_on_round_ids` and `merge_after_item_ids` are empty, controller state has only `round-032` active, and `merge_ready` is true.
- Pending dependencies: none.

### Follow-Up Notes
The approved implementation changes are currently worktree changes rather than committed branch divergence; include the reviewed code/test files and round artifacts in the squash commit, but do not include unrelated local edits if any appear before merge. The branch has no configured upstream, so remote freshness was not established by this merge note. `orchestrator/state.json` is dirty from the controller state transition to merge stage; keep it only if the controller expects state artifacts in the squash.
