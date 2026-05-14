### Source Round
- Round id: round-192
- Merged commit: bb76247
- Evidence: `orchestrator/rounds/round-192/selection.md`, `plan.md`,
  `implementation-notes.md`, `review.md`, `review-record.json`, and
  `merge.md`. Reviewer evidence approved the import-only migration of
  `test/CliSpec.hs` from `CodexWatcher.Core.Ids` to direct
  `CodexWatcher.Workflow.Agent.Ids (ThreadId)` and
  `CodexWatcher.Workflow.GitHub.Ids (IssueNumber, RepoName)` owner imports
  after `cabal build all`, `cabal test watcher-core-test`, git diff checks,
  selected-file no-`Core.Ids` scan, selected-file direct-owner imports,
  selected-file diff inspection, aggregate-wiring scan, and broad
  remaining-user classification passed.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed:
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/roadmap.md`

### Rationale
Round 192 changes milestone status evidence only. It completes the
`direction-011i-cli-spec-core-ids-import` extracted item by moving
`test/CliSpec.hs` off the `Core.Ids` compatibility facade and onto direct id
owner imports while preserving CLI parser expectations and `test/Main.hs`
aggregate wiring.

The future coordination remains intact. Milestone 004 stays in progress, not
complete: runtime and compatibility fixture tests remain under direction 011i
when they still import `CodexWatcher.Core.Ids`, and policy/aggregator
classification remains under direction 011j.

The current broad scan classifies remaining `Core.Ids` users as runtime tests
(`test/RuntimeSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`), the
policy/aggregator surfaces (`test/FacadeImportPolicySpec.hs`,
`test/Main.hs`), docs, Cabal exposure, and the public facade module. No app,
reusable package, or production `src` users remain beyond the public facade
module.

This status-only update does not approve public facade deprecation/removal,
Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone
004 completion, release approval, terminal completion, public compatibility
removal, or package-boundary removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
