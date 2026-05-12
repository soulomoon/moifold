### Checks Run
- Command: `rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowAgentSpec.hs`
  Result: pass. No matches; the selected file no longer imports the facade.

- Command: `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client \(AppServerTurn \(\.\.\)\)' test/WorkflowAgentSpec.hs`
  Result: pass. Direct owner import present at `test/WorkflowAgentSpec.hs:23`.

- Command: `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Client|AppServerTurn \(\.\.\)|data AppServerTurn' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`
  Result: pass. Direct owner module declaration, `AppServerTurn (..)` export, and `data AppServerTurn` definition are present.

- Command: `rg -n 'import CodexWatcher\.Workflow\.Agent\.Codex\.Client.*AppServerTurn' test/WorkflowAgentSpec.hs`
  Result: pass. Selected file imports `AppServerTurn` directly from the owner module at line 23.

- Command: `rg -n 'workflowAgentTests|workflowAgentRoleWrapsPrReviewWorkerClassifier|workflowPrReviewAgentRolesClassifyOutputs|workflowAgentObservationKernelMatchesPrReviewClassifiers|classifyPrReviewWorkerTurn|classifyPrReviewReviewerTurn|workflow Codex adapter parses thread read turn|AppServerTurn' test/WorkflowAgentSpec.hs`
  Result: pass. All selected behavioral anchors and `AppServerTurn` use sites remain present.

- Command: `rg -n 'CodexWatcher\.AppServerClient' src app test agent-workflow-codex moifold.cabal`
  Result: pass. Remaining matches are out of scope for this round: `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, `test/BoundaryPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/Main.hs`, `test/WorkflowIndexedSpec.hs`, `test/WorkflowExecutionSpec.hs`, and `test/TestSupport/Workflow.hs`.

- Command: `git diff -- test/WorkflowAgentSpec.hs`
  Result: pass. Diff is import-only, replacing `CodexWatcher.AppServerClient` with `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.

- Command: `git diff --name-only`
  Result: pass. Tracked diffs are only `orchestrator/state.json` and `test/WorkflowAgentSpec.hs`.

- Command: `git status --short`
  Result: pass. Status before review artifact writes showed `M orchestrator/state.json`, `M test/WorkflowAgentSpec.hs`, and untracked `orchestrator/rounds/round-146/` artifacts.

- Command: `find orchestrator/rounds/round-146 -maxdepth 1 -type f -print`
  Result: pass. Existing round artifacts before review artifact writes were `implementation-notes.md`, `selection.md`, and `plan.md`.

- Command: `cabal test watcher-core-test`
  Result: pass. `watcher-core-test` passed; 1 of 1 test suites passed.

- Command: `cabal build all`
  Result: pass. Build completed successfully; output was `Up to date`.

- Command: `git diff --check`
  Result: pass. No whitespace errors.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.

- Command: `git diff --cached --name-only`
  Result: pass. No staged files.

### Plan Compliance
- Scope reconfirmed before review: met. The live state names round 146 under roadmap `2026-05-11-00-highest-value-cleanup` / `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-010-appserverclient-import-convergence`, and item `round-146-workflow-agent-spec-appserverturn-direct-owner-migration`.
- Import-only selected-file migration: met. `test/WorkflowAgentSpec.hs` has a one-line import replacement and no body, helper, assertion, or string diff.
- Direct owner evidence: met. `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs` exports and defines `AppServerTurn`; the selected file imports that owner directly.
- Behavioral anchors preserved: met. The selected workflow agent role, worker/reviewer turn-classifier, observation-kernel, app-server turn-read assertion, `workflowAgentTests`, and `AppServerTurn` use sites are all still present.
- Remaining facade users recorded as out of scope: met. The broad scan still finds the public facade module, Cabal exposure, policy scanner entries, and other tests/support modules, all excluded by selection and plan.
- No out-of-scope implementation, package, docs, or public facade cleanup: met. Tracked diffs before review artifact writes were limited to orchestrator state and the selected test file; the selected test diff is import-only. No production file, package descriptor, docs file, or public facade implementation was modified.
- Project-contract non-goals preserved: met. This review does not claim public facade deprecation/removal, Cabal/API exposure cleanup, docs cleanup, package cleanup, milestone completion, release approval, terminal completion, or public compatibility removal.

### Decision
**APPROVED**

### Evidence
The integrated result satisfies the selected round: `test/WorkflowAgentSpec.hs` no longer imports `CodexWatcher.AppServerClient` and instead imports `AppServerTurn (..)` from `CodexWatcher.Workflow.Agent.Codex.Client`. The owner module exports and defines that type, the selected behavioral anchors remain present, and the selected file diff is import-only.

Required validation passed: selected-file import guard, direct owner import/export scan, behavioral anchor scan, broad remaining-user scan, selected-file diff inspection, changed-path inspection, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.

Approval is limited to this behavior-preserving import convergence slice. Remaining `CodexWatcher.AppServerClient` users and any public facade, Cabal exposure, docs, package, deprecation, removal, milestone, release, or terminal cleanup remain out of scope for later selected rounds.
