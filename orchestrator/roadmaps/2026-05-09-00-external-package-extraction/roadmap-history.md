# Roadmap History

Roadmap family: `2026-05-09-00-external-package-extraction`

## Prior Family Context

- `2026-05-08-00-framework-kernel-migration` completed the internal framework
  kernel migration through round 035. It left the controller terminal with all
  five strategy-backlog milestones complete.
- The completed internal package shape is `agent-workflow-core`,
  `agent-workflow-codex`, and `agent-workflow-github` under `moifold.cabal`.
  The package extraction readiness report records structural readiness, current
  import-graph evidence, dependency ownership, compatibility facades, and
  remaining moifold-owned blockers.
- This family starts from the approved decision to proceed toward real external
  package extraction through release-gated packaging, CI, documentation,
  consumer validation, and explicit release approval. It must not move moifold
  lifecycle/runtime policy into reusable packages.

## Active Revision History

- `rev-001`: initial strategy-backlog family for release-gated external package
  extraction of the three `agent-workflow-*` libraries.
