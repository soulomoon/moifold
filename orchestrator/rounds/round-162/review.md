### Checks Run
- Command: `cabal build all`
  Result: PASS. Output summary: `Up to date`.

- Command: `cabal test watcher-core-test`
  Result: PASS. Output summary: `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed.` The run exercised the issue-planning observation path, fanout behavior, compatibility fixture checks, runtime compatibility checks, and related watcher coverage.

- Command: `git diff --check`
  Result: PASS. No whitespace errors reported.

- Command: `git diff --cached --check`
  Result: PASS. No staged whitespace errors reported; no staged changes are present.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`
  Result: PASS. No matches; `rg` exited 1 because the selected file no longer references `CodexWatcher.Core.Ids`.

- Command: `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`
  Result: PASS. Output:
  - `32:import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`
  - `33:import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))`

- Command: `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github examples`
  Result: PASS. The selected file is absent from the remaining importer list. Remaining users are intentionally out of scope for this round and still include production, test, and compatibility-policy users such as `src/CodexWatcher/EffectInterpreter.hs`, `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, and `test/FacadeImportPolicySpec.hs`.

- Command: `git status --short && git diff --name-status && git diff --cached --name-status && git ls-files --others --exclude-standard`
  Result: PASS. Changed tracked files are only `orchestrator/state.json` and `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`; untracked round artifacts before this review were `orchestrator/rounds/round-162/selection.md`, `plan.md`, and `implementation-notes.md`; there are no staged files.

- Command: `git diff -- src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`
  Result: PASS. The production diff is import-only: it removes `import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId, TurnId)` and adds direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.

- Command: `sed -n '1,180p' src/CodexWatcher/Core/Ids.hs`
  Result: PASS. `CodexWatcher.Core.Ids` remains present and re-exports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.Agent\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids" moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`
  Result: PASS. `moifold.cabal:46` still exposes `CodexWatcher.Core.Ids`; the direct owner modules remain exposed from their owner packages.

- Command: `git diff --name-only -- docs moifold.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github src/CodexWatcher/Core/Ids.hs src/CodexWatcher/Runtime orchestrator/roadmaps`
  Result: PASS. No docs, Cabal/package descriptors, owner package descriptors, runtime compatibility files, `Core.Ids` facade file, or roadmap files changed.

### Plan Compliance
- Edit only `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs` for production code: met. The only production source change is the selected file.
- Replace `CodexWatcher.Core.Ids (IssueNumber (..), ThreadId, TurnId)` with direct owner imports: met. `ThreadId` and `TurnId` now come from `CodexWatcher.Workflow.Agent.Ids`; `IssueNumber (..)` now comes from `CodexWatcher.Workflow.GitHub.Ids`.
- Preserve function bodies, export list, planning graph validation, issue-number rendering, `selectIssueImplementationStarts`, and error text: met. The selected source diff is import-only.
- Leave `CodexWatcher.Core.Ids` exposed and unchanged: met. The facade file is unchanged and `moifold.cabal` still exposes it.
- Do not touch tests, package descriptors, docs, roadmap status, compatibility policy, runtime compatibility files, deprecation/removal gates, milestone completion, terminal completion, release approval, or public compatibility approval: met. Scope checks show no changes in those surfaces; the round artifacts explicitly keep those items out of scope.
- Record implementation notes with changed file, import-only scope, verification, and remaining facade users: met. `implementation-notes.md` records the selected file, command results, and the remaining `Core.Ids` importer scan.

### Decision
**APPROVED**

### Evidence
The integrated round result matches the selected one-file import migration. The production diff is limited to import ownership in `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`, and the baseline build/test checks pass.

`CodexWatcher.Core.Ids` remains present, unchanged, and exposed. This approval does not imply deprecation, removal, Cabal exposure cleanup, docs or policy approval, runtime compatibility migration, milestone completion, terminal roadmap completion, release approval, package publication approval, or public compatibility approval.
