### Source Round
- Round id: round-031
- Merged commit: f36a9cc
- Evidence: `orchestrator/rounds/round-031/selection.md`,
  `orchestrator/rounds/round-031/plan.md`,
  `orchestrator/rounds/round-031/implementation-notes.md`,
  `orchestrator/rounds/round-031/review.md`,
  `orchestrator/rounds/round-031/review-record.json`,
  `orchestrator/rounds/round-031/merge.md`, and the squash commit `f36a9cc`.

### Roadmap Change
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/roadmap.md`

### Rationale
Round 031 completed `milestone-003-core-runtime-contracts` direction
`direction-007-daemon-core-boundary` for extracted item
`item-031-daemon-core-boundary`. The approved and merged work added
`WorkflowObservedDaemonTickFailure` and `workflowObservedDaemonTickFailure` as
an ownership-neutral projection in `agent-workflow-core`, then routed the
moifold `DaemonObservedTransactionFailure` compatibility wrapper through that
generic projection while keeping concrete daemon ownership in moifold.

The review evidence records passing validation for `cabal build all`,
`cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`,
a direct forbidden-token scan over `agent-workflow-core/src`, and cabal
boundary inspection confirming `agent-workflow-core` still exposes the generic
daemon core module and depends only on `base`, `bytestring`, and `text`.
Focused tests now cover moifold and DocsMigration daemon success projections,
generic observed failure projection behavior, retry/stop audit recommendation,
committed-event boundaries, report partitioning, and recursive package-boundary
guards.

This update marks direction 007 complete and marks milestone 003 complete
because round 030 already completed transaction-law coverage and round 031 now
completes the remaining daemon-boundary work. It does not change future
milestone dependencies, candidate direction boundaries, parallel lanes, retry
semantics, roadmap metadata, or active revision activation. The next roadmap
work remains under later pending adapter API and extraction-readiness
milestones.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
