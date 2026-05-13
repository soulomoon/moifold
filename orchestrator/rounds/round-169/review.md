### Checks Run
- Command: `git diff -- src/CodexWatcher/DaemonLoop/Types.hs orchestrator/rounds/round-169/plan.md orchestrator/rounds/round-169/implementation-notes.md`
  Result: pass. The tracked diff for the requested paths is import-only in `src/CodexWatcher/DaemonLoop/Types.hs`: it removes `CodexWatcher.Core.Ids (CommitSha, PrNumber, ThreadId, TurnId (..))` and adds `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId (..))` plus `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)`. The round plan and implementation notes are untracked round artifacts, so they do not appear in this tracked diff command.
- Command: `rg -n "CodexWatcher\.Core\.Ids" src/CodexWatcher/DaemonLoop/Types.hs`
  Result: pass. Exit 1 with no matches, as expected.
- Command: `rg -n "CodexWatcher\.Workflow\.(GitHub|Agent)\.Ids" src/CodexWatcher/DaemonLoop/Types.hs`
  Result: pass. The selected file imports `CodexWatcher.Workflow.Agent.Ids` at line 35 and `CodexWatcher.Workflow.GitHub.Ids` at line 36.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. The suite completed with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported.
- Command: `rg -n "CodexWatcher\.Core\.Ids" src app test moifold.cabal`
  Result: pass. `src/CodexWatcher/DaemonLoop/Types.hs` is absent from the remaining-user scan. Remaining users include the still-exposed facade `moifold.cabal:46`, test imports, and out-of-scope production modules such as `RunnerGuard`, `Effects`, `StateMachine`, `Runtime/Compatibility`, `Healthcheck`, `Cli` modules, `EventLog` modules, and issue/PR workflow modules.
- Command: `rg -n "exposed-modules:|CodexWatcher\.Workflow\.Agent\.Ids|CodexWatcher\.Workflow\.GitHub\.Ids|CodexWatcher\.Core\.Ids" agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal moifold.cabal`
  Result: pass. Confirms `agent-workflow-codex` exposes `CodexWatcher.Workflow.Agent.Ids`, `agent-workflow-github` exposes `CodexWatcher.Workflow.GitHub.Ids`, and `moifold.cabal` still exposes `CodexWatcher.Core.Ids`.
- Command: `sed -n '1,120p' agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs`
  Result: pass. Confirms `CommitSha` and `PrNumber` are exported by `CodexWatcher.Workflow.GitHub.Ids`.
- Command: `sed -n '1,120p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs`
  Result: pass. Confirms `ThreadId` and `TurnId` are exported by `CodexWatcher.Workflow.Agent.Ids`.

### Plan Compliance
- Open `src/CodexWatcher/DaemonLoop/Types.hs` and locate the existing `CodexWatcher.Core.Ids` import: met. The diff shows the exact previous import was present and removed.
- Replace that import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` and `CodexWatcher.Workflow.Agent.Ids`: met. The selected file now imports GitHub-owned `CommitSha` and `PrNumber` from `CodexWatcher.Workflow.GitHub.Ids`, and agent-owned `ThreadId` and `TurnId (..)` from `CodexWatcher.Workflow.Agent.Ids`.
- Keep every declaration in `CodexWatcher.DaemonLoop.Types` unchanged: met. The production diff contains only import lines; no exports, type declarations, constructors, deriving clauses, helpers, or function bodies changed.
- Confirm the module export list stays unchanged and no `CodexWatcher.Core.Ids` import remains in the selected file: met. The diff does not touch the module header/export list, and the focused `rg` command found no selected-file `CodexWatcher.Core.Ids` matches.
- Do not edit other production modules, tests, package descriptors, documentation, roadmap files, state files, or compatibility facade modules for this round: met for implementation payload. The only production diff is `src/CodexWatcher/DaemonLoop/Types.hs`. The worktree also contains controller state metadata for active round review and untracked round artifacts; no package descriptor, docs, test, facade, or roadmap bundle source changes were part of the implementation.

### Decision
**APPROVED**

### Evidence
The integrated result is the intended import-only migration for `src/CodexWatcher/DaemonLoop/Types.hs`. It moves the selected daemon-loop type surface off the combined `CodexWatcher.Core.Ids` compatibility facade and onto the direct owner modules without changing behavior or public compatibility exposure.

The baseline gates from `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md` passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

The task-specific `Core.Ids` checks passed. The selected file has no remaining `CodexWatcher.Core.Ids` import, imports the two direct owner modules, and the owner packages expose those modules. The remaining `CodexWatcher.Core.Ids` users and `moifold.cabal` exposure are expected under this slice's boundaries and do not imply deprecation, Cabal exposure cleanup, facade removal, or broader migration approval.
