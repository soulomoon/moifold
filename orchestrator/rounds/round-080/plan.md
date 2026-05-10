### Goal
Produce an artifact-only public deprecation readiness decision for
`CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
`CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.

The round should decide whether each selected public facade is ready for any
public deprecation signal now, or whether deprecation must remain deferred or
declined with explicit blockers. It must not edit production code, tests,
docs, Haddock text, changelog/release-note text, Cabal/package descriptors,
roadmap files, `orchestrator/state.json`, deprecation pragmas, exposed modules,
public wording, runtime compatibility files, event schemas, healthcheck, repair,
or facade availability.

### Approach
Use a single sequential evidence pass. Worker fan-out is not justified because
this is an artifact-only decision, all four selected surfaces share the same
docs/Cabal/downstream inventory, and the only implementation write should be a
round-local evidence artifact.

The implementer should write
`orchestrator/rounds/round-080/deprecation-readiness-decision.md`. The artifact
must cite rounds 075-079, refresh current HEAD evidence, and assign each facade
one of `keep`, `defer`, or `deprecate`. Use `defer` when preferred imports or
partial internal migrations exist but public deprecation gates are incomplete.
Use `keep` only when the current facade remains an intended product-facing
surface rather than a deprecation candidate. Use `deprecate` only if current
evidence satisfies every gate in `verification.md` and
`docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.

Treat `orchestrator/project-contract.md` and the active roadmap verification
bundle as authoritative. In particular, the closed
`2026-05-09-01-compatibility-surface-cleanup` terminal hold is not deprecation,
migration, Cabal exposure, or removal approval, and local absence or reduction
of imports is not enough to deprecate or remove an exposed public module.

### Steps
1. Confirm active inputs and scope:
   - `git status --short --branch --untracked-files=all`
   - `sed -n '1,260p' orchestrator/state.json`
   - `sed -n '1,240p' orchestrator/project-contract.md`
   - `sed -n '1,260p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/verification.md`
   - `sed -n '1,220p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/retry-subloop.md`
   - `sed -n '1,240p' orchestrator/rounds/round-080/selection.md`
   Record roadmap `2026-05-10-00-facade-removal-readiness`, revision `rev-001`,
   extracted item `round-080-public-deprecation-readiness-decision`, and the
   artifact-only boundary in the decision artifact.
2. Load dependency evidence from rounds 075-079:
   - `sed -n '1,320p' orchestrator/rounds/round-075/implementation-notes.md`
   - `sed -n '1,320p' orchestrator/rounds/round-076/implementation-notes.md`
   - `sed -n '1,260p' orchestrator/rounds/round-077/implementation-notes.md`
   - `sed -n '1,260p' orchestrator/rounds/round-078/implementation-notes.md`
   - `sed -n '1,360p' orchestrator/rounds/round-079/implementation-notes.md`
   - `sed -n '1,260p' orchestrator/rounds/round-077/review.md`
   - `sed -n '1,260p' orchestrator/rounds/round-078/review.md`
   - `sed -n '1,320p' orchestrator/rounds/round-079/review.md`
   Extract the prior import counts, behavior-owner classifications, approved
   migration slices, remaining blockers, and review decisions. The artifact
   should explicitly distinguish prior approved internal import migrations from
   public deprecation approval.
3. Refresh current selected-facade import inventory at HEAD:
   - `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))(?!\\.)(\\b| +as +| *$| +qualified| +\\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.AppServerClient(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Core\\.Ids(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.EventLog(?!\\.)(\\b| +as +| *$| +qualified| +\\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.Permission(?!\\.)(\\b| +as +| *$| +qualified| +\\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   Record exact current import counts, current import sites, and whether any
   selected facade imports remain in standalone package candidates or examples.
   Do not migrate imports.
4. Refresh direct replacement-module inventory:
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.Agent\\.Codex\\.(Client|Transport)(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.EventLog\\.(Core|File\\.Core|Commit\\.Core)(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.Permission\\.Core(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   Use this only as preferred-import or migration-path evidence. Do not treat it
   as deprecation or removal approval.
5. Inspect facade definitions and current ownership:
   - `sed -n '1,120p' src/CodexWatcher/AppServerClient.hs`
   - `sed -n '1,100p' src/CodexWatcher/Core/Ids.hs`
   - `sed -n '1,180p' src/CodexWatcher/Workflow/EventLog.hs`
   - `sed -n '1,160p' src/CodexWatcher/Workflow/Permission.hs`
   - `sed -n '1,220p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`
   - `sed -n '1,220p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
   - `sed -n '1,180p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs`
   - `sed -n '1,180p' agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs`
   - `sed -n '1,220p' agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Core.hs`
   - `sed -n '1,180p' agent-workflow-core/src/CodexWatcher/Workflow/EventLog/File/Core.hs`
   - `sed -n '1,180p' agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Commit/Core.hs`
   - `sed -n '1,180p' agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`
   Classify `AppServerClient` and `Core.Ids` as pure reexport facades only if
   the definitions remain wrapper-only. Classify `Workflow.EventLog` and
   `Workflow.Permission` as mixed surfaces if they still expose moifold-specific
   bridge helpers over concrete moifold event/state/effect/spec or
   phase-validation types.
