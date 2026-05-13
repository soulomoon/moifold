### Checks Run
- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass; no whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors reported.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Cli/Parser/Observe.hs`
  Result: pass; no matches in the selected file.
- Command: `rg -n "CodexWatcher\\.Workflow\\.(GitHub|Agent)\\.Ids" src/CodexWatcher/Cli/Parser/Observe.hs`
  Result: pass; direct owner imports are present at lines 21 and 22.
- Command: `git diff --name-only`
  Result: pass for production scope; tracked modified files are `src/CodexWatcher/Cli/Parser/Observe.hs` and controller state `orchestrator/state.json`.
- Command: `git ls-files --others --exclude-standard`
  Result: pass for round artifacts; untracked files are `orchestrator/rounds/round-158/selection.md`, `plan.md`, and `implementation-notes.md` before reviewer artifacts.
- Command: `git diff -U0 -- src/CodexWatcher/Cli/Parser/Observe.hs`
  Result: pass; zero-context diff changes only the import from `CodexWatcher.Core.Ids` to direct `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.
- Command: `python3 -m json.tool orchestrator/rounds/round-158/review-record.json`
  Result: pass; review record parsed and pretty-printed successfully.

### Plan Compliance
- Confirm the only intended production change is the identifier import block: met; the zero-context diff for `src/CodexWatcher/Cli/Parser/Observe.hs` changes only the import lines.
- Replace the existing `CodexWatcher.Core.Ids` import with the two direct owner imports: met; `TurnId (..)` now comes from `CodexWatcher.Workflow.Agent.Ids`, while `CommitSha (..)` and `PrNumber (..)` come from `CodexWatcher.Workflow.GitHub.Ids`.
- Preserve parser expressions, constructor applications, option names, help strings, optional wrappers, and review-thread parsing: met; no non-import lines in `Observe.hs` changed.
- Keep scope narrow and avoid package descriptors, facade modules, docs, runtime compatibility files, command execution, parser helper, or test rewrites: met for production implementation; no such files changed. The worktree also contains active round controller state and round artifact files, which are orchestration metadata rather than implementation changes.
- Preserve public compatibility surfaces and avoid deprecation/removal approval: met; `CodexWatcher.Core.Ids` itself was not edited or removed, and this review does not approve Cabal exposure cleanup, public facade deletion, release, or terminal completion.

### Decision
**APPROVED**

### Evidence
The selected production file now imports:

```haskell
import CodexWatcher.Workflow.Agent.Ids (TurnId (..))
import CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber (..))
```

`src/CodexWatcher/Cli/Parser/Observe.hs` has no remaining `CodexWatcher.Core.Ids` import, and its parser body is unchanged. The required serial checks passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

Tracked non-production orchestration state is present in `orchestrator/state.json`, and round artifacts are untracked under `orchestrator/rounds/round-158/`; these match the active round metadata and do not alter parser behavior or compatibility surfaces.
