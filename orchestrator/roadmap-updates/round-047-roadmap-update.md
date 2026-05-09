### Source Round
- Round id: round-047
- Merged commit: 822e3bf Add workflow package consumer guide and example
- Evidence: `orchestrator/rounds/round-047/selection.md` selected `milestone-004-public-docs-examples`, `direction-012-examples-and-consumer-guides`, and `item-047-examples-and-consumer-guides`; `orchestrator/rounds/round-047/review-record.json` records approved status and passing evidence for staged-scope inspection, standalone example build/run, root build, `watcher-core-test`, Haddock, workflow package validation, whitespace checks, forbidden import scan, and release/ownership wording scan; `orchestrator/rounds/round-047/review.md` records the detailed checks; `orchestrator/rounds/round-047/merge.md` records the squash title `Add workflow package consumer guide and example` and confirms the round added a standalone `examples/workflow-package-consumer` Cabal project/executable, package consumer guide, and README/index links while keeping moifold-owned runtime, prompt policy, healthcheck, repair, event schema, compatibility, command execution, and release/publication responsibilities outside the reusable packages.

### Roadmap Change
- Roadmap id: 2026-05-09-00-external-package-extraction
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/roadmap.md`

### Rationale
Round 047 satisfies `direction-012-examples-and-consumer-guides`: consumers now have a standalone local Cabal example that builds and runs against `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` through package-facing imports, plus a focused consumer guide and discoverability links from package/framework docs. The approved evidence confirms the example does not depend on `moifold`, does not import compatibility facades, and does not move product-owned runtime, prompt policy, healthcheck, repair, event schema, compatibility-file, command-execution, or release/publication responsibilities into the reusable packages.

This is a status-only update to the active `rev-001` roadmap because the merged round changes completion state and evidence, not future coordination semantics, sequencing, milestone boundaries, release policy, or active revision metadata. Direction 012 is complete, but milestone 004 remains in progress because `direction-013-changelog-and-release-notes` is still pending. Milestone 005 remains pending until public docs/examples and changelog/release-note work are complete and consumer validation plus release-gate work can run.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
