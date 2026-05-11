### Squash Commit
- Title: Move common turn classifier to direct AppServerTurn import
- Summary: This round moves `src/CodexWatcher/Turn/Classifier/Common.hs` off the `CodexWatcher.AppServerClient` compatibility facade for `AppServerTurn` and imports the type directly from `CodexWatcher.Workflow.Agent.Codex.Client`. The approved diff is limited to that import convergence change; classifier behavior, package descriptors, public facade exposure, docs, fixtures, and tests are unchanged.

### Merge Readiness
- Base branch freshness: confirmed. The round branch is on local `codex/workflow-facade-extraction` at `43fc4c3`; the local base is an ancestor of `HEAD` with no committed divergence. Local `origin/main` is available at `ceb4ff1`, matches `git ls-remote origin refs/heads/main`, and is an ancestor of the local base/round branch. No `origin/codex/workflow-facade-extraction` ref exists locally or via `ls-remote`, so freshness for the named base is confirmed against the local base branch rather than a remote base ref.
- Merge ordering satisfied: yes. `orchestrator/state.json` has `stage: merge`, `active_round_id: round-106`, this active round is in `stage: merge`, `merge_ready: true`, `pending_merge_rounds: []`, `depends_on_round_ids: []`, and `merge_after_item_ids: []`.
- Pending dependencies: none.

### Follow-Up Notes
The review decision is **APPROVED** and is limited to the selected `Common.hs` import move. It does not approve facade deprecation/removal, package descriptor changes, classifier behavior changes, milestone completion, terminal roadmap completion, or the pre-existing `orchestrator/state.json` diff.

Validation recorded by the reviewer passed for `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, `git diff --cached --check`, import scans, descriptor/facade diff checks, worker-plan absence, and `jq empty orchestrator/state.json`. As merger, I rechecked branch/status, review approval, ordering/dependencies, base freshness, and diff hygiene after writing this file.
