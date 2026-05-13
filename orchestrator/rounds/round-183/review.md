### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. `watcher-core-test` ran successfully and reported `Test suite watcher-core-test: PASS`; 1 of 1 test suites passed.
- Command: `git diff --check`
  Result: pass. No whitespace or diff errors reported.
- Command: `rg -n "import CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Runtime/Compatibility.hs`
  Result: pass. No matches; the selected file no longer imports `CodexWatcher.Core.Ids`.
- Command: `rg -n "import CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Runtime/Compatibility.hs`
  Result: pass. Found direct owner imports at lines 31 and 32 for `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.
- Command: `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal agent-workflow-* 2>/dev/null`
  Result: pass. Remaining production users: `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, and `src/CodexWatcher/Domain/IssueImplement/Loop.hs`. Remaining test/test-support users: `test/RuntimeSpec.hs`, `test/FacadeImportPolicySpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/CliSpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`, `test/Main.hs`, `test/WorkflowAgentSpec.hs`, `test/TestSupport/Workflow.hs`, and `test/RuntimeCompatibilityFixtureSpec.hs`. Docs, Cabal/package descriptors, standalone package candidates, and `app` had no `Core.Ids` import matches. The public facade module `src/CodexWatcher/Core/Ids.hs` remains present and exposed by the codebase; it is not an import user.
- Command: `git diff -- src/CodexWatcher/Runtime/Compatibility.hs`
  Result: pass. Diff is import-only: removed the `CodexWatcher.Core.Ids` import and added direct imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.

### Plan Compliance
- Confirm pre-change facade import and facade ownership: met. `src/CodexWatcher/Core/Ids.hs` re-exports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`; the selected file was using the combined facade for those id constructors.
- Edit only selected production import surface: met for implementation. The source diff in `src/CodexWatcher/Runtime/Compatibility.hs` is limited to imports.
- Preserve runtime compatibility behavior: met. No changes to `CompatibilityWrite`, `writeCompatibility`, `compatibilityStateWrites`, JSON constructors, file names, summary paths, write timing, repair behavior, healthcheck behavior, runtime state semantics, event schemas, replay, public facade exposure, Cabal, docs, tests, or fixtures.
- Focused runtime compatibility evidence: met. The passing `watcher-core-test` run includes `RuntimeCompatibilityFixtureSpec`, `RuntimeSpec`, and `HealthcheckSpec` coverage as wired in `test/Main.hs`. Discoverable fixture evidence covers current `planner-state.json` / `planning-state.json` split, `daemon-state.json`, `block-state.json`, `repair-state.json`, `runtime-owner.json`, and `issue-snapshot.json` shapes; compatibility write separation and ordering; repair rewrite boundaries; healthcheck reader/non-reader contracts; summary paths; and runtime state behavior.
- Selected-file scans: met. `Runtime/Compatibility.hs` has no `Core.Ids` import and has both direct owner imports.
- Broad remaining-user scan: met. Remaining production `Core.Ids` import users are `Healthcheck.hs`, `IssuePlanning/Loop.hs`, and `IssueImplement/Loop.hs`; remaining test/test-support users are listed above; no docs, Cabal/package descriptor, standalone package-candidate, or `app` import users were found.
- Scope boundaries: met. No compatibility file names, JSON shapes, write timing, repair behavior, healthcheck behavior, runtime state semantics, event schemas/replay, public facade exposure, Cabal/docs, or behavior changed. No staging was performed, so `git diff --cached --check` was not applicable.

### Decision
**APPROVED**

### Evidence
The integrated source diff is exactly the selected import migration for `src/CodexWatcher/Runtime/Compatibility.hs`: `CodexWatcher.Core.Ids` was replaced by owner imports from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId` and `TurnId`, and `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`.

Baseline verification passed at the reviewed head. The focused runtime compatibility evidence is present in the passing `watcher-core-test` run, including runtime compatibility fixture checks and healthcheck reader/non-reader checks. The remaining production `Core.Ids` users are outside this round's selected file and are correctly left for later milestone-003 slices or classification.
