### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date` and exited 0.

- Command: `cabal test watcher-core-test`
  Result: pass. The suite ended with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`

- Command: `git diff --check`
  Result: pass. No whitespace or conflict-marker output.

- Command: `git diff --cached --check`
  Result: pass. No staged diff issues; no staged changes were present.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/PrReview/Watcher.hs`
  Result: pass. No matches in the target file; `rg` exited 1 as expected for no matches.

- Command: `rg -n "CodexWatcher\\.Workflow\\.(GitHub|Agent)\\.Ids" src/CodexWatcher/Domain/PrReview/Watcher.hs`
  Result: pass. The target file imports `CodexWatcher.Workflow.Agent.Ids (TurnId)` and `CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId (..))`.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test -g '*.hs'`
  Result: pass. Remaining `CodexWatcher.Core.Ids` imports are outside the selected file, including `src/CodexWatcher/Core/Ids.hs`, PR-review protocol/loop/launch modules, other workflow/runtime modules, and tests. No remaining match is in `src/CodexWatcher/Domain/PrReview/Watcher.hs`.

- Command: `git status --short`
  Result: pass. Changed paths were `orchestrator/state.json`, `src/CodexWatcher/Domain/PrReview/Watcher.hs`, and the untracked `orchestrator/rounds/round-161/` artifact directory.

- Command: `git diff --name-only`
  Result: pass. Tracked changed paths were only `orchestrator/state.json` and `src/CodexWatcher/Domain/PrReview/Watcher.hs`.

- Command: `find orchestrator/rounds/round-161 -maxdepth 1 -type f -print | sort`
  Result: pass. Before reviewer output, the round artifact directory contained only `implementation-notes.md`, `plan.md`, and `selection.md`.

- Command: `git diff -- src/CodexWatcher/Domain/PrReview/Watcher.hs`
  Result: pass. The production diff removes only the combined `CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), TurnId)` import and adds the two direct owner imports. No export list, data declaration, function body, event constructor, or missing-thread error text changed.

- Command: `git diff -- orchestrator/state.json`
  Result: pass. State is positioned at round-161 review with the requested roadmap lineage and no roadmap update, merge, milestone completion, terminal completion, or release/public compatibility approval.

- Command: `rg -n "verifyReviewerOutcome|missing|ReviewThreadId|TurnId|CommitSha" src/CodexWatcher/Domain/PrReview/Watcher.hs`
  Result: pass. `verifyReviewerOutcome` still contains the existing missing-thread text `clean verification did not mark fixed prior review threads as resolved:`.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" moifold.cabal src/CodexWatcher/Core/Ids.hs`
  Result: pass. `src/CodexWatcher/Core/Ids.hs` still declares `module CodexWatcher.Core.Ids`, and `moifold.cabal` still exposes `CodexWatcher.Core.Ids`.

- Command: `git diff --name-only -- orchestrator/roadmaps`
  Result: pass. No active roadmap files changed.

- Command: `git diff --name-only -- '*.cabal' docs agent-workflow-core agent-workflow-codex agent-workflow-github examples src/CodexWatcher/Runtime src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Permission.hs`
  Result: pass. No Cabal, docs, external-package candidate, runtime compatibility, AppServerClient, Workflow.EventLog, or Workflow.Permission files changed.

- Command: `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)$|CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)" moifold.cabal src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Core/Ids.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Permission.hs`
  Result: pass. All protected public modules remain declared in source and exposed in `moifold.cabal`: `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.

- Command: `git diff --cached --name-status`
  Result: pass. No staged changes.

- Command: `python3 -m json.tool orchestrator/rounds/round-161/review-record.json`
  Result: pass. The review record JSON parsed successfully.

- Command: `git diff --check`
  Result: pass after writing reviewer artifacts. No whitespace or conflict-marker output in the completed review diff.

### Plan Compliance
- Edit only `src/CodexWatcher/Domain/PrReview/Watcher.hs` for production code: met. The only production source diff is in the selected file, and it is import-only.
- Replace `CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), TurnId)` with direct owner imports: met. The file now imports `TurnId` from `CodexWatcher.Workflow.Agent.Ids` and `CommitSha` plus `ReviewThreadId (..)` from `CodexWatcher.Workflow.GitHub.Ids`.
- Preserve the rest of the import list except mechanical ordering: met. The diff shows only the removed facade import and the two added owner imports.
- Leave every function body and exported symbol unchanged: met. The source diff contains no body, constructor, export-list, pattern-match, or error-text changes.
- Do not edit `CodexWatcher.Core.Ids`, package descriptors, tests, docs, roadmap files, public compatibility facades, or other remaining `CodexWatcher.Core.Ids` importers: met. Scope checks show no changes to those surfaces, and the remaining facade import scan lists only out-of-scope users.
- Run roadmap baseline checks and focused import evidence: met. `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`, target-file facade scan, direct-owner import scan, and remaining-facade-user scan all passed.

### Decision
**APPROVED**

### Evidence
The integrated round result matches the selected extraction lineage:
`2026-05-11-00-highest-value-cleanup` / `rev-001` /
`milestone-003-import-convergence-package-boundaries` /
`direction-011-core-ids-import-convergence` /
`round-161-pr-review-watcher-core-ids-split-import-migration`.

The target file no longer imports `CodexWatcher.Core.Ids` and now imports the exact direct owner modules required by the plan. The production diff is limited to that import migration, so PR-review observation behavior, reviewer outcome validation, event constructors, and the missing-thread error text are unchanged.

No public compatibility conclusion is implied by this approval. `CodexWatcher.Core.Ids` remains present and exposed, the protected facades remain available, no Cabal/docs/package/runtime compatibility files changed, no roadmap or milestone status changed, and this review does not approve deprecation, removal, terminal completion, release, package publication, or public compatibility migration.
