### Checks Run
- Command: `test -f orchestrator/rounds/round-081/cabal-exposure-decision.md`
  Result: pass. The Cabal exposure decision artifact exists.
- Command: `test ! -e orchestrator/rounds/round-081/worker-plan.json`
  Result: pass. No worker fan-out artifact exists.
- Command: `git status --short --branch --untracked-files=all`
  Result: pass. Branch is `orchestrator/round-081-cabal-exposure-decision`; untracked files are limited to `orchestrator/rounds/round-081/cabal-exposure-decision.md`, `orchestrator/rounds/round-081/plan.md`, and `orchestrator/rounds/round-081/selection.md` before this review output.
- Command: `git ls-files --others --exclude-standard`
  Result: pass. Only the three round-081 local artifacts are untracked before this review output.
- Command: `git diff --name-only`
  Result: pass with no output. No tracked working-tree diff.
- Command: `git diff --cached --name-only`
  Result: pass with no output. No staged diff.
- Command: `git diff --name-only -- src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal cabal.project README.md docs orchestrator/state.json orchestrator/roadmaps`
  Result: pass with no output. No source, test, example, package-candidate, Cabal, docs, roadmap, or state tracked changes.
- Command: `git diff --cached --name-only -- src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal cabal.project README.md docs orchestrator/state.json orchestrator/roadmaps`
  Result: pass with no output. No staged source, test, example, package-candidate, Cabal, docs, roadmap, or state changes.
- Command: `git status --short --untracked-files=all -- moifold.cabal '*.cabal' agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal cabal.project src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs orchestrator/state.json orchestrator/roadmaps`
  Result: pass with no output. `moifold.cabal`, all checked package descriptors, source, tests, docs, roadmap files, and `orchestrator/state.json` are unchanged.
- Command: `git diff --check`
  Result: pass with no output.
- Command: `git diff --cached --check`
  Result: pass with no output.
- Command: `zsh -lc 'out=$(git diff --no-index --check -- /dev/null orchestrator/rounds/round-081/cabal-exposure-decision.md || true); test -z "$out"'`
  Result: pass. The new decision artifact has no whitespace errors.
- Command: `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))(?!\.)(\b| +as +| *$| +qualified| +\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass. Current exact selected-facade imports remain: 13 `AppServerClient`, 35 `Core.Ids`, 3 `Workflow.EventLog`, and 1 `Workflow.Permission`.
- Command: per-surface exact import scans for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`
  Result: pass. Counts and sites match the decision artifact; exact selected-facade imports remain in moifold source/test/app paths, not in package-candidate or example source.
- Command: replacement import scans for `Workflow.Agent.Codex.Client/Transport`, `Workflow.Agent/GitHub.Ids`, `Workflow.EventLog.Core/File.Core/Commit.Core`, and `Workflow.Permission.Core`
  Result: pass. Replacement modules are present and used, but this is migration-path evidence only.
- Command: `rg -n "^  exposed-modules:|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.(Agent|GitHub)\.Ids|Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)|Workflow\.Permission\.Core)" moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal`
  Result: pass. `moifold.cabal` still exposes all four selected facades; package descriptors expose the replacement modules. No exposed-module removal is present.
- Command: `sed -n '1,140p' src/CodexWatcher/AppServerClient.hs`; `sed -n '1,120p' src/CodexWatcher/Core/Ids.hs`; `sed -n '1,220p' src/CodexWatcher/Workflow/EventLog.hs`; `sed -n '1,220p' src/CodexWatcher/Workflow/Permission.hs`
  Result: pass. `AppServerClient` and `Core.Ids` are pure reexport facades; `Workflow.EventLog` and `Workflow.Permission` remain mixed moifold bridge surfaces with concrete moifold helpers.
- Command: `rg -n "workflowMoifoldCabalLibraryDoesNotReexportAdapters|exposed module|package boundary|agent-workflow-core|agent-workflow-codex|agent-workflow-github|moifold.cabal" test/Main.hs`
  Result: pass. Package-boundary and exposed-module inventory tests remain present.
