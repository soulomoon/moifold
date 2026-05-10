### Goal
Produce an artifact-only Cabal exposure decision for
`CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
`CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.

The round should decide whether each selected module's current exposure in
`moifold.cabal` should be kept, deferred for later evidence, or marked as a
future remove candidate. It must not edit `moifold.cabal`, any package
descriptor, exposed-module list, production code, tests, docs, roadmap files,
`orchestrator/state.json`, deprecation pragmas, public wording, runtime
compatibility files, event schemas, healthcheck, repair, imports, or facade
modules.

### Approach
Use one sequential evidence pass and write a single round-local decision
artifact:

`orchestrator/rounds/round-081/cabal-exposure-decision.md`

Worker fan-out is not justified. Cabal exposure status is a public boundary
decision that needs one integrated reading of prior rounds 075-080 plus current
`moifold.cabal`, import, docs/Haddock, downstream, package-boundary, and behavior
evidence.

Use `orchestrator/project-contract.md` and the active roadmap verification
bundle as authoritative. The previous `2026-05-09-01-compatibility-surface-cleanup`
terminal hold is not Cabal exposure, deprecation, migration, or removal
approval. Preferred-import guidance, partial local import migration, and local
absence of package-candidate imports are evidence, not approval by themselves.

Per selected facade, the artifact should assign exactly one status:

- `keep`: keep the facade exposed as an intended current public compatibility
  or product-facing surface.
- `defer`: keep the facade exposed for now because evidence is incomplete or
  blockers remain before a Cabal exposed-module change.
- `remove`: mark the facade as eligible for a later exact Cabal exposure removal
  round, with all gates named and satisfied. This status still must not edit
  `moifold.cabal` in round 081.

When evidence is incomplete, choose `defer` or `keep`; do not convert missing
downstream, behavior, docs/Haddock, package-boundary, or reviewer evidence into
`remove`.

### Steps
1. Confirm active inputs, branch, and artifact boundary:
   - `git status --short --branch --untracked-files=all`
   - `sed -n '1,220p' orchestrator/roles/implementer.md`
   - `sed -n '1,260p' orchestrator/state.json`
   - `sed -n '1,260p' orchestrator/project-contract.md`
   - `sed -n '1,260p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/verification.md`
   - `sed -n '1,260p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/retry-subloop.md`
   - `sed -n '1,260p' orchestrator/rounds/round-081/selection.md`
   Record roadmap `2026-05-10-00-facade-removal-readiness`, revision `rev-001`,
   extracted item `round-081-cabal-exposure-decision`, and the artifact-only
   boundary in the decision artifact.
2. Load dependency evidence from rounds 075-080:
   - `sed -n '1,360p' orchestrator/rounds/round-075/implementation-notes.md`
   - `sed -n '1,360p' orchestrator/rounds/round-076/implementation-notes.md`
   - `sed -n '1,300p' orchestrator/rounds/round-077/implementation-notes.md`
   - `sed -n '1,320p' orchestrator/rounds/round-078/implementation-notes.md`
   - `sed -n '1,420p' orchestrator/rounds/round-079/implementation-notes.md`
   - `sed -n '1,460p' orchestrator/rounds/round-080/deprecation-readiness-decision.md`
   - `sed -n '1,260p' orchestrator/rounds/round-077/review.md`
   - `sed -n '1,300p' orchestrator/rounds/round-078/review.md`
   - `sed -n '1,360p' orchestrator/rounds/round-079/review.md`
   - `sed -n '1,420p' orchestrator/rounds/round-080/review.md`
   Extract prior import counts, behavior-owner classifications, approved
   migration slices, EventLog/Permission hold evidence, public deprecation
   deferral evidence, and review decisions. The artifact must distinguish
   internal import migration approval from Cabal exposure removal approval.
3. Refresh exact selected-facade import inventory at current HEAD:
   - `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))(?!\\.)(\\b| +as +| *$| +qualified| +\\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.AppServerClient(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Core\\.Ids(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.EventLog(?!\\.)(\\b| +as +| *$| +qualified| +\\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.Permission(?!\\.)(\\b| +as +| *$| +qualified| +\\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   Record counts, files, and whether imports remain in `src`, `app`, `test`,
   `examples`, or package-candidate directories. Do not migrate imports.
4. Refresh replacement-module and package-candidate exposure inventory:
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.Agent\\.Codex\\.(Client|Transport)(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.EventLog\\.(Core|File\\.Core|Commit\\.Core)(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.Permission\\.Core(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^  exposed-modules:|CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission)|Workflow\\.Agent\\.Codex\\.(Client|Transport)|Workflow\\.(Agent|GitHub)\\.Ids|Workflow\\.EventLog\\.(Core|File\\.Core|Commit\\.Core)|Workflow\\.Permission\\.Core)" moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal`
   Record that `moifold.cabal` currently exposes each selected facade and which
   replacement modules are exposed by `agent-workflow-*` package candidates.
   Treat replacement exposure as migration-path evidence only.