6. Refresh Cabal and package-boundary evidence without changing descriptors:
   - `rg -n "^  exposed-modules:|CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission)|Workflow\\.Agent\\.Codex\\.(Client|Transport)|Workflow\\.(Agent|GitHub)\\.Ids|Workflow\\.EventLog\\.(Core|File\\.Core|Commit\\.Core)|Workflow\\.Permission\\.Core)" moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal`
   - `rg -n "workflowMoifoldCabalLibraryDoesNotReexportAdapters|exposed module|package boundary|agent-workflow-core|agent-workflow-codex|agent-workflow-github" test/Main.hs`
   Record which selected facades remain exposed by `moifold.cabal`, which
   replacement modules are exposed by package candidates, and whether executable
   or package dependency boundaries still block direct imports for any caller.
7. Refresh docs, Haddock-facing wording, changelog, and release-note evidence:
   - `find docs -path '*dist*' -prune -o -type f \\( -iname '*.html' -o -iname '*.txt' -o -iname '*haddock*' \\) -print | sort`
   - `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))" README.md docs agent-workflow-*/README.md examples/workflow-package-consumer/README.md`
   - `rg -n "deprecat|deprecated|DEPRECATED|remove-later|preferred import|preferred-import|compatibility facade|compatibility-only" README.md docs agent-workflow-*/README.md docs/agentic-workflow-framework/changelog.md docs/agentic-workflow-framework/release-notes.md docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
   - `rg -n "{-# DEPRECATED|Deprecated:|DEPRECATED|deprecat|compatibility-only|preferred import|preferred-import" src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Core/Ids.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Permission.hs`
   - `cabal haddock all`
   Record whether generated or source Haddock contains any deprecation signal,
   whether docs/changelog/release notes currently describe preferred imports or
   compatibility status, and whether Haddock generation passes. If
   `cabal haddock all` is too slow or environment-blocked, record the exact
   command, failure, and that no Haddock-based approval was obtained.
8. Refresh local downstream inventory:
   - `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))" examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))" examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))" *.cabal agent-workflow-*/*.cabal examples/workflow-package-consumer/*.cabal`
   If `gh` is authenticated and available, also run:
   - `gh search code "CodexWatcher.AppServerClient" --owner soulomoon --limit 100`
   - `gh search code "CodexWatcher.Core.Ids" --owner soulomoon --limit 100`
   - `gh search code "CodexWatcher.Workflow.EventLog" --owner soulomoon --limit 100`
   - `gh search code "CodexWatcher.Workflow.Permission" --owner soulomoon --limit 100`
   Record the downstream scope precisely. If GitHub code search is unavailable,
   record that only local in-repo/package-candidate downstream inventory was
   checked and that external downstream evidence remains missing.
9. Refresh focused behavior-protection evidence for any deprecation decision:
   - `rg -n "AppServer|app-server|formatAppServerClientFailure|decodeAppServerIncoming|parseThread|sendOneAppServerRequest|request-id|timeout" test src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src`
   - `rg -n "BranchName|CommitSha|IssueNumber|PrNumber|RepoName|RequestId|ReviewThreadId|ThreadId|TurnId|parse|render|nextRequestId" test src app agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs`
   - `rg -n "workflowEventLog|workflow event-log|goldenEventLog|golden event|eventLogRepair|replayEventLog|WorkflowTransitionFailure|WorkflowReplayFailure" test/Main.hs test/*Spec.hs`
   - `rg -n "workflowPermission|workflow permission|phaseActionValidation|phase action|validateMoifoldEffectPlan|moifoldPermissionPolicy|Permission" test/Main.hs test/*Spec.hs`
   Record which tests protect app-server protocol/failure formatting, identifier
   parsing/rendering, old-log/golden replay, event-log core parity, permission
   parity, and phase validation. Do not add or change tests.