- Command: `rg -n "^executable|^library|^test-suite|other-modules:|exposed-modules:" moifold.cabal`
  Result: pass. `moifold.cabal` still has the main library, `executable moifold`, and `watcher-core-test`; selected facades remain in the exposed-module list.
- Command: `find docs -path '*dist*' -prune -o -type f \( -iname '*.html' -o -iname '*.txt' -o -iname '*haddock*' \) -print | sort`
  Result: pass with no output. No checked-in generated docs/Haddock files were found under `docs`.
- Command: docs/source scans for selected facade mentions, deprecation/removal/preferred-import wording, and selected-facade source deprecation pragmas
  Result: pass. Docs contain compatibility/preferred-import policy, including explicit text that preferred-import guidance is not Cabal migration or removal approval. Selected source files contain no `DEPRECATED`, deprecation, compatibility-only, or preferred-import source signal.
- Command: downstream/operator scans over examples, package candidates, root docs, and Cabal descriptors
  Result: pass. No exact selected-facade imports in examples or package-candidate source; selected facades appear in `moifold.cabal` while package candidates expose replacement modules. Broad docs/package scans also show replacement modules.
- Command: `gh auth status`
  Result: pass. Authenticated to GitHub as `soulomoon`.
- Command: `gh search code "CodexWatcher.AppServerClient" --owner soulomoon --limit 100 --json repository,path --jq 'length'`
  Result: pass. Owner-scoped search returned `31`.
- Command: `gh search code "CodexWatcher.Core.Ids" --owner soulomoon --limit 100 --json repository,path --jq 'length'`
  Result: pass. Owner-scoped search returned `61`.
- Command: `gh search code "CodexWatcher.Workflow.EventLog" --owner soulomoon --limit 100 --json repository,path --jq 'length'`
  Result: pass. Owner-scoped search returned `0`.
- Command: `gh search code "CodexWatcher.Workflow.Permission" --owner soulomoon --limit 100 --json repository,path --jq 'length'`
  Result: pass. Owner-scoped search returned `0`.
- Command: `gh search code "CodexWatcher.AppServerClient" --owner soulomoon --limit 5`; `gh search code "CodexWatcher.Core.Ids" --owner soulomoon --limit 5`
  Result: pass. Samples were from `soulomoon/moifold`; the decision artifact correctly bounds this as owner-scoped and potentially stale relative to the local worktree, not complete external downstream proof.
- Command: focused behavior scans for app-server protocol/failure formatting, id parsing/rendering, event-log replay/repair/golden coverage, and permission/phase validation
  Result: pass. The scans found the expected protection points in `test/AppServerSpec.hs`, `test/CliSpec.hs`, `test/GhGitSpec.hs`, `test/RuntimeSpec.hs`, and `test/Main.hs`; no behavior code or tests were changed.
- Command: `rg -n "APPROVED|REJECTED|defer|Cabal|exposed-module|removal|deprecation|hold" orchestrator/rounds/round-077/review.md orchestrator/rounds/round-078/review.md orchestrator/rounds/round-079/review.md orchestrator/rounds/round-080/review.md orchestrator/rounds/round-080/deprecation-readiness-decision.md`
  Result: pass. Prior reviews approve internal migration/hold/deprecation-readiness artifacts only; none approve Cabal exposure removal.
- Command: `cabal haddock all`
  Result: pass. Haddock generated docs for `agent-workflow-core`, `agent-workflow-github`, `agent-workflow-codex`, and `moifold` under ignored `dist-newstyle`. Existing missing-documentation and unresolved-link warnings remain, including selected-surface-adjacent modules; Haddock success is recorded as exposure-generation evidence, not removal approval.
- Command: `cabal test watcher-core-test`
  Result: not run. This round changed only the round-local evidence artifact; focused scans and diffs showed no source, test, package descriptor, public API, Cabal exposure, docs, behavior, runtime compatibility, roadmap, or state changes. The plan permits skipping this baseline for artifact-only rounds under those conditions.
