### Goal
Migrate only `src/CodexWatcher/DaemonLoop/Types.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing the ID types it already uses from their direct owner modules, while preserving the module's exported API, type definitions, constructors, deriving behavior, helper functions, and daemon-loop behavior.

### Approach
Keep this as a narrow one-file production import migration. Replace the single combined `CodexWatcher.Core.Ids` import with owner imports from `CodexWatcher.Workflow.GitHub.Ids` for GitHub-owned identifiers and `CodexWatcher.Workflow.Agent.Ids` for agent turn/thread identifiers. Do not change function bodies, exported names, package descriptors, public compatibility modules, tests, docs, roadmap state, or other remaining `Core.Ids` users.

This round follows the shared package-boundary and compatibility invariants in `orchestrator/project-contract.md`: preferred direct-owner imports are not deprecation, Cabal exposure removal, or compatibility facade removal approval.

### Steps
1. Open `src/CodexWatcher/DaemonLoop/Types.hs` and locate the existing import of `CodexWatcher.Core.Ids (CommitSha, PrNumber, ThreadId, TurnId (..))`.
2. Replace that import with:
   - `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)`
   - `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId (..))`
3. Keep every declaration in `CodexWatcher.DaemonLoop.Types` unchanged, including `DaemonLoopConfig`, `DaemonLoopFailure`, `DaemonLoopTickResult`, `StartTurnKind`, `ActiveTurnReadResult`, command-action report types, `DomainLoopOps`, and all helper functions.
4. Confirm the module export list stays unchanged and no `CodexWatcher.Core.Ids` import remains in `src/CodexWatcher/DaemonLoop/Types.hs`.
5. Do not edit other production modules, tests, package descriptors, documentation, roadmap files, state files, or compatibility facade modules for this round.

### Verification
Run focused and baseline checks after implementation:

1. `rg "CodexWatcher.Core.Ids" src/CodexWatcher/DaemonLoop/Types.hs` should return no matches.
2. `cabal build all`
3. `cabal test watcher-core-test`
4. `git diff --check`

If staging is performed later, also run `git diff --cached --check`.
