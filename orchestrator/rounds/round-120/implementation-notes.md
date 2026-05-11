### Changes Made
- `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`: replaced the unqualified `CodexWatcher.AppServerClient` facade import with `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)` for the existing `planningSystemErrorObservation` type signature. No non-import lines or behavior were changed.

### Tests
- `watcher-core-test` focused REPL gate: ran the three issue-planning turn-classifier properties and the two planning systemError retry/blocking examples named in the plan.
- `watcher-core-test`: ran the full test suite.
- `cabal build all`: ran the full build baseline.
- Import and diff guards: ran whitespace checks, target import scans, forbidden-surface diff guards, import-only diff inspection, no-worker-plan check, and implement-stage state lineage checks.

### Notes
The qualified `CodexWatcher.Workflow.Agent.Codex` import was left unchanged. The controller-owned `orchestrator/state.json` and planner-owned round selection/plan artifacts were already present in the worktree; this implementation changed only the target import and this notes file.
