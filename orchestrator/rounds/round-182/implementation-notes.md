### Changes Made
- `src/CodexWatcher/EventLog/Types.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId`/`TurnId` and `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`/`CommitSha`/`IssueNumber`/`PrNumber`/`RepoName`/`ReviewThreadId`.

### Tests
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed; `test/Main.hs` imports and runs `WorkflowEventLogSpec.workflowEventLogTests`, and `test/WorkflowEventLogSpec.hs` includes `workflowEventCodecContractCoversWatcherEvents`, `workflowEventCodecToleratesMetadataAndPreservesGoldenTypes`, `workflowEventLogFileWrapperDecodesExistingFixtures`, `workflowEventLogCoreDetailedReplayMatchesMoifold`, `workflowEventLogCoreFixtureContractValidatesReplay`, and `workflowEventLogCoreTransitionContractsUseDirectReplay`.
- `git diff --check`: passed with no output.
- Selected-file no-`Core.Ids` import scan: `rg -n "import CodexWatcher\\.Core\\.Ids" src/CodexWatcher/EventLog/Types.hs` returned no matches.
- Selected-file direct-owner import scan: `rg -n "import CodexWatcher\\.Workflow\\.Agent\\.Ids|import CodexWatcher\\.Workflow\\.GitHub\\.Ids|ThreadId|TurnId|BranchName|CommitSha|IssueNumber|PrNumber|RepoName|ReviewThreadId" src/CodexWatcher/EventLog/Types.hs` showed `import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))` at line 39 and `import CodexWatcher.Workflow.GitHub.Ids` with `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId` at lines 40-46.
- Broad remaining `Core.Ids` import scan: `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal agent-workflow-* -g '*.hs' -g '*.md' -g '*.cabal'` returned the following remaining imports:
  - Production users: `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`.
  - Tests/test-support users: `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `test/Main.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, `test/WorkflowAgentSpec.hs`, `test/WorkflowIndexedSpec.hs`, `test/TestSupport/Workflow.hs`, `test/WorkflowExecutionSpec.hs`.
  - Docs: no `import CodexWatcher.Core.Ids` matches in the import scan; text references remain in `docs/agentic-workflow-framework/release-notes.md`, `docs/agentic-workflow-framework/release-candidate-bundle.md`, and `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
  - Cabal/package descriptors: no `import CodexWatcher.Core.Ids` matches in the import scan; `moifold.cabal` still exposes `CodexWatcher.Core.Ids`.
  - Public facade: `src/CodexWatcher/Core/Ids.hs` remains the public compatibility facade reexporting `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.

### Notes
The implementation stayed import-only. No event constructors, JSON `type` labels, schema version, metadata labels, codec field names, replay logic, fixtures, tests, Cabal files, docs, runtime compatibility files, healthcheck code, domain loops, public facade, roadmap files, `selection.md`, `plan.md`, or `state.json` were edited.
