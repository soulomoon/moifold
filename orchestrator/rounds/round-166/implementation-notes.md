### Changes Made
- `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`: replaced the `CodexWatcher.Core.Ids (CommitSha (..), PrNumber, ThreadId)` compatibility facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids (ThreadId)` and `CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber)`.
- `orchestrator/rounds/round-166/implementation-notes.md`: recorded implementation and verification evidence for this round.

### Tests
- No tests were added or modified. This round is an import-owner migration only and does not change classifier behavior.
- `cabal build all`: PASS.
- `cabal test watcher-core-test`: PASS; 1 of 1 test suites passed.
- `git diff --check`: PASS.
- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`: PASS; no matches, as expected.
- `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids \\(ThreadId\\)" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`: PASS; found `16:import CodexWatcher.Workflow.Agent.Ids (ThreadId)`.
- `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(CommitSha \\(\\.\\.\\), PrNumber\\)" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`: PASS; found `18:import CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber)`.
- `rg -n "CodexWatcher\\.Core\\.Ids" src app test`: PASS; remaining users are outside this round's scope and include tests plus production modules such as `src/CodexWatcher/RunnerGuard.hs`, `src/CodexWatcher/GoldenReplay.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/EffectInterpreter.hs`, `src/CodexWatcher/Core/Ids.hs`, `src/CodexWatcher/Effects.hs`, `src/CodexWatcher/DaemonLoop/Types.hs`, `src/CodexWatcher/StateMachine.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/EventLog/Replay.hs`, `src/CodexWatcher/Cli/Parser/Common.hs`, `src/CodexWatcher/Cli/Types.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`, `src/CodexWatcher/Workflow/Moifold/PrReview.hs`, `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`, `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, and `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`.
- `rg -n "CodexWatcher\\.Core\\.Ids" moifold.cabal`: PASS; found `46:    CodexWatcher.Core.Ids`.
- `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids" agent-workflow-codex/agent-workflow-codex.cabal`: PASS; found `54:    CodexWatcher.Workflow.Agent.Ids`.
- `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids" agent-workflow-github/agent-workflow-github.cabal`: PASS; found `48:    CodexWatcher.Workflow.GitHub.Ids`.

### Notes
No declarations, function bodies, pattern matches, error text, tests, package descriptors, roadmap files, or controller state were changed. No files were staged.
