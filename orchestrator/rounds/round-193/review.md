### Checks Run
- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`
  Result: pass; loaded reviewer contract requiring plan, implementation notes, project contract, active verification, diff review, baseline checks, and explicit decision artifacts.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/verification.md`
  Result: pass; active roadmap verification is `2026-05-11-00-highest-value-cleanup` `rev-002` and requires `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check` when staging is involved, selected-file import scans, broad remaining-user scans, and preservation of test assertions/fixtures/PASS labels/aggregate wiring for test import rounds.
- Command: `sed -n '1,240p' orchestrator/project-contract.md`
  Result: pass; stable contracts require preserving command rendering, dry-run output, app-server request rendering, public compatibility facades, package/module ownership, fixture names/meanings, and highest-value cleanup sequencing.
- Command: `sed -n '1,220p' orchestrator/rounds/round-193/selection.md`
  Result: pass; selection is `direction-011i-runtime-spec-core-ids-import` under milestone `milestone-004-core-ids-test-and-fixture-import-burndown`, roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-002`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-193/plan.md`
  Result: pass; plan limits the round to an import-only migration in `test/RuntimeSpec.hs`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-193/implementation-notes.md`
  Result: pass; notes report the `RuntimeSpec` import replacement and no implementation changes outside the selected file.
- Command: `git diff -- test/RuntimeSpec.hs`
  Result: pass; diff is import-only, replacing `CodexWatcher.Core.Ids` with `CodexWatcher.Workflow.Agent.Ids (ThreadId (..))` and `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" test/RuntimeSpec.hs`
  Result: pass; no matches in the selected file, with `rg` exit 1 indicating absence.
- Command: `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" test/RuntimeSpec.hs`
  Result: pass; direct owner imports found at `test/RuntimeSpec.hs:30` and `test/RuntimeSpec.hs:31`.
- Command: `git diff --name-only`
  Result: pass; implementation diff paths are `orchestrator/state.json` and `test/RuntimeSpec.hs`; `orchestrator/state.json` was pre-existing controller state and was not edited by the reviewer.
- Command: `git diff -- test/Main.hs`
  Result: pass; no diff, so aggregate test wiring is unchanged.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal`
  Result: pass; remaining users are out of scope and expected: `moifold.cabal`, `test/FacadeImportPolicySpec.hs`, `test/Main.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, `src/CodexWatcher/Core/Ids.hs`, and docs references.
- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.

### Plan Compliance
- Replace only the `CodexWatcher.Core.Ids` import in `test/RuntimeSpec.hs`: met; `git diff -- test/RuntimeSpec.hs` shows only import-list changes.
- Import `ThreadId` from `CodexWatcher.Workflow.Agent.Ids`: met; selected-file scan found `import CodexWatcher.Workflow.Agent.Ids (ThreadId (..))`.
- Import `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId` from `CodexWatcher.Workflow.GitHub.Ids`: met; selected-file diff shows those constructors imported from the GitHub id-owner module.
- Preserve runtime assertions, command examples, expected args/stdin, process tests, export list, PASS labels, and aggregate wiring: met; `RuntimeSpec` diff is import-only, `test/Main.hs` has no diff, and `watcher-core-test` passed.
- Leave out-of-scope files unchanged for this implementation slice: met for `RuntimeCompatibilityFixtureSpec`, `FacadeImportPolicySpec`, `test/Main.hs`, source modules, docs, Cabal, public facade removal/deprecation, and fixture data; broad scan shows their remaining `Core.Ids` references are intentionally still present.
- Do not treat import preference as deprecation/removal approval: met; review records remaining public facade, Cabal, docs, and test evidence imports as out of scope.

### Decision
**APPROVED**

### Evidence
The integrated round result satisfies `direction-011i-runtime-spec-core-ids-import`. The selected file no longer imports `CodexWatcher.Core.Ids`, imports `ThreadId` from `CodexWatcher.Workflow.Agent.Ids`, and imports the GitHub id constructors from `CodexWatcher.Workflow.GitHub.Ids`. The only selected implementation diff in `test/RuntimeSpec.hs` is the import replacement, so runtime command rendering assertions, default options, process tests, expected arguments/stdin, PASS labels, and exported test definitions are unchanged.

`test/Main.hs` has no diff, so aggregate wiring is unchanged. The broad remaining-user scan found only expected out-of-scope `Core.Ids` references in `moifold.cabal`, `test/FacadeImportPolicySpec.hs`, `test/Main.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, `src/CodexWatcher/Core/Ids.hs`, and documentation. Baseline verification passed with `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.
