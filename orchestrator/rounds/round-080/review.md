### Checks Run
- Command: `test -f deprecation-readiness-decision.md` from `orchestrator/rounds/round-080`
  Result: pass; the decision artifact exists.
- Command: `test ! -e worker-plan.json` from `orchestrator/rounds/round-080`
  Result: pass; no worker fan-out artifact exists.
- Command: `git status --short --branch --untracked-files=all`
  Result: pass; branch is `orchestrator/round-080-deprecation-readiness` with only round-local untracked artifacts before this review: `selection.md`, `plan.md`, and `deprecation-readiness-decision.md`.
- Command: `git ls-files --others --exclude-standard`
  Result: pass; untracked files are limited to `orchestrator/rounds/round-080/deprecation-readiness-decision.md`, `orchestrator/rounds/round-080/plan.md`, and `orchestrator/rounds/round-080/selection.md` before review output.
- Command: `git diff --name-only`
  Result: pass; no tracked unstaged file changes.
- Command: `git diff --cached --name-only`
  Result: pass; no staged file changes.
- Command: `git diff --name-only -- src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal cabal.project README.md docs orchestrator/state.json orchestrator/roadmaps`
  Result: pass; no tracked production code, tests, docs, Cabal, roadmap, or state changes.
- Command: `git diff --cached --name-only -- src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal cabal.project README.md docs orchestrator/state.json orchestrator/roadmaps`
  Result: pass; no staged production code, tests, docs, Cabal, roadmap, or state changes.
- Command: `git diff --check`
  Result: pass; no whitespace errors in tracked unstaged diff.
- Command: `git diff --cached --check`
  Result: pass; no staged diff.
- Command: `zsh -lc 'out=$(git diff --no-index --check -- /dev/null orchestrator/rounds/round-080/deprecation-readiness-decision.md || true); test -z "$out"'`
  Result: pass; the untracked decision artifact has no whitespace errors.
