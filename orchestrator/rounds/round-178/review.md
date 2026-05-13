### Checks Run
- Command: `cabal build all`
  Result: pass. Output: `Up to date`.

- Command: `cabal test watcher-core-test`
  Result: pass. Built and ran `watcher-core-test`; final output: `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`

- Command: `dist-newstyle/build/aarch64-osx/ghc-9.12.2/moifold-0.1.0.0/t/watcher-core-test/build/watcher-core-test/watcher-core-test | rg "PASS (golden/(pr-review|issue-implement)|golden/(pr-review|issue-implement).*(bootstrap nonempty|bootstrap json roundtrip|bootstrap domain|bootstrap phase))"`
  Result: pass. Focused evidence included golden replay domain/phase/warning PASS labels for `golden/pr-review/mlf2-pr6-merged`, `golden/pr-review/mlf2-pr6-unresolved`, `golden/pr-review/mlf2-pr6-blocked`, `golden/pr-review/mlf2-pr6-clean-ready`, `golden/issue-implement/mlf2-issue42-plan-ready`, `golden/issue-implement/mlf2-issue42-incomplete`, and `golden/issue-implement/mlf2-issue42-blocked`; bootstrap nonempty/json-roundtrip/domain/phase labels also passed for the same fixtures. The command also printed `refusing to clear runtime lease because its pid is running: 61038` on stderr, but exited successfully with the selected PASS evidence.

- Command: `git diff --check`
  Result: pass. No whitespace errors reported.

- Command: `if git diff --cached --quiet; then printf 'No staged changes; skipped git diff --cached --check\n'; else git diff --cached --check; fi`
  Result: pass. Output: `No staged changes; skipped git diff --cached --check`.

- Command: `rg -n "CodexWatcher\.Core\.Ids" src/CodexWatcher/GoldenReplay.hs || true`
  Result: pass. No matches; `src/CodexWatcher/GoldenReplay.hs` no longer imports `CodexWatcher.Core.Ids`.

- Command: `rg -n "CodexWatcher\.Workflow\.Agent\.Ids \(ThreadId \(\.\.\), TurnId \(\.\.\)\)" src/CodexWatcher/GoldenReplay.hs`
  Result: pass. Output: `28:import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`.

- Command: `rg -n "CodexWatcher\.Workflow\.GitHub\.Ids \(BranchName \(\.\.\), CommitSha \(\.\.\), IssueNumber \(\.\.\), PrNumber \(\.\.\), RepoName \(\.\.\)\)" src/CodexWatcher/GoldenReplay.hs`
  Result: pass. Output: `29:import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..))`.

- Command: `rg -n "CodexWatcher\.Core\.Ids" src app test docs *.cabal agent-workflow-* -g '*.hs' -g '*.md' -g '*.cabal'`
  Result: pass. Remaining production users outside this round: `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `src/CodexWatcher/Cli/Types.hs`, `src/CodexWatcher/Cli/Parser/Common.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/Healthcheck.hs`, and `src/CodexWatcher/Domain/IssueImplement/Loop.hs`. Public facade retained: `src/CodexWatcher/Core/Ids.hs`. Test/fixture users remain in `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `test/Main.hs`, `test/WorkflowIndexedSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/WorkflowAgentSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, and `test/TestSupport/Workflow.hs`. Docs and Cabal references remain in `docs/agentic-workflow-framework/release-candidate-bundle.md`, `docs/agentic-workflow-framework/release-notes.md`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`, and `moifold.cabal`.

### Plan Compliance
- Confirm current dependency: met. The previous `src/CodexWatcher/GoldenReplay.hs` dependency on `CodexWatcher.Core.Ids` covered `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ThreadId`, and `TurnId`.
- Replace the compatibility-facade import with owner imports: met. The file now imports `ThreadId` and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`, and `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, and `RepoName` from `CodexWatcher.Workflow.GitHub.Ids`.
- Preserve constructor availability: met. Both owner imports use `(..)` for every migrated identifier.
- Preserve replay code and behavior surfaces: met. The zero-context diff for `src/CodexWatcher/GoldenReplay.hs` is import-only; no exports, function bodies, snapshot normalization, replay warnings, bootstrap events, old fixtures, package descriptors, or public facade exposure changed.
- Run baseline and focused verification: met. `cabal build all`, `cabal test watcher-core-test`, focused golden replay/bootstrap evidence, `git diff --check`, staged-diff check handling, selected-file scans, and broad remaining-user scan all passed.
- Avoid out-of-scope approvals: met. This review does not approve public facade removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, or terminal completion.

### Decision
**APPROVED**

### Evidence
The scoped production diff in `src/CodexWatcher/GoldenReplay.hs` removes only:

```haskell
import CodexWatcher.Core.Ids (...)
```

and adds only:

```haskell
import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))
import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..))
```

`agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs` owns and exports `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, and `RepoName`. `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs` owns and exports `ThreadId` and `TurnId`. The imported constructors remain available.

The broad scan confirms `GoldenReplay.hs` is removed from the production `Core.Ids` user set while other remaining production users, tests, docs, Cabal exposure, and `src/CodexWatcher/Core/Ids.hs` remain unchanged and outside this round.