5. Inspect selected facade definitions and owners:
   - `sed -n '1,140p' src/CodexWatcher/AppServerClient.hs`
   - `sed -n '1,120p' src/CodexWatcher/Core/Ids.hs`
   - `sed -n '1,220p' src/CodexWatcher/Workflow/EventLog.hs`
   - `sed -n '1,220p' src/CodexWatcher/Workflow/Permission.hs`
   - `sed -n '1,220p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`
   - `sed -n '1,220p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
   - `sed -n '1,200p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs`
   - `sed -n '1,200p' agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs`
   - `sed -n '1,240p' agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Core.hs`
   - `sed -n '1,220p' agent-workflow-core/src/CodexWatcher/Workflow/EventLog/File/Core.hs`
   - `sed -n '1,220p' agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Commit/Core.hs`
   - `sed -n '1,220p' agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`
   Record whether `AppServerClient` and `Core.Ids` remain pure reexport
   facades, and whether `Workflow.EventLog` and `Workflow.Permission` remain
   mixed moifold bridge surfaces with concrete moifold helpers.
6. Refresh Cabal/package-boundary and descriptor-change blockers:
   - `rg -n "workflowMoifoldCabalLibraryDoesNotReexportAdapters|exposed module|package boundary|agent-workflow-core|agent-workflow-codex|agent-workflow-github|moifold.cabal" test/Main.hs`
   - `rg -n "build-depends:|agent-workflow-core|agent-workflow-codex|agent-workflow-github" moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal`
   - `rg -n "^executable|^library|^test-suite|other-modules:|exposed-modules:" moifold.cabal`
   Record any caller that cannot import a replacement module without package
   descriptor changes. In particular, carry forward round-078 evidence if
   `app/Main.hs` or executable/package boundaries still block direct imports.
7. Refresh docs, public wording, and Haddock evidence without editing docs:
   - `find docs -path '*dist*' -prune -o -type f \\( -iname '*.html' -o -iname '*.txt' -o -iname '*haddock*' \\) -print | sort`
   - `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))" README.md docs agent-workflow-*/README.md examples/workflow-package-consumer/README.md`
   - `rg -n "deprecat|deprecated|DEPRECATED|remove-later|preferred import|preferred-import|compatibility facade|compatibility-only|exposed module|Cabal|cabal" README.md docs agent-workflow-*/README.md docs/agentic-workflow-framework/changelog.md docs/agentic-workflow-framework/release-notes.md docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
   - `rg -n -e "\\{-# DEPRECATED" -e "Deprecated:" -e "DEPRECATED" -e "deprecat" -e "compatibility-only" -e "preferred import" -e "preferred-import" src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Core/Ids.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Permission.hs || true`
   - `cabal haddock all`
   Record whether current docs, source comments, release notes, deprecation
   policy, and generated Haddock are aligned with keeping exposure, deferring
   exposure removal, or removing exposure later. If `cabal haddock all` fails or
   is environment-blocked, record the exact failure and treat Haddock approval as
   missing.
8. Refresh downstream/operator inventory:
   - `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))" examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))" examples agent-workflow-core agent-workflow-codex agent-workflow-github || true`
   - `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))" *.cabal agent-workflow-*/*.cabal examples/workflow-package-consumer/*.cabal`
   If `gh` is authenticated and available, also run:
   - `gh auth status`
   - `gh search code "CodexWatcher.AppServerClient" --owner soulomoon --limit 100 --json repository,path --jq 'length'`
   - `gh search code "CodexWatcher.Core.Ids" --owner soulomoon --limit 100 --json repository,path --jq 'length'`
   - `gh search code "CodexWatcher.Workflow.EventLog" --owner soulomoon --limit 100 --json repository,path --jq 'length'`
   - `gh search code "CodexWatcher.Workflow.Permission" --owner soulomoon --limit 100 --json repository,path --jq 'length'`
   - `gh search code "CodexWatcher.AppServerClient" --owner soulomoon --limit 5`
   - `gh search code "CodexWatcher.Core.Ids" --owner soulomoon --limit 5`
   Record the downstream scope exactly. Do not overstate owner-scoped GitHub
   search as complete external downstream proof.
