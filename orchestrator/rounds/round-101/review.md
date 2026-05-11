### Checks Run
- Command: `git diff -- app/Main.hs moifold.cabal`
  Result: pass. Diff is limited to replacing `CodexWatcher.Core.Ids (RepoName (unRepoName))` with `CodexWatcher.Workflow.GitHub.Ids (RepoName (unRepoName))` in `app/Main.hs`, plus adding `agent-workflow-github >=0.1 && <0.2` only to the `executable moifold` `build-depends`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids \\(RepoName \\(unRepoName\\)\\)|CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(RepoName \\(unRepoName\\)\\)|unRepoName|healthcheckOptionsFromCli" app/Main.hs`
  Result: pass. `app/Main.hs:18` imports `CodexWatcher.Workflow.GitHub.Ids (RepoName (unRepoName))`; `healthcheckOptionsFromCli` remains at `app/Main.hs:38`; `repoFilter = unRepoName <$> options.healthcheckCliRepo` remains at `app/Main.hs:42`.
- Command: `rg -n "import CodexWatcher\\.Core\\.Ids \\(RepoName \\(unRepoName\\)\\)" app/Main.hs src test`
  Result: pass. No matches; the selected old `RepoName (unRepoName)` facade import is gone from `app/Main.hs`, `src`, and `test`.
- Command: `rg -n "import CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(RepoName \\(unRepoName\\)\\)" app/Main.hs src test`
  Result: pass. Matches are `app/Main.hs:18` and the pre-existing direct owner import in `src/CodexWatcher/Cli/Command/Service.hs:14`.
- Command: `rg -n "module CodexWatcher\\.Core\\.Ids|module CodexWatcher\\.Workflow\\.GitHub\\.Ids|newtype RepoName|unRepoName" src agent-workflow-github app test`
  Result: pass. `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs:5` defines the owner module and line 16 defines `newtype RepoName`; `src/CodexWatcher/Core/Ids.hs:1` remains the compatibility facade and reexports `CodexWatcher.Workflow.GitHub.Ids`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids" src app test docs *.cabal agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass. Broad import/exposure scan shows `app/Main.hs` moved to the direct owner, remaining facade users are untouched, docs still describe compatibility policy, and `moifold.cabal:46` still exposes `CodexWatcher.Core.Ids`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids|agent-workflow-github" moifold.cabal agent-workflow-core/*.cabal agent-workflow-codex/*.cabal agent-workflow-github/*.cabal`
  Result: pass. `moifold.cabal:46` still exposes `CodexWatcher.Core.Ids`; `agent-workflow-github/agent-workflow-github.cabal:48` exposes `CodexWatcher.Workflow.GitHub.Ids`; the round diff adds only the executable dependency at `moifold.cabal:171`.
- Command: `sed -n '1,40p' src/CodexWatcher/Core/Ids.hs && sed -n '130,180p' moifold.cabal`
  Result: pass. `CodexWatcher.Core.Ids` still reexports agent and GitHub IDs; the library still depends on `agent-workflow-github`, and the executable stanza now has the direct dependency needed for the owner import.
- Command: `cabal test watcher-core-test`
  Result: pass. Test suite `watcher-core-test` passed; Cabal reported `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors; no files were staged.

### Plan Compliance
- Reconfirm selected surface before editing: met. Current scan shows the direct owner import, `healthcheckOptionsFromCli`, and unchanged `repoFilter = unRepoName <$> options.healthcheckCliRepo`.
- Apply only intended source edit: met. `app/Main.hs` diff contains only the selected import replacement; command dispatch and healthcheck construction are unchanged.
- Run focused import and owner scans: met. The selected old facade import is absent, the direct owner import is present in `app/Main.hs`, and owner/facade module scans confirm `CodexWatcher.Workflow.GitHub.Ids` owns `RepoName` while `CodexWatcher.Core.Ids` remains present.
- Check descriptor reachability before and after compile: met. `implementation-notes.md` records the initial hidden-package compile failure for the direct owner import, and the only descriptor change is the minimal executable `agent-workflow-github >=0.1 && <0.2` dependency.
- Review diff for scope: met. Diff is limited to `app/Main.hs` and `moifold.cabal`; no implementation code, tests, library exposure, docs, roadmap, state, selection, plan, or prior artifact changes were made by this review.
- Run baseline verification: met. `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` all passed.
- Stop instead of broadening on out-of-scope failures: met. No out-of-scope verification failure occurred.
- Roadmap and project-contract alignment: met. Round records lineage for `2026-05-11-00-highest-value-cleanup` `rev-001`; this is import convergence only and does not claim deprecation, removal, Cabal exposed-module cleanup, milestone completion, release, or terminal completion.

### Decision
**APPROVED**

### Evidence
The integrated round matches the expected implementation. `app/Main.hs` now imports `RepoName (unRepoName)` from `CodexWatcher.Workflow.GitHub.Ids`, while `healthcheckOptionsFromCli` still converts `options.healthcheckCliRepo` with `unRepoName` into `repoFilter`. The focused old-import scan returned no selected `CodexWatcher.Core.Ids (RepoName (unRepoName))` import. The diff leaves command dispatch unchanged.

The `moifold.cabal` change is justified by the implementation note's compile proof: the executable could not import the direct owner module while `agent-workflow-github` was hidden. The final descriptor diff adds `agent-workflow-github >=0.1 && <0.2` only to the executable stanza. `CodexWatcher.Core.Ids` remains exposed at `moifold.cabal:46` and remains implemented as a public compatibility facade in `src/CodexWatcher/Core/Ids.hs`.

No public facade exposure, deprecation/removal policy, roadmap file, state file, tests, or runtime behavior surfaces were changed by this round. Baseline gates passed.
