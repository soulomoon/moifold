### Checks Run
- Command: `git diff -- src/CodexWatcher/Core/State.hs`
  Result: pass. The only implementation change in the selected source file removes `import CodexWatcher.Core.Ids` and adds `import CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)`. No constructors, exports, deriving clauses, parsers, renderers, or behavior code changed.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids|CommitSha|PrNumber|RequestId|ThreadId|TurnId|nextRequestId|RepoName|IssueNumber|BranchName|ReviewThreadId" src/CodexWatcher/Core/State.hs`
  Result: pass. Output showed one direct-owner import at `src/CodexWatcher/Core/State.hs:32` and only `CommitSha` / `PrNumber` id-token use in the file. No `CodexWatcher.Core.Ids` import remains in `Core.State`.

- Command: `rg -n "exposed-modules:|CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Core\\.State|CodexWatcher\\.Workflow\\.GitHub\\.Ids" moifold.cabal agent-workflow-github/agent-workflow-github.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal cabal.project`
  Result: pass. Output showed `moifold.cabal` still exposes `CodexWatcher.Core.Ids` and `CodexWatcher.Core.State`, and `agent-workflow-github/agent-workflow-github.cabal` exposes `CodexWatcher.Workflow.GitHub.Ids`.

- Command: `rg -n "^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)([[:space:]]|$|\\()" src app test agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass. The selected facade import scan no longer lists `src/CodexWatcher/Core/State.hs`; remaining `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission` imports remain in other files and are out of scope for round-100.

- Command: `git diff -- moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal cabal.project`
  Result: pass. Empty output; no package descriptor changed.

- Command: `git diff --stat`
  Result: pass with note. Tracked diff contains `src/CodexWatcher/Core/State.hs` plus `orchestrator/state.json`. The state diff records controller dispatch/review metadata for `round-100`; it does not change roadmap revision, roadmap directory, milestone completion, or implementation behavior.

- Command: `git diff -- src/CodexWatcher/Core/State.hs orchestrator/rounds/round-100/plan.md`
  Result: pass. Output showed only the selected import change in `src/CodexWatcher/Core/State.hs`; `plan.md` had no tracked diff.

- Command: `git diff -- orchestrator/state.json`
  Result: pass with note. State moved from no active round to `stage: "review"` for `round-100` with lineage matching the selection: roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, and extracted item `round-100-core-state-github-ids-import-convergence`.

- Command: `cabal test watcher-core-test`
  Result: pass. GHC 9.12.2 built and ran `watcher-core-test`; final summary was `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `cabal build all`
  Result: pass. Output: `Up to date`.

- Command: `git diff --check`
  Result: pass. Empty output.

- Command: `git diff --cached --check`
  Result: pass. Empty output; no staged diff.

- Command: `git diff --cached --name-only`
  Result: pass. Empty output; no staged files.

### Plan Compliance
- Re-read coordination inputs: met. Reviewed `orchestrator/state.json`, `selection.md`, `plan.md`, `implementation-notes.md`, `project-contract.md`, and active verification bundle `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`.
- Selected source import convergence: met. `src/CodexWatcher/Core/State.hs` now imports `CommitSha` and `PrNumber` from `CodexWatcher.Workflow.GitHub.Ids` and no longer imports `CodexWatcher.Core.Ids`.
- Preserve behavior and typed state surface: met. The source diff is import-only; `CompletionEvidence`, `WatcherState`, `SomeWatcherState`, constructors, exports, and deriving clauses are unchanged.
- Keep public compatibility facade exposure: met. `moifold.cabal` still exposes `CodexWatcher.Core.Ids`; no package descriptor diff exists.
- Keep direct owner available through package graph: met. `agent-workflow-github/agent-workflow-github.cabal` exposes `CodexWatcher.Workflow.GitHub.Ids`.
- Leave remaining facade users untouched: met. Facade import scan shows remaining users outside `Core.State`; they are expected blockers or later slices per plan.
- Avoid deprecation, removal, release, milestone completion, or terminal completion claims: met. No roadmap files changed; `state.json` only records active round review metadata and no completion transition.
- Run focused checks and baseline gates: met. Source diff, id/import scans, facade scan, package descriptor diff, `watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` all passed.

### Decision
**APPROVED**

### Evidence
The implementation matches the expected one-file source change: `src/CodexWatcher/Core/State.hs` replaces the combined `CodexWatcher.Core.Ids` import with `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)`. The selected file now has no `Core.Ids` import and only uses the GitHub id types named by the round.

Package-boundary evidence is clean: `CodexWatcher.Workflow.GitHub.Ids` is already exposed by `agent-workflow-github`, `CodexWatcher.Core.Ids` remains exposed by `moifold.cabal`, and package descriptor diff output is empty.

Baseline verification passed: `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`. No staged files were present during cached diff verification.
