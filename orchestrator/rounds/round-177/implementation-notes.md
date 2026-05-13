### Changes Made
- `src/CodexWatcher/EventLog/Replay.hs`: verified the selected import-only migration is present. `IssueNumber (..)` now comes from `CodexWatcher.Workflow.GitHub.Ids`, and `ThreadId (..), TurnId (..)` now come from `CodexWatcher.Workflow.Agent.Ids`; the previous `CodexWatcher.Core.Ids` import is gone.

### Tests
- `src/CodexWatcher/EventLog/Replay.hs`: focused scan confirmed no `CodexWatcher.Core.Ids` import remains in the selected file.
- `src/CodexWatcher/EventLog/Replay.hs`: focused scan confirmed direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` and `CodexWatcher.Workflow.Agent.Ids`.
- Repository diff: `git diff --check` passed.
- Not run: `cabal build all`, `cabal test watcher-core-test`, or the focused replay matcher; full baseline validation is left to the reviewer.

### Notes
This round is import-only. It preserves all function bodies, exports, constructors, replay initialization, event application, transition logic, replay failure text, event JSON shape, old-log parsing behavior, package descriptors, and public compatibility facade exposure.

`CodexWatcher.Core.Ids` remains available and still has users outside this selected slice, including docs, Cabal exposure, production modules, and tests. Those remaining users are blockers for later rounds, not failures of round 177.