- Command: `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))(?!\.)(\b| +as +| *$| +qualified| +\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; exact selected-facade inventory matches the artifact: 13 `AppServerClient`, 35 `Core.Ids`, 3 `Workflow.EventLog`, and 1 `Workflow.Permission` imports.
- Command: `rg -n "^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; 13 current local import sites remain.
- Command: `rg -n "^ *import +(qualified +)?CodexWatcher\.Core\.Ids(\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; 35 current local import sites remain.
- Command: `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\.Workflow\.EventLog(?!\.)(\b| +as +| *$| +qualified| +\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; 3 current local import sites remain.
- Command: `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission(?!\.)(\b| +as +| *$| +qualified| +\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; 1 current local import site remains.
- Command: `rg -n "^ *import +(qualified +)?CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport)(\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; replacement Codex client/transport imports exist and remain only migration-path evidence.
- Command: `rg -n "^ *import +(qualified +)?CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids(\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; split id replacement imports exist and remain only migration-path evidence.
- Command: `rg -n "^ *import +(qualified +)?CodexWatcher\.Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)(\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; event-log replacement/core imports exist, but bridge facade users remain.
- Command: `rg -n "^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission\.Core(\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; permission core is imported by the facade, not evidence of public deprecation readiness.
- Command: `rg -n "^  exposed-modules:|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.(Agent|GitHub)\.Ids|Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)|Workflow\.Permission\.Core)" moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal`
  Result: pass; `moifold.cabal` still exposes all four selected facades, and package candidates expose the replacement modules.
- Command: `rg -n "workflowMoifoldCabalLibraryDoesNotReexportAdapters|exposed module|package boundary|agent-workflow-core|agent-workflow-codex|agent-workflow-github" test/Main.hs`
  Result: pass; package-boundary and exposed-module inventory tests remain present.
- Command: `find docs -path '*dist*' -prune -o -type f \( -iname '*.html' -o -iname '*.txt' -o -iname '*haddock*' \) -print | sort`
  Result: pass; no checked-in generated docs/Haddock text under `docs`.
- Command: `rg -n "CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))" README.md docs agent-workflow-*/README.md examples/workflow-package-consumer/README.md`
  Result: pass; docs mention selected facades as compatibility surfaces and preferred-import context, not public deprecation approval.
- Command: `rg -n "deprecat|deprecated|DEPRECATED|remove-later|preferred import|preferred-import|compatibility facade|compatibility-only" README.md docs agent-workflow-*/README.md docs/agentic-workflow-framework/changelog.md docs/agentic-workflow-framework/release-notes.md docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  Result: pass; policy explicitly says preferred-import guidance is not a deprecation pragma, warning policy, Cabal descriptor migration, or removal approval.
- Command: `rg -n -e "\{-# DEPRECATED" -e "Deprecated:" -e "DEPRECATED" -e "deprecat" -e "compatibility-only" -e "preferred import" -e "preferred-import" src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Core/Ids.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Permission.hs || true`
  Result: pass; no source deprecation signal exists in selected facades.
- Command: `rg -n "CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))" examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs`
  Result: pass; local downstream/package-candidate inventory is documented and does not show exact selected-facade imports in examples or package candidates.
- Command: `rg -n "^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))" examples agent-workflow-core agent-workflow-codex agent-workflow-github || true`
  Result: pass; no exact selected-facade imports under examples or standalone package candidates.
- Command: `rg -n "CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))" *.cabal agent-workflow-*/*.cabal examples/workflow-package-consumer/*.cabal`
  Result: pass; selected facades appear in `moifold.cabal`; package candidates expose replacement modules.
- Command: `gh auth status`
  Result: pass; authenticated as `soulomoon`.
- Command: `gh search code "CodexWatcher.AppServerClient" --owner soulomoon --limit 100 --json repository,path --jq 'length'`
  Result: pass; 31 owner-scoped results.
- Command: `gh search code "CodexWatcher.Core.Ids" --owner soulomoon --limit 100 --json repository,path --jq 'length'`
  Result: pass; 61 owner-scoped results.
- Command: `gh search code "CodexWatcher.Workflow.EventLog" --owner soulomoon --limit 100 --json repository,path --jq 'length'`
  Result: pass; 0 owner-scoped results.
- Command: `gh search code "CodexWatcher.Workflow.Permission" --owner soulomoon --limit 100 --json repository,path --jq 'length'`
  Result: pass; 0 owner-scoped results.
- Command: `gh search code "CodexWatcher.AppServerClient" --owner soulomoon --limit 5`
  Result: pass; sample results are all in `soulomoon/moifold`.
- Command: `gh search code "CodexWatcher.Core.Ids" --owner soulomoon --limit 5`
  Result: pass; sample results are all in `soulomoon/moifold`.
- Command: `rg -n "AppServer|app-server|formatAppServerClientFailure|decodeAppServerIncoming|parseThread|sendOneAppServerRequest|request-id|timeout" test src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src`
  Result: pass; behavior-protection scan finds app-server protocol, client, transport, CLI, and test coverage.
- Command: `rg -n "BranchName|CommitSha|IssueNumber|PrNumber|RepoName|RequestId|ReviewThreadId|ThreadId|TurnId|parse|render|nextRequestId" test src app agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs`
  Result: pass; identifier parsing/rendering and runtime command protection points remain present.
- Command: `rg -n "workflowEventLog|workflow event-log|goldenEventLog|golden event|eventLogRepair|replayEventLog|WorkflowTransitionFailure|WorkflowReplayFailure" test/Main.hs test/*Spec.hs`
  Result: pass; old-log, golden, replay, repair, event-log core, and facade parity protection points remain present.
- Command: `rg -n "workflowPermission|workflow permission|phaseActionValidation|phase action|validateMoifoldEffectPlan|moifoldPermissionPolicy|Permission" test/Main.hs test/*Spec.hs`
  Result: pass; permission, phase-validation, policy, and parity protection points remain present.
- Command: `cabal haddock all`
  Result: pass; Haddock generated for `agent-workflow-core`, `agent-workflow-github`, `agent-workflow-codex`, and `moifold` under ignored `dist-newstyle`. Existing missing-documentation and unresolved-link warnings remain, including selected-surface-adjacent modules; no deprecation signal is generated from selected facade source text.
- Command: `cabal test watcher-core-test`
  Result: not run; the only implementation write is a round-local evidence artifact, and tracked diffs plus untracked inventory prove no source, test, Cabal, docs, API, behavior, exposure, runtime compatibility, roadmap, or state surface changed. Verification.md permits skipping this baseline for this artifact-only round unless behavior-surface uncertainty or out-of-scope edits appear; neither appeared.

### Plan Compliance
- Step 1, confirm active inputs and scope: met. State, project contract, roadmap verification, retry policy, and selection were loaded; the decision artifact records roadmap `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, and the artifact-only boundary.
- Step 2, load dependency evidence from rounds 075-079: met. The artifact summarizes round 075 import inventory, round 076 behavior ownership, round 077 `AppServerClient` migration, round 078 `Core.Ids` migration, and round 079 EventLog/Permission hold evidence, and separates internal migration approval from public deprecation approval.
- Step 3, refresh selected-facade import inventory: met. Current counts are recorded and verified as 13, 35, 3, and 1 for the selected facades.
- Step 4, refresh replacement-module inventory: met. Replacement imports were scanned and treated only as preferred-import or migration-path evidence.
- Step 5, inspect facade definitions and current ownership: met. The artifact correctly classifies `AppServerClient` and `Core.Ids` as pure reexport facades and `Workflow.EventLog` and `Workflow.Permission` as mixed moifold bridge surfaces.
- Step 6, refresh Cabal and package-boundary evidence: met. `moifold.cabal` exposure of all four selected facades and package-candidate exposure of replacement modules are recorded accurately.
- Step 7, refresh docs, Haddock-facing wording, changelog, and release-note evidence: met. Docs scans, absence of source deprecation pragmas, and passing `cabal haddock all` evidence are recorded.
- Step 8, refresh local downstream inventory and optional GitHub code search: met. Local package-candidate scope and authenticated `soulomoon` owner-scoped GitHub search are described accurately; the artifact does not overstate owner-scoped search as external downstream proof.
- Step 9, refresh focused behavior-protection evidence: met. Behavior scan evidence is recorded for app-server protocol/failure formatting, id parsing/rendering, old-log/golden replay/event-log behavior, and permission/phase validation.
- Step 10, write deprecation-readiness decision artifact: met. The artifact contains active inputs, dependency evidence, import counts, replacement-path evidence, classifications, Cabal/docs/Haddock/downstream/behavior evidence, a per-surface decision table, missing gates, and explicit no-change confirmation.
- Step 11, choose defer or keep when evidence is incomplete: met. All four selected facades are `defer`; missing gates are treated as blockers, not approval.

### Decision
**APPROVED**

### Evidence
The artifact-only decision is evidence-backed and stays inside the selected facade scope. `CodexWatcher.AppServerClient` and `CodexWatcher.Core.Ids` have replacement-module paths and prior approved internal migration slices, but both still have current local facade imports and owner-scoped GitHub search hits. `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` have reusable core modules, but still expose moifold-specific bridge behavior and carry forward the round-079 hold.

`defer` rather than `deprecate` is justified for all four selected facades because preferred-import guidance, partial internal migration, and local/package-candidate inventory do not satisfy the policy gates for public deprecation wording, `DEPRECATED` pragmas, Cabal exposure changes, or removal. The artifact records that `cabal haddock all` passed and accurately notes that Haddock warnings plus absent source deprecation text are not deprecation-alignment evidence.

Tracked and staged diffs are empty for production code, tests, docs, Cabal/package descriptors, `orchestrator/state.json`, roadmap files, runtime compatibility files, event schemas, healthcheck, repair, import migrations, public wording, exposed modules, API/deprecation exposure, and removal. Before this review output, untracked files were limited to round-080 selection, plan, and decision artifacts.
