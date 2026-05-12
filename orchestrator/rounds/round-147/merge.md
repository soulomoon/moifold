### Squash Commit
- Title: Round 147: Move WorkflowIndexedSpec to the direct AppServerTurn owner
- Summary: Move `test/WorkflowIndexedSpec.hs` off the `CodexWatcher.AppServerClient` compatibility facade by importing `AppServerTurn (..)` from `CodexWatcher.Workflow.Agent.Codex.Client`. The selected test remains otherwise unchanged: no indexed PR-review assertions, helper signatures, fixtures, test bodies, production modules, package descriptors, docs, or public facade files were edited.

### Merge Readiness
- Base branch freshness: confirmed against the available local `codex/workflow-facade-extraction` ref. `codex/workflow-facade-extraction` and `HEAD` both resolve to `8521fa369c60`, and `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` passed. `origin` currently advertises no `codex/workflow-facade-extraction` head.
- Merge ordering satisfied: yes. `orchestrator/state.json` has `pending_merge_rounds: []`, `depends_on_round_ids: []`, `merge_after_item_ids: []`, and `parallel_group: null` for `round-147`.
- Pending dependencies: none.
- Review status: approved. `orchestrator/rounds/round-147/review.md` records `**APPROVED**`, and `orchestrator/rounds/round-147/review-record.json` records `"decision": "approved"`.
- Scheduler status: ready. `orchestrator/state.json` records `stage: "merge"`, `active_round_id: "round-147"`, and `merge_ready: true`.

### Expected Files
- `test/WorkflowIndexedSpec.hs`: selected import-only implementation change.
- `orchestrator/state.json`: controller state for active round 147 merge readiness.
- `orchestrator/rounds/round-147/selection.md`: selected extraction and scheduler fields.
- `orchestrator/rounds/round-147/plan.md`: import-only implementation and verification plan.
- `orchestrator/rounds/round-147/implementation-notes.md`: implementer evidence.
- `orchestrator/rounds/round-147/review.md`: reviewer approval and validation evidence.
- `orchestrator/rounds/round-147/review-record.json`: machine-readable approved review record.
- `orchestrator/rounds/round-147/merge.md`: this merge preparation note.

### Passed Checks
- Selected-file facade guard passed: no `import CodexWatcher.AppServerClient` remains in `test/WorkflowIndexedSpec.hs`.
- Direct-owner import guard passed: `test/WorkflowIndexedSpec.hs` imports `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
- Direct-owner export/facade scan passed: the direct owner exports `AppServerTurn (..)`, and `CodexWatcher.AppServerClient` remains a compatibility facade over the direct owner.
- Behavioral anchor scan passed: `workflowIndexedTests`, both classifier-backed outcome tests, both classifier helper definitions, `-> AppServerTurn` helper signatures, and existing `AppServerTurn` fixtures remain present.
- Broad facade scan passed: no remaining `CodexWatcher.AppServerClient` hit in `test/WorkflowIndexedSpec.hs`; remaining hits are documented out of scope.
- Diff scope passed: `test/WorkflowIndexedSpec.hs` is import-only; tracked diff before merge notes contained only `orchestrator/state.json` and `test/WorkflowIndexedSpec.hs`.
- Baseline checks passed in review: `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.
- Current whitespace checks passed after merge-note preparation: `git diff --check` and `git diff --cached --check`.

### Explicit Non-Goals
- No production code changes.
- No test body, assertion, fixture, or helper-signature changes.
- No package descriptor, Cabal exposure, or public API cleanup.
- No public facade deprecation, removal, hiding, or behavior change.
- No docs, policy, or package-boundary text cleanup.
- No edits to remaining `CodexWatcher.AppServerClient` importers outside `test/WorkflowIndexedSpec.hs`.
- No milestone completion, release approval, terminal completion, commit, squash merge, or branch merge.

### Follow-Up Notes
Remaining `CodexWatcher.AppServerClient` users are intentionally left for later selected rounds: `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, `test/BoundaryPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/Main.hs`, `test/WorkflowExecutionSpec.hs`, `test/TestSupport/Workflow.hs`, and docs under `docs/agentic-workflow-framework/`.
