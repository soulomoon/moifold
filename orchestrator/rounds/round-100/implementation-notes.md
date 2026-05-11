### Changes Made
- `src/CodexWatcher/Core/State.hs`: replaced the combined `CodexWatcher.Core.Ids` compatibility-facade import with `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)` so the file imports only the GitHub id types it uses from the direct owner module.
- `orchestrator/rounds/round-100/implementation-notes.md`: recorded the scoped implementation and verification results for round-100.

### Tests
- No test files were edited; this round is import convergence only.
- Pre-edit Core.State scan: `src/CodexWatcher/Core/State.hs` imported `CodexWatcher.Core.Ids` and matched only `CommitSha` and `PrNumber` id tokens from the selected scan.
- Package exposure scan: `agent-workflow-github/agent-workflow-github.cabal` exposes `CodexWatcher.Workflow.GitHub.Ids`; `moifold.cabal` still exposes `CodexWatcher.Core.Ids` and `CodexWatcher.Core.State`.
- Post-edit Core.State scan: `src/CodexWatcher/Core/State.hs` has one direct `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)` import and no remaining `CodexWatcher.Core.Ids` import.
- Selected facade import scan over `src`, `app`, `test`, `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`: `src/CodexWatcher/Core/State.hs` is no longer a `CodexWatcher.Core.Ids` importer; remaining `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission` users are outside this round and intentionally unchanged.
- Package descriptor diff check: empty for `moifold.cabal`, `agent-workflow-core/agent-workflow-core.cabal`, `agent-workflow-codex/agent-workflow-codex.cabal`, `agent-workflow-github/agent-workflow-github.cabal`, and `cabal.project`.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed with an empty index; no files were staged.

### Notes
`CompletionEvidence`, `WatcherState`, `SomeWatcherState`, constructors, exports, deriving behavior, package descriptors, and public compatibility facade exposure were preserved. `CodexWatcher.Core.Ids` remains exposed and available. This round makes no deprecation, removal, migration, release, milestone-completion, or terminal-completion claim.
