### Changes Made
- `orchestrator/rounds/round-082/terminal-decision-report.md`: added the artifact-only terminal decision report for roadmap `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, selected item `round-082-terminal-decision-report`.
- `orchestrator/rounds/round-082/implementation-notes.md`: recorded implementation scope, verification, and reviewer notes for this artifact-only round.

No production code, tests, docs, README, Cabal/package descriptors,
exposed-module lists, roadmap files, `orchestrator/state.json`, runtime
compatibility files, event schemas, healthcheck, repair, import migrations,
deprecation pragmas, public wording, facade deletions, release decisions,
publication decisions, or `worker-plan.json` were changed or created.

### Tests
- `test -f orchestrator/rounds/round-082/terminal-decision-report.md`: verifies the required terminal decision artifact exists.
- `test ! -e orchestrator/rounds/round-082/worker-plan.json`: verifies the round did not create worker fan-out state.
- `rg -n "kept|deferred|deprecated|removed|blocked|Removed surface set|removed-surface" orchestrator/rounds/round-082/terminal-decision-report.md`: verifies the report explicitly names the required final surface-set categories.
- `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))" orchestrator/rounds/round-082/terminal-decision-report.md`: verifies the report covers all four selected facades.
- `rg -n "round-075|round-076|round-077|round-078|round-079|round-080|round-081" orchestrator/rounds/round-082/terminal-decision-report.md`: verifies dependency evidence from rounds 075-081 is recorded.
- `git diff --check`: verifies tracked diff whitespace.
- `git diff --no-index --check -- /dev/null orchestrator/rounds/round-082/terminal-decision-report.md`: produced no whitespace output. As expected for a no-index comparison against a new file, raw exit status was `1`; a wrapper check verified there was no `--check` output and no exit status above `1`.
- `git diff --no-index --check -- /dev/null orchestrator/rounds/round-082/implementation-notes.md`: produced no whitespace output. As expected for a no-index comparison against a new file, raw exit status was `1`; a wrapper check verified there was no `--check` output and no exit status above `1`.
- `git status --short -uall`: verifies only round-local artifacts are untracked/changed.
- `find orchestrator/rounds/round-082 -maxdepth 1 -type f -print | sort`: verified the round directory contains only `plan.md`, `selection.md`, `terminal-decision-report.md`, and `implementation-notes.md`.

`cabal build all` and `cabal test watcher-core-test` were intentionally not run
because the plan defines this as a round-local artifact-only implementation and
no source, test, package descriptor, public API, exposed module, docs, runtime
compatibility, roadmap, or state surface was touched.

### Notes
The report carries forward the reviewed dependency conclusions instead of
rescanning production code:

- `round-075`: current inventory and initial blockers.
- `round-076`: behavior-owner classification.
- `round-077`: approved narrow `CodexWatcher.AppServerClient` import migration,
  leaving the facade live and unchanged.
- `round-078`: approved narrow `CodexWatcher.Core.Ids` split-import migration,
  leaving the facade live and unchanged.
- `round-079`: approved artifact-only hold for
  `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission`.
- `round-080`: approved artifact-only public deprecation `defer` for all four
  selected facades.
- `round-081`: approved artifact-only Cabal exposure `defer` for all four
  selected facades.

Final report posture:

- Kept: all four selected facades remain available/exposed for now as
  compatibility facades.
- Deferred: all four selected facades.
- Deprecated: empty.
- Removed: empty.
- Blocked: all four selected facades, with blockers copied from reviewed
  evidence.

The empty deprecated and removed sets are intentional. No exact removal,
deprecation, public wording, Cabal exposure removal, package descriptor edit,
public API change, facade deletion, import migration, runtime compatibility
change, event schema change, healthcheck/repair change, release, or publication
is approved by this round.
