### Checks Run
- Command: `cabal build all`
  Result: pass; output was `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; Cabal built and ran `watcher-core-test`, then reported `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass; no whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass; no staged diff and no whitespace errors reported.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
  Result: pass; no matches, as expected.
- Command: `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids \\(ThreadId\\)" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
  Result: pass; found `16:import CodexWatcher.Workflow.Agent.Ids (ThreadId)`.
- Command: `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(CommitSha \\(\\.\\.\\), PrNumber\\)" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
  Result: pass; found `18:import CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber)`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test`
  Result: pass; remaining users are outside this round's scope, including tests and production modules such as `RunnerGuard`, `Runtime/Compatibility`, `GoldenReplay`, `EffectInterpreter`, `DaemonLoop/Types`, `StateMachine`, `Effects`, `Healthcheck`, `EventLog`, CLI modules, `IssueImplement/Watcher.hs`, `IssueImplement/Loop.hs`, `IssuePlanning/Loop.hs`, `IssuePlanning/Fanout.hs`, `PrReview/LaunchCli.hs`, and moifold workflow modules.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" moifold.cabal`
  Result: pass; found `46:    CodexWatcher.Core.Ids`, proving the compatibility facade remains exposed.
- Command: `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids" agent-workflow-codex/agent-workflow-codex.cabal`
  Result: pass; found `54:    CodexWatcher.Workflow.Agent.Ids`, proving the agent owner module remains exposed.
- Command: `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids" agent-workflow-github/agent-workflow-github.cabal`
  Result: pass; found `48:    CodexWatcher.Workflow.GitHub.Ids`, proving the GitHub owner module remains exposed.
- Command: `git diff --name-only`
  Result: pass; tracked diff contains only `orchestrator/state.json` and `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`.
- Command: `git diff --cached --name-only`
  Result: pass; no staged files.
- Command: `git diff --unified=0 -- src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
  Result: pass; the only production hunks add `CodexWatcher.Workflow.Agent.Ids (ThreadId)`, remove `CodexWatcher.Core.Ids (CommitSha (..), PrNumber, ThreadId)`, and add `CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber)`.
- Command: `test ! -e orchestrator/rounds/round-166/worker-plan.json && printf 'absent\n' || printf 'present\n'`
  Result: pass; output was `absent`.

### Plan Compliance
- Confirm the selected file's only `CodexWatcher.Core.Ids` dependency was the `CommitSha`, `PrNumber`, and `ThreadId` import: met; the production diff removes exactly that import and no other `TurnClassifier.hs` code.
- Replace the facade import with direct owner imports: met; `ThreadId` now comes from `CodexWatcher.Workflow.Agent.Ids`, and `CommitSha (..), PrNumber` now come from `CodexWatcher.Workflow.GitHub.Ids`.
- Leave all declarations and function bodies unchanged, including `classifyIssuePlanTurn`, `classifyIssueImplementationTurn`, `classifyIssueFinalReviewTurn`, structured-turn outcome handling, final-review commit validation, reviewer prompt-version validation, missing-output handling, malformed JSON handling, and error text: met; `git diff --unified=0 -- src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` shows import-only hunks.
- Do not create `orchestrator/rounds/round-166/worker-plan.json`: met; the file is absent.
- Keep scope away from tests, package descriptors, roadmap files, compatibility facades, public exposure, event schemas, fixtures, and runtime compatibility files: met; tracked diff names only `orchestrator/state.json` and `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`, and package exposure scans prove the facade and owner modules remain exposed.
- Preserve public compatibility surfaces and avoid treating import convergence as deprecation or removal approval: met; `CodexWatcher.Core.Ids` remains exposed in `moifold.cabal`, and the remaining `Core.Ids` users are recorded as out of scope.

### Decision
**APPROVED**

### Evidence
The integrated production change is an import-only migration in `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`:

```diff
+import CodexWatcher.Workflow.Agent.Ids (ThreadId)
-import CodexWatcher.Core.Ids (CommitSha (..), PrNumber, ThreadId)
+import CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber)
```

No function bodies, data types, pattern matches, structured-turn outcome handling, final-review commit validation, reviewer prompt-version validation, missing-output handling, malformed JSON handling, or error text changed. Baseline build/test/checks passed, the selected file no longer imports `CodexWatcher.Core.Ids`, the direct owner imports are present, and package exposure for `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.Agent.Ids`, and `CodexWatcher.Workflow.GitHub.Ids` remains intact.
