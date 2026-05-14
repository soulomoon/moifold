### Source Round
- Round id: round-189
- Merged commit: fc9aa0d
- Evidence: `orchestrator/rounds/round-189/selection.md`, `plan.md`,
  `implementation-notes.md`, `review.md`, `review-record.json`, and
  `merge.md`. Reviewer evidence approved the import-only migration of
  `test/WorkflowAgentSpec.hs` from `CodexWatcher.Core.Ids` to direct
  `CodexWatcher.Workflow.Agent.Ids` and
  `CodexWatcher.Workflow.GitHub.Ids` owner imports after `cabal build all`,
  `cabal test watcher-core-test`, git diff checks, selected-file
  no-`Core.Ids` scan, selected-file direct-owner imports, and broad
  remaining-user classification passed.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed:
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/roadmap.md`

### Rationale
Round 189 changes milestone status evidence only. It completes the
`direction-011h-workflow-agent-spec-core-ids-import` slice by moving
`test/WorkflowAgentSpec.hs` off the `Core.Ids` compatibility facade, but it
leaves the existing future coordination intact: remaining workflow specs stay
under direction 011h, runtime/CLI tests stay under direction 011i, and
policy/aggregator classification stays under direction 011j. Milestone 004
remains in progress, not complete.

The reviewer-approved broad scan classifies remaining `Core.Ids` users as
workflow specs (`test/WorkflowExecutionSpec.hs`,
`test/WorkflowIndexedSpec.hs`), runtime/CLI tests (`test/RuntimeSpec.hs`,
`test/RuntimeCompatibilityFixtureSpec.hs`, `test/CliSpec.hs`), the
policy/aggregator surfaces (`test/FacadeImportPolicySpec.hs`, `test/Main.hs`),
docs, Cabal exposure, and the public facade module. No app, reusable package,
or production `src` users remain beyond the public facade module.

This status-only update does not approve public facade deprecation/removal,
Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone
004 completion, release approval, terminal completion, or public compatibility
removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
