### Squash Commit
- Title: Move IssueFanout off AppServerClient facade
- Summary: This approved round converges the production `IssueFanout` import path away from the public `CodexWatcher.AppServerClient` facade and onto the owning workflow agent Codex client and transport modules. The implementation diff is import-only in `src/CodexWatcher/Cli/Command/IssueFanout.hs`; behavior bodies, tests, support modules, public facade exposure, Cabal/API surfaces, docs, fixtures, runtime compatibility files, and owner implementations remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed. `git rev-parse HEAD`, `git rev-parse codex/workflow-facade-extraction`, and `git merge-base HEAD codex/workflow-facade-extraction` all resolve to `b43495fc763bdecaefb9b2a4cf04daa74be9fbd6` before the uncommitted round changes.
- Merge ordering satisfied: yes. `depends_on_round_ids` and `merge_after_item_ids` are both empty for `round-126`, and there are no pending merge rounds in controller-visible state.
- Pending dependencies: none.

### Follow-Up Notes
This is production import convergence only. It does not remove or deprecate the public `CodexWatcher.AppServerClient` facade, does not clean up Cabal/API exposure, does not migrate tests or test support, and does not complete the broader milestone.
