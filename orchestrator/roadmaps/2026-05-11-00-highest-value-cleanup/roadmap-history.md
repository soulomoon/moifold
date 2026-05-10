# Highest-Value Cleanup Roadmap History

Roadmap id: `2026-05-11-00-highest-value-cleanup`

## Prior Family Context

- `2026-05-10-00-facade-removal-readiness` ended at `round-082` with
  `controller_stage=done`, no active rounds, and no pending roadmap update.
- The prior family completed a terminal decision report, not a removal round.
  `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
  `CodexWatcher.Workflow.EventLog`, and
  `CodexWatcher.Workflow.Permission` remain available and exposed for now.
- Deprecated surface set: empty.
- Removed surface set: empty.
- `direction-008-exact-approved-removal` was explicitly not run because no
  exact selected facade, module, or Cabal exposed-module entry had approval.

## Scaffold Notes

This family is a fresh `next-family` scaffold for broad cleanup. It does not
reopen the held facade-removal-readiness family and does not convert a terminal
hold into deprecation or removal approval.
