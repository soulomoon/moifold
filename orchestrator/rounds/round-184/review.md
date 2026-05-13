### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. `Test suite watcher-core-test: PASS`; 1 of 1 test suites passed. The run included PASS evidence for healthcheck worker `thread/read`, request id `9001`, missing endpoint/thread skips, JSON-RPC and decode failures, planner-state healthcheck reader boundary, runtime-state read/non-read contract, daemon/block/repair/runtime-owner/issue-snapshot source boundaries, and healthcheck repair-state/issue-snapshot non-reader contracts.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `! rg -n "import CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Healthcheck.hs`
  Result: pass. No selected-file `CodexWatcher.Core.Ids` import remains.
- Command: `rg -n "import CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Healthcheck.hs`
  Result: pass. Direct owner imports are present at `src/CodexWatcher/Healthcheck.hs:36` and `src/CodexWatcher/Healthcheck.hs:39`.
- Command: `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal`
  Result: pass for classification. Remaining import users are production `src/CodexWatcher/Domain/IssuePlanning/Loop.hs:29` and `src/CodexWatcher/Domain/IssueImplement/Loop.hs:38`; tests/test-support `test/FacadeImportPolicySpec.hs:11`, `test/WorkflowEventLogSpec.hs:65`, `test/RuntimeSpec.hs:30`, `test/CliSpec.hs:14`, `test/Main.hs:67`, `test/WorkflowAgentSpec.hs:66`, `test/RuntimeCompatibilityFixtureSpec.hs:11`, `test/WorkflowIndexedSpec.hs:66`, `test/TestSupport/Workflow.hs:98`, and `test/WorkflowExecutionSpec.hs:65`; no `app` users; no docs or Cabal import users in this import-only scan.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs *.cabal`
  Result: pass for broad surface classification. In addition to the import users above, docs mention the facade at `docs/agentic-workflow-framework/release-candidate-bundle.md:70`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:60`, `:86`, `:100`, and `docs/agentic-workflow-framework/release-notes.md:98`; Cabal exposure remains at `moifold.cabal:46`; the public facade remains `src/CodexWatcher/Core/Ids.hs:1`.
- Command: `rg -n "healthcheck.*(thread|read)|thread.*healthcheck|RequestId 9001|missing endpoint|JSON-RPC|decode|daemon|required|dirty workdir|summary.*kind|healthcheck parsing|HealthcheckSpec" test/HealthcheckSpec.hs test/Main.hs`
  Result: pass. Focused HealthcheckSpec evidence is discoverable for worker thread inspection, request id `9001`, missing endpoint/thread skips, JSON-RPC/decode failures, daemon-required and dirty-workdir warnings, read-only logic review, and suite wiring.
- Command: `rg -n "healthcheckPlannerReaderBoundaryTest|healthcheckRuntimeStateReadNonReadContractTest|daemonStateSourceBoundaryTest|blockStateSourceBoundaryTest|repairStateSourceBoundaryTest|runtimeOwnerSourceBoundaryTest|issueSnapshotSourceBoundaryTest|repair.*non-reader|reader boundary|non-read|RuntimeCompatibilityFixtureSpec" test/RuntimeCompatibilityFixtureSpec.hs test/Main.hs`
  Result: pass. The requested runtime compatibility fixture evidence is discoverable and wired through `runtimeCompatibilityFixtureTests`.
- Command: `rg -n "threadReadRequest|RequestId 9001|latestTurnId|stateFileSpecs|runtime owner|repair-state|planner-state|daemon-state|block-state|issue-snapshot|skipped" src/CodexWatcher/Healthcheck.hs`
  Result: pass. The current healthcheck source still shows `threadReadRequest (RequestId 9001)`, `latestTurnId`, `stateFileSpecs`, `planner-state.json`, `daemon-state.json`, `block-state.json`, skipped app-server paths, and no `repair-state.json` or `issue-snapshot.json` reader.

### Plan Compliance
- Confirm current target import: met. The source diff removes only the `CodexWatcher.Core.Ids` import in `src/CodexWatcher/Healthcheck.hs`.
- Replace with direct owner imports: met. `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..))` and `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), PrNumber (..), RepoName (..))` are imported directly.
- Do not touch healthcheck logic: met. `git diff -- src/CodexWatcher/Healthcheck.hs` is import-only; no JSON shape, summary path, reader set, command rendering, app-server thread check, runtime-state semantic, compatibility file name, repair behavior, public facade exposure, Cabal, docs, or behavior change is present.
- Classify remaining `Core.Ids` users: met. Remaining production users are the two domain loop files; tests/test-support, docs, Cabal exposure, and the public facade are separated above.

### Decision
**APPROVED**

### Evidence
The integrated source diff is scoped to `src/CodexWatcher/Healthcheck.hs` and changes only imports. `orchestrator/state.json` also has controller state changes for activating `round-184`; I did not modify or revert them.

Healthcheck behavior evidence is covered by the passing `watcher-core-test` run and focused source/test scans: app-server worker thread reads still use request id `9001`, missing endpoint/thread paths remain skipped, latest-turn extraction remains present, and healthcheck remains read-only.

Runtime compatibility evidence is covered by the passing fixture tests and source-boundary scans: `planner-state.json`, `daemon-state.json`, `block-state.json`, and `runtime-owner.json` reader/source boundaries remain in place; `repair-state.json` and `issue-snapshot.json` remain non-readers for healthcheck; repair and restart boundaries remain covered by `RuntimeCompatibilityFixtureSpec`.

No staged changes were made, so `git diff --cached --check` was not applicable.
