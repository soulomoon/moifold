### Squash Commit
- Title: Add workflow package consumer guide and example
- Summary: This round adds a standalone `examples/workflow-package-consumer` Cabal project and executable that demonstrate `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` through package-facing imports only. It also adds `docs/agentic-workflow-framework/package-consumer-guide.md` plus package README and framework index links so consumers can find the example while moifold-owned runtime, prompt policy, healthcheck, repair, event schema, compatibility, command execution, and release/publication responsibilities remain outside the reusable packages.

### Merge Readiness
- Base branch freshness: confirmed
- Merge ordering satisfied: yes; dependency rounds `round-036`, `round-039`, `round-040`, `round-041`, `round-042`, `round-045`, and `round-046` are completed on base, and both round `HEAD` and `codex/workflow-facade-extraction` resolve to `5967e29761298218d83cccb3220867b86ac7cf3b` before this staged payload.
- Pending dependencies: none

### Follow-Up Notes
Reviewer approval is recorded in `orchestrator/rounds/round-047/review.md`. Preserve the staged payload boundary during squash merge: root `cabal.project` and `orchestrator/state.json` are intentionally excluded. Changelog, release-note, release-gate, and publication decisions remain separate roadmap work, not part of this round.
