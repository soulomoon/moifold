### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. The suite rebuilt and ended with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged diff whitespace errors reported.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/EventLogRepair.hs`
  Result: pass. No matches; command exited 1 as expected for the removed facade import.
- Command: `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(IssueNumber \\(\\.\\.\\), PrNumber \\(\\.\\.\\)\\)" src/CodexWatcher/EventLogRepair.hs`
  Result: pass. Found `20:import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), PrNumber (..))`.
- Command: `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids \\(TurnId \\(\\.\\.\\)\\)" src/CodexWatcher/EventLogRepair.hs`
  Result: pass. Found `19:import CodexWatcher.Workflow.Agent.Ids (TurnId (..))`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test *.cabal`
  Result: pass. Remaining users were recorded and are outside this round, including `moifold.cabal`, tests, `EffectInterpreter`, daemon/runtime/CLI modules, domain loops, event-log modules, and `src/CodexWatcher/Core/Ids.hs`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" moifold.cabal`
  Result: pass. Found `46:    CodexWatcher.Core.Ids`, proving the public compatibility facade remains exposed.
- Command: `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids" agent-workflow-github/agent-workflow-github.cabal`
  Result: pass. Found `48:    CodexWatcher.Workflow.GitHub.Ids`, proving the GitHub owner module remains exposed.
- Command: `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids" agent-workflow-codex/agent-workflow-codex.cabal`
  Result: pass. Found `54:    CodexWatcher.Workflow.Agent.Ids`, proving the agent owner module remains exposed.
- Command: `git diff -- src/CodexWatcher/EventLogRepair.hs`
  Result: pass. The production diff removes only `import CodexWatcher.Core.Ids (IssueNumber (..), PrNumber (..), TurnId (..))` and adds direct owner imports for `TurnId`, `IssueNumber`, and `PrNumber`.
- Command: `git diff --stat -- src app test '*.cabal' orchestrator/roadmaps orchestrator/project-contract.md`
  Result: pass. Only `src/CodexWatcher/EventLogRepair.hs | 3 ++-` changed in production/package/roadmap-contract scope.

### Plan Compliance
- Step 1, confirm intended edit is only the ID import block in `src/CodexWatcher/EventLogRepair.hs`: met. The production diff is import-only in that file.
- Step 2, replace `CodexWatcher.Core.Ids` with direct owner imports: met. `TurnId` now comes from `CodexWatcher.Workflow.Agent.Ids`, and `IssueNumber`/`PrNumber` now come from `CodexWatcher.Workflow.GitHub.Ids`.
- Step 3, leave repair functions, deterministic helpers, inserted/dropped event construction, and `finishPlan` replay validation unchanged: met. `git diff -- src/CodexWatcher/EventLogRepair.hs` shows no function-body changes.
- Step 4, avoid behavior, error-message, export-list, package descriptor, test, docs, roadmap, or compatibility-surface changes: met for implementation scope. The only non-production tracked change is controller round state in `orchestrator/state.json`; round artifacts are untracked as expected. No package descriptors, tests, docs, roadmap files, fixtures, runtime compatibility files, public facades, or event schemas changed.
- Step 5, record implementation notes with validation and scans: met. `orchestrator/rounds/round-164/implementation-notes.md` records the changed file, command results, import scans, remaining facade users, and package exposure evidence.
- Alignment lineage: met. `selection.md`, `state.json`, and this review use roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, and extracted item `round-164-event-log-repair-core-ids-split-import-migration`.
- Compatibility boundaries: met. `CodexWatcher.Core.Ids` remains exposed in `moifold.cabal`; owner modules remain exposed; no deprecation, removal, Cabal exposure cleanup, event schema change, fixture change, runtime compatibility change, or public compatibility removal is present.

### Decision
**APPROVED**

### Evidence
The integrated round diff matches the selected extraction. `src/CodexWatcher/EventLogRepair.hs` changed only its import block:

```diff
-import CodexWatcher.Core.Ids (IssueNumber (..), PrNumber (..), TurnId (..))
+import CodexWatcher.Workflow.Agent.Ids (TurnId (..))
+import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), PrNumber (..))
```

Repair functions, error text, event construction, deterministic repair planning, and replay validation are unchanged by the diff. The full build and `watcher-core-test` passed, including the existing repair CLI and runtime compatibility coverage. Focused scans prove the selected file no longer imports `CodexWatcher.Core.Ids`, the direct owner imports are present, remaining `Core.Ids` users are outside this slice, and all relevant exposed-module entries remain available.
