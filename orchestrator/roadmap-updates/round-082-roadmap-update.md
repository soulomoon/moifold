### Source Round
- Round id: `round-082`
- Merged commit: `40ddd2a`
- Evidence: `orchestrator/rounds/round-082/review-record.json`,
  `orchestrator/rounds/round-082/review.md`, and
  `orchestrator/rounds/round-082/terminal-decision-report.md`

### Roadmap Change
- Roadmap id: `2026-05-10-00-facade-removal-readiness`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed:
  `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/roadmap.md`

### Rationale
Round 082 was reviewed and approved as the terminal decision report for
`direction-009-terminal-decision-report` under
`milestone-004-exact-removal-or-hold`. The approved report records
`CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
`CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission` as
kept available for now, deferred for public deprecation and Cabal exposure
removal, and blocked from exact removal by the named evidence gaps.

This closes milestone 004 through the terminal hold path, not through actual
removal. Direction 008 remains not run because milestone 003 did not approve an
exact selected facade, module, or exposed-module entry for removal. The
deprecated surface set is empty and the removed surface set is empty.

No exact removal, deprecation, Cabal exposure, package descriptor, production
source, test, documentation, public API, runtime compatibility, event schema,
healthcheck, repair, release, or publication change was approved by round 082.
No new roadmap revision is needed because the update is a status-only closeout
within the active `rev-001` coordination model.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
