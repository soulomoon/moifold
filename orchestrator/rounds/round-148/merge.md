### Squash Commit
- Title: Move Workflow test support AppServerTurn import to direct owner
- Summary: Round 148 moves only `test/TestSupport/Workflow.hs` off the `CodexWatcher.AppServerClient` compatibility facade for `AppServerTurn (..)`. The selected helper now imports `AppServerTurn (..)` from `CodexWatcher.Workflow.Agent.Codex.Client`; helper exports, helper bodies, fixtures, test bodies, production code, package descriptors, docs, facade exposure, and direct-owner exports remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed locally. Branch `orchestrator/round-148-highest-value-cleanup-slice`, `HEAD`, base `codex/workflow-facade-extraction`, and the local merge-base all resolve to `7bb7ec4d3bdc959bb790a5534c68504139b46aa9`; `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` returned success.
- Merge ordering satisfied: yes. `orchestrator/state.json` has `stage: "merge"`, `active_round_id: "round-148"`, active round `stage: "merge"`, `merge_ready: true`, `depends_on_round_ids: []`, `merge_after_item_ids: []`, and `pending_merge_rounds: []`.
- Pending dependencies: none.
- Review approval: confirmed. `orchestrator/rounds/round-148/review.md` reports no findings and `APPROVED`; `review-record.json` has `"decision": "approved"`.
- Expected files: `test/TestSupport/Workflow.hs` as the approved import-only implementation change; `orchestrator/rounds/round-148/merge.md` as this merger artifact. The existing `orchestrator/state.json` diff is controller state for this round and was not edited by the merger.

### Validation Evidence
- `git diff --check`: passed with no whitespace errors.
- `git diff --cached --check`: passed with no staged whitespace errors.
- `! rg -n '^import CodexWatcher\.AppServerClient\b' test/TestSupport/Workflow.hs`: passed; the selected file no longer imports the facade.
- `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client \(AppServerTurn \(\.\.\)\)' test/TestSupport/Workflow.hs`: passed; direct owner import found at line 111.
- `git diff -- test/TestSupport/Workflow.hs`: confirmed import-only replacement of `CodexWatcher.AppServerClient` with `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
- Review-cited baselines remain accepted for this merge packet: `cabal test watcher-core-test` passed, `cabal build all` passed, selected helper/export anchor scan passed, and direct owner export evidence scan passed.

### Explicit Non-Goals
- No production code changes.
- No test body, helper body, fixture, test-suite wiring, or Cabal changes.
- No docs, policy, runtime compatibility file, public facade implementation, public facade exposure, or direct-owner export changes.
- No deprecation, public API removal, package exposure cleanup, release approval, milestone completion, or terminal roadmap completion claim.

### Follow-Up Notes
Remaining `CodexWatcher.AppServerClient` users and references are intentionally out of scope and should be handled only by later selected rounds: `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, `test/BoundaryPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/Main.hs`, and docs under `docs/agentic-workflow-framework/`.
