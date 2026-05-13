### Source Round
- Round id: round-187
- Merged commit: bb9b679
- Evidence: `orchestrator/rounds/round-187/selection.md`, `plan.md`,
  `implementation-notes.md`, `review.md`, `review-record.json`, and
  `merge.md`. Reviewer evidence approved the import-only migration of
  `test/TestSupport/Workflow.hs` from `CodexWatcher.Core.Ids` to direct
  `CodexWatcher.Workflow.Agent.Ids` and
  `CodexWatcher.Workflow.GitHub.Ids` owner imports after `cabal build all`,
  `cabal test watcher-core-test`, git diff checks, selected-file
  no-`Core.Ids` scan, selected-file direct-owner scan, broad remaining-user
  classification, and focused workflow PASS-label evidence passed.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed:
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/roadmap.md`

### Rationale
Round 187 changes milestone status evidence only. It completes the
`direction-011h-testsupport-workflow-core-ids-import` slice by moving the
shared workflow test-support helper off the `Core.Ids` compatibility facade,
but it leaves the existing future coordination intact: workflow specs remain
under direction 011h, runtime/CLI tests remain under direction 011i, and
policy/aggregator classification remains under direction 011j. Milestone 004
is now in progress, not complete.

This status-only update does not approve public facade deprecation/removal,
Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone
004 completion, release approval, terminal completion, or public compatibility
removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
