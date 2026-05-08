### Source Round
- Round id: round-036
- Merged commit: 56b5a02
- Evidence: `orchestrator/rounds/round-036/selection.md`,
  `orchestrator/rounds/round-036/plan.md`,
  `orchestrator/rounds/round-036/implementation-notes.md`,
  `orchestrator/rounds/round-036/review.md`,
  `orchestrator/rounds/round-036/review-record.json`,
  `orchestrator/rounds/round-036/merge.md`, the squash commit `56b5a02`,
  `docs/agentic-workflow-framework/package-identity-versioning-contract.md`,
  and the narrow README discoverability link.

### Roadmap Change
- Roadmap id: 2026-05-09-00-external-package-extraction
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/roadmap.md`

### Rationale
Round 036 completed `milestone-001-package-identity-release-contract`
direction `direction-001-package-names-and-versioning` for extracted item
`item-036-package-names-versioning-contract`. The approved and merged work
added a source-backed package identity and versioning contract for the future
external `agent-workflow-core`, `agent-workflow-codex`, and
`agent-workflow-github` package candidates, then linked it from the framework
README for discoverability.

The review evidence records passing `cabal build all`,
`cabal test watcher-core-test`, `git diff --check`, and
`git diff --cached --check`. It also records source-backed inspection of
`moifold.cabal`, current exposed module namespaces, the package extraction
readiness report, the implemented API freeze, the project contract, and the
new identity contract's release-gate limits.

This update marks direction 001 complete and moves milestone 001 to
in-progress. The milestone completion signal is not yet satisfied because
release metadata policy and compatibility/deprecation policy remain pending.
The round did not change Cabal descriptors, Haskell source, tests, generated
fixtures, release notes, changelogs, compatibility facades, source layout,
package descriptors, publication state, roadmap sequencing, dependencies,
parallel lanes, release policy, active revision metadata, or future
coordination semantics. Therefore the active rev-001 roadmap remains the
correct coordination surface and no new roadmap revision is justified.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
