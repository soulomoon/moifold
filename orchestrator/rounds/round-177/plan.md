### Goal
Migrate only `src/CodexWatcher/EventLog/Replay.hs` off the `CodexWatcher.Core.Ids` compatibility facade for its existing `IssueNumber`, `ThreadId`, and `TurnId` uses, preserving replay behavior and all public compatibility surfaces.

### Approach
Make an import-only change in `CodexWatcher.EventLog.Replay`: replace `CodexWatcher.Core.Ids (IssueNumber (..), ThreadId (..), TurnId (..))` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))` and `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`.

Do not change exports, constructors, function bodies, replay initialization, event application, transition logic, replay failure text, event JSON shape, old-log parsing behavior, package exposure, Cabal files, docs, tests, roadmap files, runtime compatibility files, or the public `CodexWatcher.Core.Ids` facade. Keep `worker_mode` as `none`; this is a single-file sequential slice and does not justify worker fan-out or `worker-plan.json`.

### Steps
1. Edit `src/CodexWatcher/EventLog/Replay.hs` import declarations only.
2. Confirm the file no longer imports `CodexWatcher.Core.Ids`.
3. Confirm the file imports `IssueNumber (..)` from `CodexWatcher.Workflow.GitHub.Ids` and `ThreadId (..), TurnId (..)` from `CodexWatcher.Workflow.Agent.Ids`.
4. Review the selected-file diff and verify no non-import code changed.
5. Run the focused scans and baseline validation below.
6. In implementation notes, record remaining `CodexWatcher.Core.Ids` users from the repo-wide scan as blockers for later rounds, not as failures of this selected slice.

### Verification
- Selected-file scan:
  - `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/EventLog/Replay.hs`
  - `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids|CodexWatcher\\.Workflow\\.Agent\\.Ids" src/CodexWatcher/EventLog/Replay.hs`
- Diff scope check:
  - `git diff -- src/CodexWatcher/EventLog/Replay.hs`
  - Confirm only import declarations changed.
- Remaining-user scan:
  - `rg -n "CodexWatcher\\.Core\\.Ids" $(git ls-files 'src/**' 'app/**' 'test/**' 'docs/**' 'agent-workflow-*/**' '*.cabal' 'cabal.project*')`
  - Record remaining users without expanding this round.
- Focused replay compatibility:
  - `cabal test watcher-core-test --test-options='--match "workflow event-log"'`
  - If the test runner does not support that matcher, run `cabal test watcher-core-test` and record that the focused matcher was unavailable.
- Baseline checks:
  - `cabal build all`
  - `cabal test watcher-core-test`
  - `git diff --check`
