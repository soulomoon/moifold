### Goal
Produce an artifact-only terminal decision report for
`2026-05-10-00-facade-removal-readiness` round 082, closing
`direction-009-terminal-decision-report` by preserving the reviewed evidence
from rounds 075-081 and explicitly recording the final kept, deferred,
deprecated, removed, and blocked surface sets for:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Permission`

The report must not perform or approve any production source, test, docs,
Cabal/package descriptor, roadmap, `orchestrator/state.json`, import migration,
deprecation, exposed-module removal, facade deletion, runtime compatibility,
event schema, healthcheck, repair, release, or publication change.

### Approach
Write a single round-local implementation artifact,
`orchestrator/rounds/round-082/terminal-decision-report.md`. Reuse the active
roadmap bundle and dependency evidence instead of rescanning or rebuilding the
project unless a contradiction is found in the existing reviewed artifacts.

The report should treat rounds 075-081 as the evidence base:

- Round 075: current facade inventory and initial blockers.
- Round 076: behavior-owner classification.
- Round 077: approved narrow `CodexWatcher.AppServerClient` import migration,
  leaving the facade live and unchanged.
- Round 078: approved narrow `CodexWatcher.Core.Ids` split-import migration,
  leaving the facade live and unchanged.
- Round 079: approved artifact-only hold for
  `CodexWatcher.Workflow.EventLog` and
  `CodexWatcher.Workflow.Permission`.
- Round 080: approved artifact-only public deprecation `defer` for all four
  selected facades.
- Round 081: approved artifact-only Cabal exposure `defer` for all four
  selected facades.

The final decision posture should be conservative and explicit:

- `deferred`: all four selected facades.
- `deprecated`: empty.
- `removed`: empty, unless the implementer finds already-reviewed evidence
  created before this selection that names an exact approved removal surface.
- `blocked`: all four selected facades, with blockers copied from the reviewed
  evidence rather than inferred from local absence.
- `kept`: all four selected facades remain kept available/exposed for now as
  compatibility facades because the current approved decision is defer; do not
  describe this as a permanent keep decision or as release approval.

Do not create `worker-plan.json`. This is a sequential artifact-only round, and
worker fan-out is not justified.

### Steps
1. Confirm the active inputs still match this plan: branch
   `orchestrator/round-082-terminal-decision-report`, selection
   `round-082-terminal-decision-report`, roadmap id
   `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, and the
   project-contract rule that public compatibility facades stay available until
   safe removal is proven with import, build, and behavior coverage.
2. Read the dependency artifacts from rounds 075-081, prioritizing the
   implementation notes/decision artifacts and reviews. Preserve their
   reviewed conclusions; do not reinterpret a hold, preferred-import note, or
   local import reduction as removal approval.
3. Write `orchestrator/rounds/round-082/terminal-decision-report.md` with:
   - roadmap lineage, selected item, worktree/branch, and artifact-only scope;
   - command log showing the inputs and dependency evidence read;
   - dependency evidence table for rounds 075-081;
   - final surface-set summary for kept, deferred, deprecated, removed, and
     blocked surfaces;
   - per-surface decision rows for the four selected facades, including current
     approved status, kept-available rationale, blockers, and what is not
     approved;
   - explicit statement that no exact removal surface is currently approved and
     that the removed-surface set is empty unless pre-selection reviewed
     evidence proves otherwise;
   - explicit statement that the report approves no public deprecation signal,
     `DEPRECATED` pragma, public wording, Cabal exposure removal, package
     descriptor edit, public API change, facade deletion, import migration,
     runtime compatibility change, event schema change, healthcheck/repair
     change, release, or publication.
4. For `CodexWatcher.AppServerClient`, carry forward that it is a pure reexport
   facade with replacement imports in
   `CodexWatcher.Workflow.Agent.Codex.Client` and
   `CodexWatcher.Workflow.Agent.Codex.Transport`, but remains deferred because
   local facade imports, owner-scoped downstream evidence limits, public
   deprecation/Cabal alignment, and focused app-server behavior validation
   still block deprecation or removal.
5. For `CodexWatcher.Core.Ids`, carry forward that it is a pure reexport facade
   over `CodexWatcher.Workflow.Agent.Ids` and
   `CodexWatcher.Workflow.GitHub.Ids`, but remains deferred because local
   facade imports, mixed/executable/package-boundary users, owner-scoped
   downstream evidence limits, parser/rendering validation, and public
   deprecation/Cabal alignment still block deprecation or removal.
6. For `CodexWatcher.Workflow.EventLog`, carry forward that it is a mixed
   moifold bridge surface with generic replacement modules available, but
   remains deferred/blocked because it still carries concrete moifold helpers
   over `WatcherEvent`, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`,
   and exact removal would need reviewed split, old-log/golden/replay,
   downstream/public API, docs/Haddock, and Cabal evidence.
7. For `CodexWatcher.Workflow.Permission`, carry forward that reusable
   permission core exists, but the facade remains deferred/blocked because it
   still exposes concrete moifold phase-validation helpers and state-machine
   error formatting, and exact removal would need reviewed public API,
   downstream, permission/phase-validation, docs/Haddock, and Cabal evidence.
8. Record that no baseline build/test is required for this artifact-only
   implementation unless the implementer touches source, tests, docs, package
   descriptors, public API, exposed modules, runtime compatibility, roadmap, or
   state files. If any such file would be touched, stop instead of broadening
   the round.

### Verification
- `test -f orchestrator/rounds/round-082/terminal-decision-report.md`
- `test ! -e orchestrator/rounds/round-082/worker-plan.json`
- `rg -n "kept|deferred|deprecated|removed|blocked|Removed surface set|removed-surface" orchestrator/rounds/round-082/terminal-decision-report.md`
- `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))" orchestrator/rounds/round-082/terminal-decision-report.md`
- `rg -n "round-075|round-076|round-077|round-078|round-079|round-080|round-081" orchestrator/rounds/round-082/terminal-decision-report.md`
- `git diff --check`
- `git diff --no-index --check -- /dev/null orchestrator/rounds/round-082/terminal-decision-report.md`
- `git status --short -uall`

`cabal build all` and `cabal test watcher-core-test` are intentionally not part
of the expected verification for this round because the planned implementation
is a round-local artifact-only report. If the implementation changes anything
outside `orchestrator/rounds/round-082/terminal-decision-report.md`, that is a
plan violation rather than a reason to broaden validation.
