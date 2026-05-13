### Changes Made
- `src/CodexWatcher/GoldenReplay.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId`/`TurnId` and `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`/`CommitSha`/`IssueNumber`/`PrNumber`/`RepoName`. The diff is import-only; function bodies, exports, constructors, snapshot normalization, replay warnings, bootstrap events, old fixture behavior, package descriptors, and public facade exposure are unchanged.
- `orchestrator/rounds/round-178/implementation-notes.md`: recorded this implementation and verification evidence for review.

### Tests
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed; `1 of 1 test suites (1 of 1 test cases) passed`.
- Direct built-test executable output filtered for golden replay/bootstrap evidence: passed selected labels, including golden replay domain/phase/warning expectation for PR review and issue implement fixtures, plus bootstrap nonempty/json roundtrip/domain/phase parity for the same fixtures.
- `git diff --check`: passed.
- `git diff --cached --check`: skipped because no changes are staged.

### Notes
Focused import scans:
- `rg -n "CodexWatcher\.Core\.Ids" src/CodexWatcher/GoldenReplay.hs`: no matches.
- `rg -n "CodexWatcher\.Workflow\.Agent\.Ids \(ThreadId \(\.\.\), TurnId \(\.\.\)\)" src/CodexWatcher/GoldenReplay.hs`: line 28 shows the direct agent id import.
- `rg -n "CodexWatcher\.Workflow\.GitHub\.Ids \(BranchName \(\.\.\), CommitSha \(\.\.\), IssueNumber \(\.\.\), PrNumber \(\.\.\), RepoName \(\.\.\)\)" src/CodexWatcher/GoldenReplay.hs`: line 29 shows the direct GitHub id import.

Broad remaining-user scan:
- Production `src` users still outside this round: `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/Cli/Types.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/Cli/Parser/Common.hs`, and `src/CodexWatcher/Domain/IssueImplement/Loop.hs`.
- Public compatibility facade retained: `src/CodexWatcher/Core/Ids.hs`.
- Test/fixture users remain milestone-004 scope: `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `test/Main.hs`, `test/WorkflowIndexedSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/WorkflowAgentSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, and `test/TestSupport/Workflow.hs`.
- Docs and package descriptors intentionally unchanged: `docs/agentic-workflow-framework/release-notes.md`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`, `docs/agentic-workflow-framework/release-candidate-bundle.md`, and `moifold.cabal`.

Golden replay/snapshot-normalization evidence:
- Focused filtered output from the built watcher-core-test executable showed `PASS golden/pr-review/mlf2-pr6-*` and `PASS golden/issue-implement/mlf2-issue42-*` domain, phase, and warning expectation checks.
- The same focused output showed bootstrap checks for those fixtures: `bootstrap nonempty`, `bootstrap json roundtrip`, `bootstrap domain`, and `bootstrap phase`, covering parity between normalized snapshot replay and bootstrapped event replay.
