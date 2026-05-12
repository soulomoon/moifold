### Squash Commit
- Title: Import AppServerTurn directly in WorkflowAgentSpec
- Summary: Round 146 moves only `test/WorkflowAgentSpec.hs` off the public compatibility facade `CodexWatcher.AppServerClient` for `AppServerTurn (..)`, importing that type from the direct owner module `CodexWatcher.Workflow.Agent.Codex.Client`. Existing workflow agent role, PR-review worker/reviewer turn-classifier, observation-kernel, and app-server turn-read assertions remain unchanged.

### Merge Readiness
- Review decision: approved. `orchestrator/rounds/round-146/review.md` records `APPROVED`, and `orchestrator/rounds/round-146/review-record.json` records `"decision": "approved"`.
- Merge ready flag: confirmed. `orchestrator/state.json` records round 146 with `"stage": "merge"` and `"merge_ready": true`.
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`. The round branch `orchestrator/round-146-highest-value-cleanup-slice`, `HEAD`, and local base ref all resolve to `1eceeb98f576ac04cd5aaad99469b8f13ec279b3`; `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` returned success. `git ls-remote origin refs/heads/codex/workflow-facade-extraction` returned no advertised remote ref, so no newer remote base was found.
- Merge ordering satisfied: yes. `orchestrator/state.json` records `"pending_merge_rounds": []`, `"depends_on_round_ids": []`, `"merge_after_item_ids": []`, and `"parallel_group": null` for round 146.
- Pending dependencies: none.

### Expected Files
- `test/WorkflowAgentSpec.hs`: import-only implementation change replacing `import CodexWatcher.AppServerClient` with `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
- `orchestrator/state.json`: controller state for round 146 at merge stage.
- `orchestrator/rounds/round-146/selection.md`: selected item and scope boundary.
- `orchestrator/rounds/round-146/plan.md`: import-only implementation and verification plan.
- `orchestrator/rounds/round-146/implementation-notes.md`: implementation evidence and explicit non-goals.
- `orchestrator/rounds/round-146/review.md`: reviewer approval and validation evidence.
- `orchestrator/rounds/round-146/review-record.json`: machine-readable approval summary.
- `orchestrator/rounds/round-146/merge.md`: this merger readiness note.

### Passed Checks
- `rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowAgentSpec.hs`: no matches recorded in review evidence.
- `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client \(AppServerTurn \(\.\.\)\)' test/WorkflowAgentSpec.hs`: direct owner import recorded at `test/WorkflowAgentSpec.hs:23`.
- Direct owner scan in `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`: module declaration, `AppServerTurn (..)` export, and `data AppServerTurn` definition recorded present.
- Selected behavioral anchor scan in `test/WorkflowAgentSpec.hs`: existing workflow agent tests, classifier calls, app-server turn-read assertion text, and `AppServerTurn` use sites recorded present.
- Broad `CodexWatcher.AppServerClient` scan: remaining matches recorded as out of scope for this selected round.
- `git diff -- test/WorkflowAgentSpec.hs`: recorded as import-only.
- `git diff --name-only`: recorded tracked diffs before review artifact writes as `orchestrator/state.json` and `test/WorkflowAgentSpec.hs`.
- `cabal test watcher-core-test`: passed per review evidence.
- `cabal build all`: passed per review evidence.
- `git diff --check`: passed per review evidence.
- `git diff --cached --check`: passed per review evidence.

### Follow-Up Notes
Explicit non-goals: do not remove or deprecate the public `CodexWatcher.AppServerClient` facade, do not change Cabal exposure or package descriptors, do not change production code, do not change test bodies or helper modules, do not update docs/policy text, do not migrate remaining facade users, and do not claim milestone completion, release approval, terminal completion, or public compatibility removal from this round.