9. Refresh focused behavior-protection evidence:
   - `rg -n "AppServer|app-server|formatAppServerClientFailure|decodeAppServerIncoming|parseThread|sendOneAppServerRequest|request-id|timeout" test src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src`
   - `rg -n "BranchName|CommitSha|IssueNumber|PrNumber|RepoName|RequestId|ReviewThreadId|ThreadId|TurnId|parse|render|nextRequestId" test src app agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs`
   - `rg -n "workflowEventLog|workflow event-log|goldenEventLog|golden event|eventLogRepair|replayEventLog|WorkflowTransitionFailure|WorkflowReplayFailure|EventReplayResult" test/Main.hs test/*Spec.hs`
   - `rg -n "workflowPermission|workflow permission|phaseActionValidation|phase action|validateMoifoldEffectPlan|moifoldPermissionPolicy|Permission" test/Main.hs test/*Spec.hs`
   Record the behavior coverage that would protect any future Cabal exposure
   removal, especially app-server protocol/failure formatting, identifier
   parsing/rendering, old-log/golden replay/event-log behavior, and
   permission/phase validation. Do not add, remove, or weaken tests.
10. Write `orchestrator/rounds/round-081/cabal-exposure-decision.md` with:
    - active input confirmation and command log;
    - dependency evidence summary from rounds 075-080;
    - current exact import inventory and current Cabal exposure status;
    - replacement-module exposure and migration-path evidence;
    - facade definition and behavior-owner classification;
    - package-boundary and descriptor-change blockers;
    - docs, public wording, source-Haddock, and generated-Haddock evidence;
    - local and optional GitHub downstream/operator inventory scope;
    - focused behavior-protection evidence;
    - per-surface decision table with status `keep`, `defer`, or `remove`;
    - for each `defer` or `keep`, exact blockers before any exposed-module
      change;
    - for any `remove`, exact evidence proving imports, downstream scope,
      package boundaries, behavior protection, docs/Haddock/public wording,
      deprecation readiness, and reviewer approval are sufficient for a later
      exact removal round;
    - explicit confirmation that no `moifold.cabal`, package descriptor,
      exposed-module list, production code, tests, docs, roadmap files,
      `orchestrator/state.json`, deprecation pragmas, public wording, runtime
      compatibility files, event schemas, healthcheck, repair, imports, or
      facade modules were changed.
11. If any selected facade lacks complete evidence for a future exposure
    removal, choose `defer` or `keep` and name the missing gate. Do not treat the
    round-080 `defer` deprecation decision as Cabal exposure removal approval.

### Verification
Because this is an artifact-only decision round, verify scope first:

- `test -f orchestrator/rounds/round-081/cabal-exposure-decision.md`
- `test ! -e orchestrator/rounds/round-081/worker-plan.json`
- `git status --short --branch --untracked-files=all`
- `git ls-files --others --exclude-standard`
- `git diff --name-only`
- `git diff --cached --name-only`
- `git diff --name-only -- src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal cabal.project README.md docs orchestrator/state.json orchestrator/roadmaps`
- `git diff --cached --name-only -- src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal cabal.project README.md docs orchestrator/state.json orchestrator/roadmaps`
- `git diff --check`
- `git diff --cached --check`
- `zsh -lc 'out=$(git diff --no-index --check -- /dev/null orchestrator/rounds/round-081/cabal-exposure-decision.md || true); test -z "$out"'`

Re-run the focused commands from the steps and make sure the decision artifact
records their results:

- selected facade import inventory;
- replacement-module import and exposure inventory;
- `moifold.cabal` exposed-module evidence;
- package-boundary and descriptor-change blockers;
- docs, public wording, and Haddock evidence;
- local and optional GitHub downstream/operator inventory;
- focused behavior-protection scan evidence.

Run `cabal haddock all` for the Haddock-facing evidence required by this round.
Run `cabal test watcher-core-test` and `cabal build all` only if anything outside
`orchestrator/rounds/round-081/cabal-exposure-decision.md` changes, if a focused
scan reveals behavior-surface uncertainty, or if the reviewer asks for a live
baseline. Otherwise, record why those baselines were not run: the implementation
write was round-local evidence only and no source, test, package descriptor,
public API, Cabal exposure, or behavior surface changed.

Reviewers should specifically confirm:

- all four selected facades remain exposed and unchanged in `moifold.cabal`;
- no exposed-module list, package descriptor, production code, tests, docs,
  public wording, roadmap, `orchestrator/state.json`, runtime compatibility,
  event schema, healthcheck, repair, deprecation pragma, import, or facade file
  changed;
- prior internal import migrations and preferred-import docs are not overstated
  as Cabal exposure removal approval;
- the round-079 hold and round-080 public deprecation `defer` evidence are
  carried forward accurately;
- any `remove` status names a later exact removal round and does not perform the
  removal in round 081.

### Worker Fan-Out
No worker fan-out. This is an artifact-only Cabal exposure decision with one
write target and shared evidence. Do not write `worker-plan.json`.
