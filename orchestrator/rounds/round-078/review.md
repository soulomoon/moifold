### Checks Run
- Command: `rg -n "^ *import +(qualified +)?CodexWatcher\\.Core\\.Ids(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; final scan found 35 `CodexWatcher.Core.Ids` import lines, all remaining callers are unchanged facade users recorded in `implementation-notes.md`.

- Command: `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; final split-owner scan found 42 direct owner import lines.

- Command: `git diff --name-only`
  Result: pass; diff is limited to 30 planned source/test import-only files.

- Command: `git diff --stat`
  Result: pass; 30 files changed, 30 insertions, 30 deletions.

- Command: `git diff --unified=0 -- src test app agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; every changed hunk is a one-line replacement from `CodexWatcher.Core.Ids` to either `CodexWatcher.Workflow.Agent.Ids` or `CodexWatcher.Workflow.GitHub.Ids`.

- Command: `git diff -- src/CodexWatcher/Core/Ids.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs '*.cabal' cabal.project README.md docs src/CodexWatcher/Runtime/Compatibility.hs src/CodexWatcher/Healthcheck.hs src/CodexWatcher/EventLogRepair.hs src/CodexWatcher/EventLog/Types.hs src/CodexWatcher/EventLog/Replay.hs src/CodexWatcher/Workflow/Execution.hs src/CodexWatcher/Workflow/Types.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Permission.hs`
  Result: pass; no output. The Core.Ids facade, split owner id modules, package descriptors, docs, runtime compatibility, healthcheck, repair, event-schema, Workflow.Execution/Types/EventLog/Permission, public API, deprecation, and facade-removal surfaces are unchanged.

- Command: `git diff --check`
  Result: pass; no whitespace errors.

- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.

- Command: `git diff --cached --name-only`
  Result: pass; no staged files.

- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `cabal build all`
  Result: pass; output: `Up to date`.

### Plan Compliance
- Active inputs: met. `state.json` selects `round-078`, roadmap `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, and item `round-078-core-ids-split-import-migration`.
- Starting and final inventories: met. `implementation-notes.md` records starting `Core.Ids` imports at 65, final `Core.Ids` imports at 35, and final direct owner imports at 42; reviewer reran the final scans.
- Agent-id-only migration: met. The planned agent-only source/test callers now import `CodexWatcher.Workflow.Agent.Ids`.
- GitHub-id-only migration: met with the planned boundary exception. The planned library/test callers now import `CodexWatcher.Workflow.GitHub.Ids`; `app/Main.hs` remains on `CodexWatcher.Core.Ids` because direct GitHub owner import would require an executable package dependency change, which is out of scope and recorded in `implementation-notes.md`.
- Mixed and deferred facade users: met. Remaining `CodexWatcher.Core.Ids` users are recorded as legitimate mixed users, explicit boundary deferrals, compatibility/event/repair/runtime/healthcheck surfaces, broad deferred users, or tests still compiling through the facade.
- Compile-only import adjustment: met. The diff contains only import-line replacements in 30 files and preserves behavior-facing implementation code.
- Final evidence recording: met. `implementation-notes.md` records changed files, chosen owner module, final counts, remaining facade users, and unchanged out-of-scope surfaces.
- Roadmap lineage and closed-family boundary: met. Round artifacts refer to the active `2026-05-10-00-facade-removal-readiness` rev-001 roadmap and do not rely on the closed `2026-05-09-01-compatibility-surface-cleanup` terminal hold.

### Decision
**APPROVED**

### Evidence
The integrated round result is a behavior-neutral import migration. The diff is limited to 30 one-line import replacements, with no changes to `src/CodexWatcher/Core/Ids.hs`, owner id modules, package descriptors, docs, runtime compatibility, healthcheck, repair, event schemas, deprecation pragmas, public API, or facade removal surfaces.

Focused scans show the remaining `CodexWatcher.Core.Ids` imports are still present and recorded rather than treated as removal evidence. The split-owner import scan shows direct imports are now used where the round selected single-owner callers. `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` all pass.
