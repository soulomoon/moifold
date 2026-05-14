### Source Round
- Round id: round-194
- Merged commit: 3bfd1aa
- Evidence: `orchestrator/rounds/round-194/selection.md`, `plan.md`,
  `implementation-notes.md`, `review.md`, `review-record.json`, and
  `merge.md`. Reviewer evidence approved the import-only migration of
  `test/RuntimeCompatibilityFixtureSpec.hs` from `CodexWatcher.Core.Ids` to
  direct `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)` and
  `CodexWatcher.Workflow.GitHub.Ids (BranchName, IssueNumber, PrNumber,
  RepoName)` owner imports after `cabal build all`, `cabal test
  watcher-core-test`, git diff checks, selected-file no-`Core.Ids` scan,
  selected-file direct-owner imports, selected-file diff inspection,
  aggregate/policy/public-surface unchanged checks, and broad remaining-user
  classification passed.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed:
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/roadmap.md`

### Rationale
Round 194 changes milestone status evidence only. It completes the
`direction-011i-runtime-compatibility-fixture-core-ids-import` extracted item by
moving `test/RuntimeCompatibilityFixtureSpec.hs` off the `Core.Ids`
compatibility facade and onto direct id owner imports while preserving fixture
JSON, fixture paths, runtime compatibility writes, repair behavior, healthcheck
reader boundary assertions, daemon-state assertions, planning graph assertions,
PASS labels, helpers, export list, and `test/Main.hs` aggregate wiring.

The current broad scan finds no remaining safe runtime or CLI test
`Core.Ids` imports. Direction 011i is therefore complete. Future coordination
does not change: milestone 004 stays in progress, not complete, because
direction 011j still owns policy/aggregator classification for
`test/FacadeImportPolicySpec.hs` and `test/Main.hs` while those files still
import `CodexWatcher.Core.Ids`.

The current broad scan classifies remaining `Core.Ids` users as the
policy/aggregator surfaces (`test/FacadeImportPolicySpec.hs`, `test/Main.hs`),
docs/policy references, the public facade module
(`src/CodexWatcher/Core/Ids.hs`), and Cabal exposure (`moifold.cabal`). No app,
reusable package, production `src` user beyond the public facade module,
runtime spec, CLI spec, or runtime compatibility fixture test remains on the
facade.

This status-only update does not approve public facade deprecation/removal,
Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone
004 completion, release approval, terminal completion, public compatibility
removal, or package-boundary removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
