### Checks Run
- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass; no whitespace errors reported.
- Command: `git diff --cached --check`
  Result: not run; reviewer did not stage anything.
- Command: `git diff -U0 -- src/CodexWatcher/EventLog/Types.hs`
  Result: pass; source diff is limited to removing the `CodexWatcher.Core.Ids` import block and adding direct imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.
- Command: `rg -n "import CodexWatcher\\.Core\\.Ids" src/CodexWatcher/EventLog/Types.hs || true`
  Result: pass; no selected-file `CodexWatcher.Core.Ids` import remains.
- Command: `rg -n "import CodexWatcher\\.Workflow\\.Agent\\.Ids|import CodexWatcher\\.Workflow\\.GitHub\\.Ids|ThreadId|TurnId|BranchName|CommitSha|IssueNumber|PrNumber|RepoName|ReviewThreadId" src/CodexWatcher/EventLog/Types.hs`
  Result: pass; direct owner imports are present at lines 39-46 for `ThreadId`, `TurnId`, `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`.
- Command: `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal agent-workflow-* -g '*.hs' -g '*.md' -g '*.cabal' || true`
  Result: pass; remaining import matches are separated below.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" docs moifold.cabal agent-workflow-* src/CodexWatcher/Core/Ids.hs -g '*.hs' -g '*.md' -g '*.cabal' || true`
  Result: pass; public facade, Cabal exposure, and docs references remain unchanged.
- Command: `rg -n "workflowEventLogTests|workflowEventCodecContractCoversWatcherEvents|workflowEventCodecToleratesMetadataAndPreservesGoldenTypes|workflowEventLogFileWrapperDecodesExistingFixtures|workflowEventLogCoreDetailedReplayMatchesMoifold|workflowEventLogCoreFixtureContractValidatesReplay|workflowEventLogCoreTransitionContractsUseDirectReplay|watcherEventSchemaVersion|schema version|metadata" test/Main.hs test/WorkflowEventLogSpec.hs src/CodexWatcher/EventLog/Types.hs`
  Result: pass; `test/Main.hs` runs `workflowEventLogTests`, and `WorkflowEventLogSpec` contains the focused codec, metadata, fixture decode, replay parity, fixture contract, and transition/replay tests named in the plan.

### Plan Compliance
- Confirm selected target import migration: met. `src/CodexWatcher/EventLog/Types.hs` no longer imports `CodexWatcher.Core.Ids`; it imports `ThreadId` and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`, and `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId` from `CodexWatcher.Workflow.GitHub.Ids`.
- Preserve event-log behavior and compatibility surfaces: met. The source diff is import-only. No watcher event constructors, JSON `type` labels, schema version, metadata labels, codec field names, old fixtures, replay logic, runtime compatibility files, healthcheck behavior, domain loops, public facade exposure, Cabal files, docs, or behavior code changed.
- Baseline verification: met. `cabal build all`, `cabal test watcher-core-test`, and `git diff --check` passed.
- Focused event-log compatibility evidence: met. `watcher-core-test` passed and includes `WorkflowEventLogSpec.workflowEventLogTests`, covering event codec contract/type stability, schema version `1`, metadata tolerance, existing fixture decoding, detailed replay parity, fixture replay contract, and transition/replay compatibility.
- Broad remaining `Core.Ids` import classification: met.
  Production users: `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`.
  Tests/test-support users: `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `test/Main.hs`, `test/WorkflowAgentSpec.hs`, `test/WorkflowIndexedSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/TestSupport/Workflow.hs`.
  Docs: no import matches; text references remain in `docs/agentic-workflow-framework/release-candidate-bundle.md`, `docs/agentic-workflow-framework/release-notes.md`, and `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
  Cabal/package descriptors: no import matches; `moifold.cabal` still exposes `CodexWatcher.Core.Ids`.
  Public facade: `src/CodexWatcher/Core/Ids.hs` remains available.

### Decision
**APPROVED**

### Evidence
Round lineage: `roadmap_id=2026-05-11-00-highest-value-cleanup`, `roadmap_revision=rev-002`, `roadmap_dir=orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`, `milestone_id=milestone-003-core-ids-production-import-burndown`, `direction_id=direction-011a-core-ids-eventlog-types-production-import`, `extracted_item_id=round-182-eventlog-types-core-ids-split-import-migration`.

The implementation source diff is scoped exactly to the selected file's import ownership split. It does not imply public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone completion, or terminal completion.
