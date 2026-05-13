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

## Revision History

- `rev-001` carried the original broad milestone sequence from the family
  scaffold through round 177. Detailed per-round status for the test topology,
  runtime compatibility fixture/contract work, AppServerClient import
  convergence, Core.Ids import convergence, and EventLog/Permission bridge
  work remains available in the rev-001 roadmap history in git and in the
  matching `orchestrator/roadmap-updates/round-083` through
  `orchestrator/roadmap-updates/round-177` artifacts.
- `rev-002` was introduced after round 177 because milestone 003 had become an
  overloaded bucket. The new revision keeps the same roadmap id and splits that
  work into finite milestones for production Core.Ids import burndown,
  test/fixture Core.Ids import burndown, EventLog/Permission bridge burndown,
  and AppServerClient public-surface cleanup. The existing large-module,
  runtime compatibility, and final removal milestones are preserved and
  renumbered after the split.
- Round 177 evidence: `src/CodexWatcher/EventLog/Replay.hs` moved from
  `CodexWatcher.Core.Ids (IssueNumber (..), ThreadId (..), TurnId (..))` to
  direct `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))` and
  `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`. Reviewer
  evidence passed `cabal build all`, focused replay/event-log watcher-core
  validation, full `cabal test watcher-core-test`, `git diff --check`,
  focused selected-file scans, direct-owner scans, and the broad remaining-user
  scan. This evidence supports the rev-002 split but does not approve public
  facade removal, Cabal exposure cleanup, runtime compatibility cleanup,
  release approval, milestone completion, terminal completion, or public
  compatibility removal.
