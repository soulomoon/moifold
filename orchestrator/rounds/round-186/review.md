### Checks Run
- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; final output reported `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass; no whitespace errors reported.
- Command: `git diff --cached --name-status`
  Result: pass; no staged files, so `git diff --cached --check` was not required by `verification.md`/`plan.md`.
- Command: `git diff -- src/CodexWatcher/Domain/IssueImplement/Loop.hs`
  Result: pass; diff is import-only: one `CodexWatcher.Core.Ids` import removed and two direct owner imports added.
- Command: `git diff -- src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  Result: pass; no output, so the round-185 planning loop file was not edited.
- Command: `git diff --name-status -- test docs moifold.cabal app src/CodexWatcher/Core/Ids.hs orchestrator/roadmaps src/CodexWatcher/Runtime`
  Result: pass; no tests, docs, Cabal file, app file, roadmap bundle file, runtime compatibility file, or public facade file changed.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/IssueImplement/Loop.hs`
  Result: pass; no matches.
- Command: `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/Domain/IssueImplement/Loop.hs`
  Result: pass; line 42 imports `RequestId` and `ThreadId (..)` from `CodexWatcher.Workflow.Agent.Ids`, and line 45 imports `BranchName (..)`, `CommitSha (..)`, `IssueNumber (..)`, and `PrNumber (..)` from `CodexWatcher.Workflow.GitHub.Ids`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal agent-workflow-*/*.cabal`
  Result: pass with classification. Production users: none except `src/CodexWatcher/Core/Ids.hs` itself. Public facade: `src/CodexWatcher/Core/Ids.hs:1`. Cabal/package exposure: `moifold.cabal:46`. Tests/fixtures: `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `test/Main.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, `test/WorkflowAgentSpec.hs`, `test/TestSupport/Workflow.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`. Docs: release candidate bundle, release notes, and compatibility deprecation policy references. App matches: none. Standalone package candidate matches: none.
- Command: `rg -n "prop_eventLogFullIssueImplementationPathCompletes|prop_eventLogRefreshesIdleIssueWorkerThread|prop_eventLogIssueIncompleteCanContinueToComplete|prop_issueImplementWatcherIncompleteRestartsImplementation|prop_issueImplementWatcherMergedStartsPostMergeReview|prop_issueImplementWatcherBlockedStops|prop_runtimeGhPrCreateKeepsStdoutJsonOnly|prop_runtimeGhPrBodyUpdateUsesPlanFile|prop_turnClassifierMapsDomainOutputs|prop_turnClassifierPrefersStructuredOutputs|prop_turnClassifierBlocksMissingOutputs|prop_effectInterpreterPrBodyUpdateUsesIssuePlan|prop_effectInterpreterIssueTurnsUsePhaseSpecificPrompts" test/Main.hs`
  Result: pass; named QuickCheck properties are defined and wired into the full `watcher-core-test` run at `test/Main.hs:622`, `683`, `800`, `849`, `881`, `955`, `2249`, `2262`, `2309`, `2416`, `2423`, and aggregate call sites `6851`, `6854`, `6863`, `6866`, `6869`, `6873`, `6940`, `6941`, `6980`, `6981`, `6982`, `6984`, `6985`.
- Command: `rg -n "workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPlanPrSetupAndImplementationWorkerProjections|workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPostMergeReviewProjections|workflowIssueImplementIndexedDaemon" test/WorkflowIndexedSpec.hs test/Main.hs`
  Result: pass; indexed issue-implementation daemon projection groups are wired at `test/WorkflowIndexedSpec.hs:237-241`, with definitions at `3183`, `3189`, `3195`, and `3201`.
- Command: `cabal test watcher-core-test 2>&1 | rg -n "Test suite watcher-core-test: PASS|body-updated PR|indexed workflow issue implement|issue follow-up|merged PR with existing reviewer|post-merge review|new PR body update|reused PR body update|missing plan fails PR body update|automatic implementation|turn classifier|runtime gh pr|implementation turn start|worker thread|reviewer thread|commits event and compatibility writes|failure text|JSON-RPC failure|decode failure"`
  Result: pass; filtered output showed the required focused behavior evidence and ended with `Test suite watcher-core-test: PASS`.
- Command: `cabal test watcher-core-test 2>&1 | rg -n "Test suite watcher-core-test: PASS|indexed workflow issue implement daemon execute (pull request body update|implementation incomplete restart|post-merge clean final review closes issue|issue close completes) commits event and compatibility writes"`
  Result: pass; event append / compatibility write ordering lines appeared at filtered output lines 1328, 1346, 1652, and 1688, followed by `Test suite watcher-core-test: PASS`.

### Plan Compliance
- Confirm working scope before editing: met by review. The source diff is limited to `src/CodexWatcher/Domain/IssueImplement/Loop.hs`; orchestrator state/round artifacts are controller metadata, and no unrelated source/test/docs/Cabal/runtime/public facade files changed.
- Replace only the `CodexWatcher.Core.Ids` import: met. The target file now imports agent ids and GitHub ids from direct owner modules at lines 42 and 45.
- Keep every use site unchanged: met. The diff contains no non-import source changes, and `cabal build all` passed.
- Verify import-only diff: met. `git diff -- src/CodexWatcher/Domain/IssueImplement/Loop.hs` shows 2 insertions and 1 deletion in the import block only.
- Classify compile/export/package blockers if present: not needed. Direct owner imports compiled without Cabal or public surface changes.
- Verify focused issue-implementation loop behavior evidence: met. Full `watcher-core-test` passed, named properties are wired, and filtered PASS lines cover request-id progression, worker/reviewer thread handling, repo/issue/PR and command rendering, event append order, daemon transition behavior, app-server turn classification, command rendering, and failure text.
- Leave `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` untouched: met. `git diff -- src/CodexWatcher/Domain/IssuePlanning/Loop.hs` had no output.
- Roadmap and boundary compliance: met. This review does not approve public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.

### Decision
**APPROVED**

### Evidence
The integrated source change is exactly the selected import migration: `src/CodexWatcher/Domain/IssueImplement/Loop.hs` no longer imports `CodexWatcher.Core.Ids`, and it directly imports `RequestId`/`ThreadId` from `CodexWatcher.Workflow.Agent.Ids` plus `BranchName`/`CommitSha`/`IssueNumber`/`PrNumber` from `CodexWatcher.Workflow.GitHub.Ids`.

The broad `Core.Ids` scan leaves no remaining production users beyond the public compatibility facade module itself. Remaining matches are correctly outside this milestone slice: Cabal exposure, test/fixture imports, and docs/policy references.

Focused behavior evidence came from the full passing `watcher-core-test` target and the wired issue-implementation properties/projection groups. PASS lines covered implementation completion ordering, body-update command/event ordering, request-id advancement, implementation turn request-id compatibility, worker refresh/replacement, reviewer-thread behavior, automatic incomplete/missing-output/complete-without-PR classification, indexed daemon dry-run/execute request ids, and execute-mode event-before-compatibility-write behavior.

No tests, docs, Cabal files, roadmap bundle files, runtime compatibility files, public facade files, or `IssuePlanning/Loop.hs` changed. The round stays within `milestone-003-core-ids-production-import-burndown` and `direction-011e-core-ids-domain-loop-production-imports`.
