### Squash Commit
- Title: Move WorkflowDocsMigrationSpec to direct AppServerTurn owner
- Summary: This round migrates only `test/WorkflowDocsMigrationSpec.hs` away from the `CodexWatcher.AppServerClient` compatibility facade for `AppServerTurn (..)`, replacing it with the direct owner import `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`. The docs-migration test bodies, helpers, package descriptors, public facade, docs, and compatibility/removal policy surfaces remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` returned success, and both `HEAD` and the local base branch resolve to `377a38d` before the uncommitted round diff. `origin` does not advertise `codex/workflow-facade-extraction`, so this note makes no remote-freshness claim.
- Merge ordering satisfied: yes; `pending_merge_rounds` is empty, `depends_on_round_ids` is `[]`, `merge_after_item_ids` is `[]`, and `parallel_group` is `null`.
- Pending dependencies: none.
- Review evidence: `orchestrator/rounds/round-145/review.md` records `APPROVED`, and `orchestrator/rounds/round-145/review-record.json` has `"decision": "approved"`.
- Scheduler evidence: `orchestrator/state.json` has `stage: "merge"`, active round `round-145`, and `merge_ready: true`.
- Expected files in merge: `test/WorkflowDocsMigrationSpec.hs`, `orchestrator/state.json`, `orchestrator/rounds/round-145/selection.md`, `orchestrator/rounds/round-145/plan.md`, `orchestrator/rounds/round-145/implementation-notes.md`, `orchestrator/rounds/round-145/review.md`, `orchestrator/rounds/round-145/review-record.json`, and `orchestrator/rounds/round-145/merge.md`.
- Implementation diff shape: import-only in `test/WorkflowDocsMigrationSpec.hs`; the selected file now imports `AppServerTurn (..)` from `CodexWatcher.Workflow.Agent.Codex.Client` and no longer imports `CodexWatcher.AppServerClient`.
- Passed checks: selected-file facade-import guard, direct-owner import guard, docs-migration test symbol scan, broad remaining-facade inventory, `git diff -- test/WorkflowDocsMigrationSpec.hs`, `git diff --name-only`, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.

### Follow-Up Notes
- Non-goals preserved: no public facade removal or deprecation, no Cabal/API exposure cleanup, no docs cleanup, no package cleanup, no milestone or terminal completion, no release approval, and no public compatibility removal.
- Remaining `CodexWatcher.AppServerClient` references in package exposure, public facade implementation, other tests/helpers, and docs/policy/readiness files are intentional out-of-scope inventory for later roadmap selections.
- This merge note only prepares the approved round for controller squash merge; it does not perform the merge or approve any later compatibility-removal gate.
