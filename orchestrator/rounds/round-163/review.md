### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. Cabal built and ran `watcher-core-test`; final output reported `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged diff and no whitespace errors reported.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/PrReview/Protocol.hs`
  Result: pass. No matches; command exited with status 1 as expected for an empty search result.
- Command: `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/Domain/PrReview/Protocol.hs`
  Result: pass. Output showed `33:import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)` and `34:import CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId)`.
- Command: `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github examples`
  Result: pass. Remaining facade users were reported in other files, including `src/CodexWatcher/EffectInterpreter.hs`, `src/CodexWatcher/RunnerGuard.hs`, `src/CodexWatcher/DaemonLoop/Types.hs`, `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/Domain/PrReview/Loop.hs`, issue-planning and issue-implementation modules, runtime/event-log modules, CLI modules, and tests; `src/CodexWatcher/Domain/PrReview/Protocol.hs` was not listed.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`
  Result: pass. Output showed `agent-workflow-github/agent-workflow-github.cabal:48:    CodexWatcher.Workflow.GitHub.Ids`, `agent-workflow-codex/agent-workflow-codex.cabal:54:    CodexWatcher.Workflow.Agent.Ids`, and `moifold.cabal:46:    CodexWatcher.Core.Ids`.
- Command: `git diff --stat && git diff -- src/CodexWatcher/Domain/PrReview/Protocol.hs && git diff -- orchestrator/state.json orchestrator/rounds/round-163/selection.md orchestrator/rounds/round-163/plan.md orchestrator/rounds/round-163/implementation-notes.md`
  Result: pass. Tracked source diff is limited to a three-line import-block change in `src/CodexWatcher/Domain/PrReview/Protocol.hs`; tracked controller diff is limited to activating round 163 in `orchestrator/state.json`.

### Plan Compliance
- Step 1, edit `src/CodexWatcher/Domain/PrReview/Protocol.hs` only for source: met. The only production source diff is `src/CodexWatcher/Domain/PrReview/Protocol.hs`.
- Step 2, replace the `CodexWatcher.Core.Ids` import with direct owner imports: met. The old import was removed, and the file now imports `ThreadId` and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`, plus `CommitSha` and `ReviewThreadId` from `CodexWatcher.Workflow.GitHub.Ids`.
- Step 3, preserve other imports except ordering-only cleanup: met. The diff shows only the removed facade import and the two new owner imports.
- Step 4, confirm the source diff is import-only: met. No data types, constructors, protocol runners, helper functions, or event construction changed.
- Step 5, do not change compatibility facades, runtime compatibility files, Cabal exposure, roadmap files, state files beyond controller state, or tests: met. No package descriptor, compatibility facade, runtime compatibility file, roadmap revision file, or test file changed. `orchestrator/state.json` only records the active round, and round-local artifacts were added under `orchestrator/rounds/round-163`.
- Step 6, record implementation notes with changed file, verification commands, focused import scans, and remaining `CodexWatcher.Core.Ids` users: met. `orchestrator/rounds/round-163/implementation-notes.md` contains the changed-file summary, verification summary, focused scans, remaining users, package exposure scan, and notes that no files were staged.
- Roadmap alignment, keep public compatibility facades exposed until an exact gate: met. `moifold.cabal` still exposes `CodexWatcher.Core.Ids`; the direct owner modules remain exposed in their package descriptors.
- Project-contract package-boundary invariant: met. The change moves one reusable import use to direct owner modules and does not move moifold lifecycle policy into reusable packages.

### Decision
**APPROVED**

### Evidence
The integrated diff matches the selected extraction. `src/CodexWatcher/Domain/PrReview/Protocol.hs` changed only this import block:

```diff
-import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId, ThreadId, TurnId)
+import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)
+import CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId)
```

`WorkerSession`, `ReviewerSession`, `WorkerOutcome`, `ReviewerOutcome`, turn-start/wait/emit helpers, `runPrReviewWorkerProtocol`, `runPrReviewReviewerProtocol`, `ReviewerClean`, `ReviewerProblemsAdded`, `PrReviewCleanFound`, and `PrReviewProblemsAdded` are unchanged by the diff. Baseline build/test checks passed, focused scans prove `Protocol.hs` no longer imports `CodexWatcher.Core.Ids`, remaining facade users are outside the selected file, and package exposure for `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.Agent.Ids`, and `CodexWatcher.Workflow.GitHub.Ids` remains intact.
