### Checks Run
- Command: `cabal test watcher-core-test`
  Result: pass. The suite built and passed. Relevant passing output included the new lifecycle checks for launch manifests/dry-run command shape, launch write ordering, repair CLI dry-run/execute ordering, runtime status issue-close gating, healthcheck IssueImplement lifecycle reporting, and workflow lifecycle package-boundary scans.

- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

- Command: `git diff --check`
  Result: pass. No whitespace errors reported.

- Command: `git diff --cached --check`
  Result: pass. No staged diff and no whitespace errors reported.

- Command: `rg -n "ChildDaemon|WatcherRuntimeStatus|Healthcheck|EventLogRepair|IssueFanout|IssuePlanningFanout|runtime-owner|issue-watcher\\.pid|\\.lock|IssueConfig|WatcherEvent|SomeWatcherState" agent-workflow-core/src`
  Result: pass. No matches, so `agent-workflow-core` does not contain the IssueImplement lifecycle ownership tokens from the verification contract.

- Command: `rg -n "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed|projectIssueImplement|IssueImplementIndexedSpec" src/CodexWatcher/Domain/IssueImplement src/CodexWatcher/DaemonLoop src/CodexWatcher/AutomaticLoop`
  Result: pass. No matches, so the checked lifecycle/loop paths do not route live IssueImplement observations through the indexed daemon projector.

- Command: `rg -n "reexported-modules|CodexWatcher.Workflow.Agent|CodexWatcher.Workflow.GitHub" moifold.cabal`
  Result: pass. Matches are in the `agent-workflow-codex` and `agent-workflow-github` sublibrary exposed-module sections, not in main-library reexports.

- Command: `rg -n "CodexWatcher\\.Workflow\\.Moifold\\.IssueImplement\\.Indexed|projectIssueImplement|IssueImplementIndexedSpec" src`
  Result: pass. Matches are limited to `src/CodexWatcher/Daemon.hs` and `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`, preserving daemon-only live routing.

- Command: `rg -n "CodexWatcher\\.Workflow\\.|agent-workflow-core|IssueImplementIndexedSpec|projectIssueImplement|IssueImplement\\.Indexed" src/CodexWatcher/Cli/Command/IssueFanout.hs src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs src/CodexWatcher/WatcherRuntimeStatus.hs src/CodexWatcher/Healthcheck.hs src/CodexWatcher/Healthcheck/Analysis.hs src/CodexWatcher/Healthcheck/Types.hs src/CodexWatcher/EventLogRepair.hs src/CodexWatcher/Cli/Command/Replay.hs`
  Result: pass. No IssueImplement indexed router usage in the lifecycle hardening paths; existing non-IssueImplement workflow imports are `IssuePlanning.Indexed`, `Workflow.Spec`, and GitHub remote parsing.

- Command: `git diff --name-only -- golden`
  Result: pass. No golden fixture changes.

- Command: `git diff --name-only -- src/CodexWatcher/EventLog src/CodexWatcher/EventLog.hs src/CodexWatcher/GoldenReplay.hs golden`
  Result: pass. No event codec, golden replay, or golden fixture changes.

### Plan Compliance
- Step 1, source-scan guards: met. `test/Main.hs` adds `workflowIssueImplementLifecycleBoundarySourceScans`, and the explicit scans above passed. `agent-workflow-core` has no lifecycle ownership tokens, IssueImplement indexed routing is isolated to `Daemon.hs`, and main-library adapter reexports are not present.
- Step 2, child launch planning and manifests: met. `test/Main.hs` adds `issueImplementerLaunchLifecycleManifestsAndDryRunCommand`, covering pending/finalized manifest fields, `IssueImplementInitialized`, compatibility facade paths, and dry-run child command arguments. `src/CodexWatcher/Cli/Command/IssueFanout.hs` only exports the pure helpers needed by the tests.
- Step 3, runtime status and child start behavior: met. `runtimeStatusIssueImplementTerminalRequiresIssueCloseVerifier` covers missing watcher and `IssueComplete` gating through the remote close verifier, and `issueImplementerLaunchSourcePreservesWriteOrdering` checks `startIssueImplementerChildDetailed` classifies terminal complete before ready, running, and problem statuses as planned.
- Step 4, issue-planning fanout lifecycle decisions: met by existing focused coverage retained in the suite for running-only active discovery, explicit active issue override, stopped restart/missing launch reconciliation, terminal ready issue non-recreation, and ready-issues-fixed append-before-compatibility ordering. The round did not change `IssuePlanningFanout.hs`.
- Step 5, healthcheck IssueImplement lifecycle reporting: met. `prop_healthcheckIssueImplementLifecycleReporting` covers terminal complete daemon requirements, stopped non-terminal warnings, duplicate active implementer detection, dirty stopped workdir warning, active implementer summary count, and read-only logic-review text. Source scan confirms healthcheck surfaces `issue-state.json`, `daemon-state.json`, `block-state.json`, and `runtime-owner.json` without mutation.
- Step 6, deterministic repair coverage: met. Existing repair tests cover stale `IssuePlanningReadyIssuesFixed`, missing-plan-before-PR, completion-without-implementation-turn, and valid-log rejection; the new CLI source-order test covers dry-run reporting and execute archive/rewrite/compatibility/block-state ordering.
- Step 7, dead compatibility-only routing removal: met. No compatibility routing code was removed; event schemas, golden logs, daemon result constructors, dry-run rendering, runtime command rendering, compatibility writes, and lifecycle behavior were not changed.
- Step 8, focused test names: met. The round adds named checks for child launch lifecycle/manifests, runtime terminal success gating, healthcheck lifecycle reporting, repair behavior, and workflow package-boundary lifecycle scans. The suite does not expose a narrower test-runner matcher, so the focused checks were validated through `cabal test watcher-core-test`.

### Decision
**APPROVED**

### Evidence
The integrated diff is limited to exporting two pure IssueFanout helpers and adding focused tests in `test/Main.hs` and `test/HealthcheckSpec.hs`. The full watcher-core suite and full build pass. Required source scans preserve package boundaries and confirm no lifecycle ownership leaked into `agent-workflow-core`. Additional scans show live IssueImplement indexed routing remains isolated to `src/CodexWatcher/Daemon.hs`, with no event codec or golden fixture changes.
