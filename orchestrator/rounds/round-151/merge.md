### Squash Commit
- Title: Migrate AppServerClient test import to direct owners
- Summary: Round 151 completes the approved import-only migration for `round-151-main-appserverclient-direct-owner-import-migration`. `test/Main.hs` no longer imports the `CodexWatcher.AppServerClient` compatibility facade; the app-server symbols now come from their direct owner modules, `AppServerRequest` remains covered by `CodexWatcher.AppServerProtocol`, and the `CodexWatcher.ActionExecutor` import is narrowed so `AppServerInterpreter` is supplied only by `CodexWatcher.Workflow.Agent.Codex.Interpreter`.

### Merge Readiness
- Base branch freshness: confirmed against `codex/workflow-facade-extraction`; `HEAD`, `codex/workflow-facade-extraction`, and `git merge-base codex/workflow-facade-extraction HEAD` all resolve to `8ebbc6868b552a2f154d2c242652c88fa2bb1014`, and `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` passes.
- Merge ordering satisfied: yes. `orchestrator/state.json` records `stage: "merge"`, `active_round_id: "round-151"`, and the active round record has `stage: "merge"` with `merge_ready: true`.
- Pending dependencies: none. The active round has `depends_on_round_ids: []` and `merge_after_item_ids: []`; no pending merge order blocker is recorded.
- Review status: approved. `orchestrator/rounds/round-151/review.md` reports no findings and `orchestrator/rounds/round-151/review-record.json` records `"decision": "approved"`.

### Expected Files
- `test/Main.hs`: implementation diff only; import-only migration from `CodexWatcher.AppServerClient` to direct owner imports.
- `orchestrator/rounds/round-151/merge.md`: merger artifact for this round.
- `orchestrator/state.json`: already modified controller state in this worktree; not part of this merger's write ownership and not changed by this merger.

### Validation Evidence
- `git diff --check`: passed with no whitespace errors.
- `git diff --cached --check`: passed with no staged whitespace errors; there are currently no staged files.
- `git diff -- test/Main.hs`: import-only diff in the selected file.
- `git diff --name-only`: current unstaged paths are `orchestrator/state.json` and `test/Main.hs` before this `merge.md` artifact.
- `rg -n '^import CodexWatcher\.AppServerClient$' test/Main.hs`: no matches.
- `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Interpreter)|^import CodexWatcher\.AppServerProtocol|^import CodexWatcher\.ActionExecutor' test/Main.hs`: confirms `AppServerProtocol`, narrowed `ActionExecutor`, and direct owner imports for Client, Interpreter, and Transport.
- `rg -n '^import CodexWatcher\.AppServerClient$|CodexWatcher\.AppServerClient' src app test moifold.cabal docs`: no remaining exact source/app/test import of the facade; remaining hits are compatibility facade exposure, policy strings, and docs.
- Reviewer-recorded package checks: `cabal test watcher-core-test` passed, `cabal build all` passed, `git diff --check` passed, and `git diff --cached --check` passed.

### Explicit Non-Goals
- No production code changes.
- No test body, helper, assertion, failure-message, or behavior changes.
- No Cabal exposure cleanup.
- No docs or compatibility policy edits.
- No `CodexWatcher.AppServerClient` facade deletion, deprecation pragma, public API cleanup, or removal approval.
- No package publication, release approval, milestone completion, roadmap update, or terminal completion claim.

### Follow-Up Notes
Remaining `CodexWatcher.AppServerClient` references are intentional follow-up surfaces:

- `src/CodexWatcher/AppServerClient.hs`: compatibility facade remains available.
- `moifold.cabal`: exposed-module entry remains unchanged.
- `test/BoundaryPolicySpec.hs`: policy-string references remain unchanged.
- `docs/agentic-workflow-framework/*`: compatibility, readiness, release-note, and deprecation-policy references remain unchanged.

This round is ready for the controller to squash merge after it accounts for the existing controller-state edit and includes this merge artifact. It should not be treated as approval to remove or deprecate the facade.
