# Roadmap History

Roadmap family: `2026-05-09-01-compatibility-surface-cleanup`

## Prior Family Context

- `2026-05-09-00-external-package-extraction` completed the external package
  extraction roadmap through round 051. It left the controller terminal with
  all five strategy-backlog milestones complete.
- The current package candidates are standalone local packages:
  `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`.
  `moifold` consumes them through package dependencies while preserving
  moifold-facing compatibility modules and runtime compatibility files.
- The terminal publication gate deliberately held publication because hosted
  CI was not observed, Haddock warnings remained, and no operator approval
  existed for external package upload.
- This family starts from the approved decision to move from publication
  extraction into compatibility-surface cleanup. Cleanup must be staged:
  inventory first, readiness evidence second, policy third, expansion review
  near the end of the initial todo list, and only then gated removals.

## Active Revision History

- `rev-001`: initial strategy-backlog family for evidence-first compatibility
  surface cleanup, with final removal allowed only behind explicit gates.
