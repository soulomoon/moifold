### Goal
Migrate only `src/CodexWatcher/EventLogRepair.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing the existing ID types from their owner modules, while preserving event-log repair behavior, replay validation, and public compatibility exposure.

### Approach
Keep this as a narrow import-convergence change. Replace the current `CodexWatcher.Core.Ids (IssueNumber (..), PrNumber (..), TurnId (..))` import in `src/CodexWatcher/EventLogRepair.hs` with:

- `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), PrNumber (..))`
- `CodexWatcher.Workflow.Agent.Ids (TurnId (..))`

Do not change repair functions, exported symbols, event constructors, inserted or dropped event construction, deterministic repair rule selection, replay validation, or error text. Do not change `CodexWatcher.Core.Ids`, package descriptors, tests, docs, roadmap status, or controller state. No worker fan-out is needed because the selected work has one production file and one import ownership boundary.

### Steps
1. Open `src/CodexWatcher/EventLogRepair.hs` and confirm the only intended edit is the ID import block near the top of the module.
2. Replace the `CodexWatcher.Core.Ids` import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `IssueNumber` and `PrNumber`, and `CodexWatcher.Workflow.Agent.Ids` for `TurnId`.
3. Leave `EventLogRepairPlan`, `repairFailureBlockStateJson`, `repairIssueImplementEventLog`, `repairFromFailure`, all deterministic repair helpers, inserted/dropped event construction, and `finishPlan` replay validation unchanged.
4. Inspect the resulting diff and confirm it contains no behavior, error-message, export-list, package descriptor, test, docs, roadmap, or orchestrator state changes.
5. Record implementation notes with the exact changed file, validation commands, import-scan output, remaining `Core.Ids` users, and package exposure evidence.

### Verification
Run the baseline checks from the active roadmap verification file:

```sh
cabal build all
cabal test watcher-core-test
git diff --check
```

If staging is involved, also run:

```sh
git diff --cached --check
```

Run focused import scans proving the selected migration happened:

```sh
rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/EventLogRepair.hs
rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(IssueNumber \\(\\.\\.\\), PrNumber \\(\\.\\.\\)\\)" src/CodexWatcher/EventLogRepair.hs
rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids \\(TurnId \\(\\.\\.\\)\\)" src/CodexWatcher/EventLogRepair.hs
```

The first scan should return no matches. The second and third scans should return the new direct owner imports.

Run a remaining facade-user scan and record the output without expanding the round scope:

```sh
rg -n "CodexWatcher\\.Core\\.Ids" src app test *.cabal
```

Run package exposure scans proving the public compatibility facade remains exposed and both owner modules remain exposed:

```sh
rg -n "CodexWatcher\\.Core\\.Ids" moifold.cabal
rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids" agent-workflow-github/agent-workflow-github.cabal
rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids" agent-workflow-codex/agent-workflow-codex.cabal
```

Review the final diff manually for the project-contract invariants: no event schema changes, no golden fixture changes, no runtime compatibility file changes, no public facade removal, and no Cabal exposure changes.