- Command: `cabal build all`
  Result: not run. Same artifact-only rationale as `watcher-core-test`; `cabal haddock all` provided the required Haddock-facing live package validation for this round.

### Plan Compliance
- Confirm active inputs, branch, and artifact boundary: met. Reviewer loaded `reviewer.md`, `state.json`, `project-contract.md`, active `verification.md`, active `retry-subloop.md`, `selection.md`, `plan.md`, and the decision artifact. Branch and roadmap lineage are correct: `2026-05-10-00-facade-removal-readiness`, `rev-001`, `round-081-cabal-exposure-decision`.
- Load dependency evidence from rounds 075-080: met. Decision artifact carries forward import counts, behavior-owner classification, approved internal migration slices, EventLog/Permission hold evidence, and round-080 public deprecation `defer` evidence. Review confirmed prior approvals do not include Cabal exposure removal approval.
- Refresh current import inventory: met. Live scans confirm all four selected facades still have exact local imports and the decision artifact records the counts accurately.
- Refresh replacement-module and Cabal exposure inventory: met. Replacement modules are exposed in package candidates, while `moifold.cabal` still exposes all four selected facades. No package descriptor changed.
- Inspect selected facade definitions and owners: met. Pure reexport vs mixed bridge classifications are accurate.
- Refresh package-boundary and descriptor blockers: met. Package-boundary tests remain present, `app/Main.hs` still imports `Core.Ids`, and no descriptor changes occurred.
- Refresh docs, public wording, and Haddock evidence: met. Docs/source scans and live `cabal haddock all` evidence are recorded. Existing policy wording does not authorize removal.
- Refresh downstream/operator inventory: met. Local and owner-scoped GitHub scans are recorded with correct bounded scope; owner-scoped search is not overstated as complete external downstream proof.
- Refresh focused behavior-protection evidence: met. Behavior scans found relevant tests and protection points; no behavior surface changed.
- Write artifact-only Cabal exposure decision: met. `cabal-exposure-decision.md` records active inputs, command log, dependency evidence, import/Cabal/docs/downstream/behavior evidence, four `defer` decisions, blockers, and explicit no-change confirmation.
- Choose `defer` or `keep` when evidence is incomplete: met. All four selected facades are `defer`; missing downstream, behavior, docs/Haddock, package-boundary, deprecation-readiness, and reviewer evidence are treated as blockers, not approval.

### Decision
**APPROVED**

### Evidence
The artifact-only Cabal exposure decision is evidence-backed and stays inside round scope. All four selected facades are explicitly `defer`: `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`. The artifact approves no exposed-module removal, no package descriptor change, and no future exact removal round by implication.

Tracked and staged diffs are empty for production code, tests, docs, Cabal/package descriptors, `orchestrator/state.json`, roadmap files, runtime compatibility files, event schemas, healthcheck, repair, import migrations, public wording, public API, exposure, and removal surfaces. Before this review output, untracked files were limited to the round-local `selection.md`, `plan.md`, and `cabal-exposure-decision.md`.

`moifold.cabal` remains unchanged and still exposes all four selected facades. Replacement modules are exposed by package-candidate descriptors, but that only proves a migration path. Current local imports remain for every selected facade, and owner-scoped GitHub search still finds indexed `soulomoon` results for `AppServerClient` and `Core.Ids`; the artifact accurately bounds that search rather than treating it as complete downstream proof.

`cabal haddock all` passed and generated current docs under ignored `dist-newstyle`, with existing missing-documentation and unresolved-link warnings. That satisfies this round's Haddock evidence requirement while still supporting `defer`, because source/docs/Cabal surfaces do not carry public deprecation or removal approval.

`cabal test watcher-core-test` and `cabal build all` were not necessary for this review because the implementation write was round-local evidence only and the review found no source, test, package descriptor, API, Cabal exposure, behavior, docs, runtime compatibility, roadmap, or state change. The active round plan allows skipping those baselines in exactly that artifact-only case.