10. Write `orchestrator/rounds/round-080/deprecation-readiness-decision.md`
    with:
    - active input confirmation and command log;
    - dependency evidence summary from rounds 075-079;
    - current per-surface import counts and import sites;
    - current replacement-module and migration-path evidence;
    - current facade definition and behavior-owner classification;
    - Cabal exposure and package-boundary evidence;
    - docs, source-Haddock, changelog, release-note, and generated-Haddock
      evidence;
    - local and optional GitHub downstream inventory scope;
    - protecting behavior-test evidence;
    - a per-surface decision table for the four selected facades with status
      `keep`, `defer`, or `deprecate`;
    - for each non-`deprecate` status, explicit missing gates before any public
      deprecation wording, `DEPRECATED` pragma, exposed-module change, or
      removal;
    - for any `deprecate` status, exact evidence proving preferred imports,
      downstream inventory, behavior coverage, docs/Haddock/changelog/Cabal
      alignment, package-boundary approval, and reviewer approval are sufficient;
    - explicit confirmation that no production code, tests, docs, Haddock text,
      changelog/release-note text, Cabal/package descriptors, roadmap files,
      `orchestrator/state.json`, deprecation pragmas, public wording, exposed
      modules, runtime compatibility files, event schemas, healthcheck, repair,
      import migrations, or facade removals were changed.
11. If evidence is incomplete, choose `defer` or `keep` with blockers. Do not
    convert missing evidence into public deprecation approval.

### Verification
Because this is an artifact-only decision round, first verify artifact scope:

- `test -f orchestrator/rounds/round-080/deprecation-readiness-decision.md`
- `test ! -e orchestrator/rounds/round-080/worker-plan.json`
- `git status --short --branch --untracked-files=all`
- `git diff --name-only`
- `git diff --name-only -- src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal cabal.project README.md docs orchestrator/state.json orchestrator/roadmaps`
- `git diff --cached --name-only -- src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal cabal.project README.md docs orchestrator/state.json orchestrator/roadmaps`
- `git diff --check`
- `zsh -lc 'out=$(git diff --no-index --check -- /dev/null orchestrator/rounds/round-080/deprecation-readiness-decision.md || true); test -z "$out"'`

Re-run the focused evidence commands from the steps and ensure the artifact
records their results, especially:

- selected facade import inventory;
- replacement-module import inventory;
- Cabal exposed-module scan;
- docs/Haddock/changelog/release-note scan;
- local downstream inventory scan;
- focused behavior-protection test scan.

Run `cabal haddock all` as the Haddock-facing validation for this decision. Run
`cabal test watcher-core-test` only if the implementer edits anything outside
`orchestrator/rounds/round-080/deprecation-readiness-decision.md`, if Haddock or
inventory checks reveal behavior-surface uncertainty, or if the reviewer asks
for a live behavior baseline. Otherwise, record why Cabal tests were not run:
the implementation write was round-local evidence only and no source/test/API
surface changed.

Reviewers should specifically confirm:

- all four selected facades remain available and unchanged;
- no production code, tests, docs, Haddock text, changelog/release-note text,
  package descriptors, roadmap files, `orchestrator/state.json`, runtime
  compatibility files, event schemas, healthcheck, repair, import migrations,
  deprecation pragmas, public wording, exposed modules, or facade removals
  changed;
- `AppServerClient` and `Core.Ids` partial import migrations are not overstated
  as public deprecation approval;
- `Workflow.EventLog` and `Workflow.Permission` hold evidence from round 079 is
  carried forward unless current evidence genuinely proves otherwise;
- the decision does not use local import absence, preferred-import guidance,
  release notes, or the prior terminal hold as removal or deprecation approval.

### Worker Fan-Out
No worker fan-out. This is an artifact-only public deprecation readiness
decision with one write target and shared verification; do not write
`worker-plan.json`.
