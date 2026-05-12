### Goal
Move only `test/WorkflowAgentSpec.hs` off the `CodexWatcher.AppServerClient` compatibility facade for `AppServerTurn (..)`, importing it from `CodexWatcher.Workflow.Agent.Codex.Client` while preserving the existing workflow agent role, worker/reviewer turn-classifier coverage, app-server turn-read assertions, `workflowAgentTests`, and all test bodies.

Roadmap lineage: `2026-05-11-00-highest-value-cleanup` / `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-010-appserverclient-import-convergence`, item `round-146-workflow-agent-spec-appserverturn-direct-owner-migration`.

### Approach
Make a single import-only edit in `test/WorkflowAgentSpec.hs`: replace the facade import `CodexWatcher.AppServerClient` with an explicit direct-owner import of `AppServerTurn (..)` from `CodexWatcher.Workflow.Agent.Codex.Client`.

Do not change production files, helper modules, test-suite wiring, package descriptors, docs/policy, `CodexWatcher.AppServerClient`, direct-owner module exports, public facade exposure, Cabal exposure, runtime compatibility files, deprecation/removal policy, milestone status, or any test body. The public facade remains available; remaining facade users are evidence for later rounds, not work for this round.

Worker fan-out is not justified. The edit is one import in one file with one implementer ownership boundary, so do not create `worker-plan.json`.

### Steps
1. Reconfirm scope before editing with `git status --short` and `sed -n '1,80p' test/WorkflowAgentSpec.hs`; preserve existing unrelated controller/selection artifacts and edit only `test/WorkflowAgentSpec.hs` for implementation.
2. In `test/WorkflowAgentSpec.hs`, remove `import CodexWatcher.AppServerClient` and add `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))` near the other app-server/workflow-agent imports, matching the direct-owner pattern already used by `test/WorkflowDocsMigrationSpec.hs`.
3. Do not reorder or rewrite unrelated imports except as needed for the new import line. Do not modify any declarations, assertions, helper functions, strings, expected values, or `workflowAgentTests`.
4. Re-scan the selected file to confirm it no longer imports the facade and that the direct-owner import is present:
   `! rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowAgentSpec.hs`
   `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client \(AppServerTurn \(\.\.\)\)' test/WorkflowAgentSpec.hs`
5. Re-scan the selected behavioral anchors and leave them unchanged: `workflowAgentTests`, `workflowAgentRoleWrapsPrReviewWorkerClassifier`, `workflowPrReviewAgentRolesClassifyOutputs`, `workflowAgentObservationKernelMatchesPrReviewClassifiers`, `classifyPrReviewWorkerTurn`, `classifyPrReviewReviewerTurn`, the assertion text `workflow Codex adapter parses thread read turn`, and all `AppServerTurn` uses.
6. Run a direct-owner evidence scan showing `AppServerTurn` is exported by `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs` and imported directly by the selected file:
   `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Client|AppServerTurn \(\.\.\)|data AppServerTurn' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`
   `rg -n 'import CodexWatcher\.Workflow\.Agent\.Codex\.Client.*AppServerTurn' test/WorkflowAgentSpec.hs`
7. Run a broad `CodexWatcher.AppServerClient` scan over `src`, `app`, `test`, `agent-workflow-codex`, and `moifold.cabal`. Record remaining matches as out of scope, including the facade module/exposure and other tests or policy scanners, without changing them:
   `rg -n 'CodexWatcher\.AppServerClient' src app test agent-workflow-codex moifold.cabal`
8. Inspect the implementation diff with `git diff -- test/WorkflowAgentSpec.hs` and confirm it is import-only. Then run `git diff --name-only` and confirm no implementation path other than `test/WorkflowAgentSpec.hs` changed for this round.

### Verification
Required checks:

1. Focused selected-file import guard:
   `! rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowAgentSpec.hs`
   `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client \(AppServerTurn \(\.\.\)\)' test/WorkflowAgentSpec.hs`
2. Direct owner import/export scan:
   `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Client|AppServerTurn \(\.\.\)|data AppServerTurn' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`
   `rg -n 'import CodexWatcher\.Workflow\.Agent\.Codex\.Client.*AppServerTurn' test/WorkflowAgentSpec.hs`
3. Selected-file behavioral anchor scan:
   `rg -n 'workflowAgentTests|workflowAgentRoleWrapsPrReviewWorkerClassifier|workflowPrReviewAgentRolesClassifyOutputs|workflowAgentObservationKernelMatchesPrReviewClassifiers|classifyPrReviewWorkerTurn|classifyPrReviewReviewerTurn|workflow Codex adapter parses thread read turn|AppServerTurn' test/WorkflowAgentSpec.hs`
4. Broad AppServerClient scan, with remaining users documented as out of scope:
   `rg -n 'CodexWatcher\.AppServerClient' src app test agent-workflow-codex moifold.cabal`
5. Diff checks:
   `git diff -- test/WorkflowAgentSpec.hs`
   `git diff --name-only`
6. Baseline behavior and build checks:
   `cabal test watcher-core-test`
   `cabal build all`
7. Whitespace/staging checks:
   `git diff --check`
   `git diff --cached --check`

Optional, if practical, a focused REPL load of `test/WorkflowAgentSpec.hs` through the `watcher-core-test` component may be used as additional evidence, but it must not replace `cabal test watcher-core-test`.
