### Source Round
- Round id: `round-087`
- Merged commit: `51774b6`
- Evidence: `orchestrator/rounds/round-087/selection.md`,
  `orchestrator/rounds/round-087/plan.md`,
  `orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`,
  `orchestrator/rounds/round-087/implementation-notes.md`,
  `orchestrator/rounds/round-087/review.md`,
  `orchestrator/rounds/round-087/review-record.json`, and
  `orchestrator/rounds/round-087/merge.md`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed:
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`

### Rationale
Round 087 completed
`direction-005-compatibility-fixture-gap-inventory` as approved
artifact-only evidence. The merged inventory covers planning, daemon, block,
repair, runtime-owner, checked-in compatibility snapshots, and live
`issue-snapshot.json` surfaces, and records current producers/readers,
healthcheck reader and non-reader evidence, existing fixture coverage, policy
references, and prioritized blockers for later fixture and contract rounds.

This changes milestone 002 from untouched pending work to in-progress work,
but it does not satisfy the milestone completion signal. Fixture and test
coverage for selected old/current JSON shapes, an explicit reviewed
`planner-state.json` versus `planning-state.json` contract, healthcheck
behavior tests, and final cleanup classifications remain for later directions.

The roadmap update preserves the round boundary: the inventory is not
deprecation, facade removal, Cabal exposure removal, runtime compatibility-file
deletion or rename, healthcheck behavior approval, repair behavior approval,
release approval, or public compatibility removal approval.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
