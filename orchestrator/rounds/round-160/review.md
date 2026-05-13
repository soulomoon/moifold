### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. The suite ended with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass with no output.
- Command: `git diff --cached --check`
  Result: pass with no output.
- Command: `git diff --cached --name-status`
  Result: pass with no output; no staged changes were present.
- Command: `if rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Cli/RuntimeConfig.hs; then exit 1; else echo "no CodexWatcher.Core.Ids references in RuntimeConfig.hs"; fi`
  Result: pass. Output confirmed no `CodexWatcher.Core.Ids` references in `RuntimeConfig.hs`.
- Command: `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Cli/RuntimeConfig.hs`
  Result: pass. Found `CodexWatcher.Workflow.Agent.Ids (RequestId (..))` and `CodexWatcher.Workflow.GitHub.Ids (IssueNumber, RepoName)`.
- Command: `git diff -U0 -- src/CodexWatcher/Cli/RuntimeConfig.hs`
  Result: pass. The only production-code hunk replaces the single `CodexWatcher.Core.Ids (IssueNumber, RepoName, RequestId (..))` import with the two direct owner imports.
- Command: `rg -n "module CodexWatcher\\.Core\\.Ids|module CodexWatcher\\.Workflow\\.Agent\\.Ids|module CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/Core/Ids.hs`
  Result: pass. The facade remains present and still re-exports the agent and GitHub ID modules.
- Command: `rg -n "^\\s+CodexWatcher\\.Core\\.Ids$" moifold.cabal`
  Result: pass. `moifold.cabal:46` still exposes `CodexWatcher.Core.Ids`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test *.cabal`
  Result: pass. Remaining facade users were found outside `RuntimeConfig.hs`, including the exposed-module entry and existing source/test importers; they remain intentionally out of scope.
- Command: `git status --porcelain=v1 --untracked-files=all | awk '{p=substr($0,4); if (p != "orchestrator/state.json" && p != "src/CodexWatcher/Cli/RuntimeConfig.hs" && p !~ /^orchestrator\\/rounds\\/round-160\\//) {print "unexpected: " p; bad=1}} END {if (bad) exit 1; print "scope ok: only orchestrator/state.json, round-160 artifacts, and RuntimeConfig.hs changed"}'`
  Result: pass. Changed paths were limited to the selected source file, control-plane state, and round-160 artifacts.
- Command: `git diff --name-only -- '*.cabal' 'docs/**' 'package.yaml' 'cabal.project*' 'fixtures/**' 'runtime/**'`
  Result: pass with no output; no package descriptor, docs, fixture, or runtime compatibility path changed.
- Command: `git diff --name-only -- src/CodexWatcher/Core/Ids.hs moifold.cabal docs app test src/CodexWatcher/Runtime/Compatibility.hs`
  Result: pass with no output; no facade, Cabal exposure, app, docs, test, or runtime compatibility file changed.
- Command: `rg -n "2026-05-10-00-facade-removal-readiness|2026-05-09-01-compatibility-surface-cleanup|2026-05-11-00-highest-value-cleanup" orchestrator/rounds/round-160`
  Result: pass. Round artifacts reference the active `2026-05-11-00-highest-value-cleanup` family and do not append this work to older families.
- Command: `rg -n "deprecat|facade deletion|Cabal exposed|exposed-module|milestone completion|terminal completion|release approval|public compatibility removal|removal approval" orchestrator/rounds/round-160/selection.md orchestrator/rounds/round-160/plan.md orchestrator/rounds/round-160/implementation-notes.md`
  Result: pass. Matches are explicit out-of-scope/non-claim statements, not approvals.

### Plan Compliance
- Replace only the `RuntimeConfig.hs` `CodexWatcher.Core.Ids` import with direct owner imports: met. `git diff -U0` shows only that import replacement.
- Preserve function bodies, exports, default runtime configuration, planner scope behavior, thread instructions, `effectRuntimeRepo`, and `effectRuntimeNextRequestId = RequestId 1`: met. The production diff contains no body or export changes.
- Do not migrate adjacent `Core.Ids` importers in other modules: met. The broader `rg` scan shows remaining facade users outside `RuntimeConfig.hs`, intentionally unchanged.
- Preserve public `CodexWatcher.Core.Ids` facade and exposure: met. `src/CodexWatcher/Core/Ids.hs` remains present and `moifold.cabal` still exposes `CodexWatcher.Core.Ids`.
- Do not edit tests, package descriptors, docs, runtime compatibility files, facade modules, public exports, or roadmap status as part of the implementation: met for the integrated production diff. The only production change is `RuntimeConfig.hs`; control-plane state already records the live review round and is not a roadmap status update.
- Do not imply deprecation, removal, Cabal exposure cleanup, terminal completion, milestone completion, release approval, or public compatibility approval: met. Selection, plan, and implementation notes state these are out of scope, and no corresponding files changed.

### Decision
**APPROVED**

### Evidence
The integrated round result matches the selected extraction for `round-160-runtime-config-core-ids-split-import-migration`: one import-only production migration in `src/CodexWatcher/Cli/RuntimeConfig.hs`, moving `RequestId` to `CodexWatcher.Workflow.Agent.Ids` and `IssueNumber`/`RepoName` to `CodexWatcher.Workflow.GitHub.Ids`.

Baseline build, baseline test, diff hygiene, focused import scans, scope checks, and compatibility-facade checks all passed. `CodexWatcher.Core.Ids` remains available and exposed, remaining facade users remain out of scope, and this approval is limited to the import convergence slice. It is not deprecation, removal, Cabal exposure cleanup, milestone completion, terminal completion, release approval, or public compatibility approval.
