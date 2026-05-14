### Checks Run
- Command: `cabal build all`
  Result: pass. Output: `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. Output ended with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. Nothing staged; no cached whitespace errors reported.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" test/WorkflowExecutionSpec.hs`
  Result: pass. No matches in the selected target.
- Command: `rg -n "\\bRequestId\\b" test/WorkflowExecutionSpec.hs`
  Result: pass. No matches; no unused `RequestId` import was introduced.
- Command: `rg -n "CodexWatcher.Workflow.Agent.Ids|CodexWatcher.Workflow.GitHub.Ids" test/WorkflowExecutionSpec.hs`
  Result: pass. Direct imports present at `test/WorkflowExecutionSpec.hs:78` and `test/WorkflowExecutionSpec.hs:88`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" test src app docs moifold.cabal agent-workflow-*`
  Result: pass for classification. Remaining users are out of selected scope:
  `test/WorkflowIndexedSpec.hs:66`, `test/RuntimeSpec.hs:30`, `test/CliSpec.hs:14`, `test/RuntimeCompatibilityFixtureSpec.hs:11`, `test/FacadeImportPolicySpec.hs:11`, `test/Main.hs:67`, `docs/agentic-workflow-framework/release-notes.md:98`, `docs/agentic-workflow-framework/release-candidate-bundle.md:70`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:60`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:86`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:100`, `moifold.cabal:46`, and `src/CodexWatcher/Core/Ids.hs:1`.
- Command: `rg -n "^import .*CodexWatcher\\.Core\\.Ids|^import CodexWatcher\\.Core\\.Ids" src app test`
  Result: pass for production/app classification. Import matches are only in tests: `test/RuntimeCompatibilityFixtureSpec.hs:11`, `test/WorkflowIndexedSpec.hs:66`, `test/RuntimeSpec.hs:30`, `test/FacadeImportPolicySpec.hs:11`, `test/CliSpec.hs:14`, and `test/Main.hs:67`; no `src` or `app` import users remain.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" app agent-workflow-*`
  Result: pass. No matches in app code or standalone workflow package candidates.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" --glob "*.cabal" --glob "package.yaml" --glob "cabal.project*" .`
  Result: pass for package classification. Only `./moifold.cabal:46` exposes the compatibility facade; standalone package candidate cabals and `cabal.project` have no matches.
- Command: `git diff -- test/WorkflowExecutionSpec.hs`
  Result: pass. The selected file diff removes `import CodexWatcher.Core.Ids` and adds only direct `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` imports.
- Command: `git diff --numstat -- test/WorkflowExecutionSpec.hs && git diff -U0 -- test/WorkflowExecutionSpec.hs`
  Result: pass. Selected file has `2` additions and `1` deletion, all import lines.
- Command: `git diff --name-status && git status --short`
  Result: pass for review context. Tracked diffs are `orchestrator/state.json` control-plane active-round metadata and `test/WorkflowExecutionSpec.hs`; round artifacts are untracked before this review writes its required outputs.

### Plan Compliance
- Edit only `test/WorkflowExecutionSpec.hs` for the implementation migration: met. The selected implementation file diff is import-only. `orchestrator/state.json` also has control-plane active-round metadata for `round-190`, but it is not an implementation migration and was not edited during this review.
- Remove `import CodexWatcher.Core.Ids`: met. The selected-file scan has no `CodexWatcher.Core.Ids` matches.
- Add direct owner imports: met. `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))` and `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..), ReviewThreadId (..))` are present.
- Do not import `RequestId`: met. `rg -n "\\bRequestId\\b" test/WorkflowExecutionSpec.hs` has no matches.
- Preserve test bodies, fixtures, assertion strings, PASS labels, runtime command expected values, aggregate wiring, replay expectations, and behavior: met. The selected file diff is limited to import lines, and `cabal test watcher-core-test` passed.
- Do not touch out-of-scope files such as `test/WorkflowIndexedSpec.hs`, runtime/CLI tests, `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, source modules, docs, Cabal files, roadmap files, public facade removal/deprecation, runtime compatibility cleanup, fixture data, or milestone completion state: met for implementation scope. No out-of-scope source/test/docs/Cabal files were changed by the selected implementation diff.
- Record remaining users separately without claiming public facade removal or milestone completion: met. Remaining `Core.Ids` users are classified below and remain out of scope.

### Decision
**APPROVED**

### Evidence
The selected `test/WorkflowExecutionSpec.hs` migration is behavior-preserving and import-only:

```diff
-import CodexWatcher.Core.Ids
+import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))
+import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..), ReviewThreadId (..))
```

Remaining-user classification:

- `WorkflowIndexedSpec`: `test/WorkflowIndexedSpec.hs:66`.
- Runtime/CLI tests: `test/RuntimeSpec.hs:30`, `test/CliSpec.hs:14`, `test/RuntimeCompatibilityFixtureSpec.hs:11`.
- Policy/aggregator candidates: `test/FacadeImportPolicySpec.hs:11`, `test/Main.hs:67`.
- Docs/Cabal/public facade: `docs/agentic-workflow-framework/release-notes.md:98`, `docs/agentic-workflow-framework/release-candidate-bundle.md:70`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:60`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:86`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:100`, `moifold.cabal:46`, `src/CodexWatcher/Core/Ids.hs:1`.
- Production/app/package users: no `src` import users beyond the facade module itself, no `app` matches, and no standalone `agent-workflow-*` package candidate matches.

The active roadmap lineage is `2026-05-11-00-highest-value-cleanup` / `rev-002`, and this round does not treat preferred imports as deprecation, Cabal exposure removal, public facade removal, or milestone completion approval.
