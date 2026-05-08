### Source Round
- Round id: round-042
- Merged commit: 14f84a4 Wire moifold to standalone workflow packages
- Evidence: `orchestrator/rounds/round-042/selection.md` selected `milestone-002-standalone-package-layout`, `direction-007-moifold-local-consumer-wiring`, and `item-042-moifold-local-consumer-wiring`; `orchestrator/rounds/round-042/review.md` approved the implementation after standalone package builds, moifold product builds, `cabal build all`, `cabal test watcher-core-test`, boundary scans, and `git diff --check` passed; `orchestrator/rounds/round-042/review-record.json` records approved status and the standalone consumer-wiring evidence; `orchestrator/rounds/round-042/merge.md` records the squash merge and notes that the round closes the remaining standalone package layout direction for milestone 002 without broadening into release validation.

### Roadmap Change
- Roadmap id: 2026-05-09-00-external-package-extraction
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/roadmap.md`

### Rationale
Round 042 satisfies `direction-007-moifold-local-consumer-wiring`: moifold and `watcher-core-test` now consume the local standalone `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates with approved `>=0.1 && <0.2` bounds, the internal `moifold:agent-workflow-*` sublibrary wiring is absent, compatibility facades remain available, package-boundary scans pass, and the full behavior checks recorded by the reviewer passed.

This is a status-only update to the active `rev-001` roadmap because the merged round changes completion state, not future coordination semantics. Directions 004, 005, 006, and 007 are now complete, so milestone 002's completion signal is satisfied: the three workflow packages have standalone descriptors or equivalent build surfaces, moifold consumes them locally, package-boundary assertions are in place, and current behavior still passes. Milestone 003 remains pending because package check/source distribution, CI matrix, Haddock, docs, and release-validation work were explicitly out of scope for round 042.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
