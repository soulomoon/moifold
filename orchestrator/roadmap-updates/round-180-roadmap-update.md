### Source Round
- Round id: `round-180`
- Merged commit: `229562aa404a5967ce0d7b1a2ea587c3709697ee`
- Evidence: `orchestrator/rounds/round-180/selection.md`, `orchestrator/rounds/round-180/plan.md`, `orchestrator/rounds/round-180/implementation-notes.md`, `orchestrator/rounds/round-180/review.md`, `orchestrator/rounds/round-180/review-record.json`, and `orchestrator/rounds/round-180/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/roadmap.md`

### Rationale
Round 180 completed the selected `round-180-cli-types-core-ids-split-import-migration` item under `milestone-003-core-ids-production-import-burndown` and `direction-011f-core-ids-cli-production-imports`.

The merged implementation was an import-only migration of `src/CodexWatcher/Cli/Types.hs` away from the `CodexWatcher.Core.Ids` compatibility facade and onto direct owner imports: `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)` and `CodexWatcher.Workflow.GitHub.Ids (CommitSha, IssueNumber, PrNumber, RepoName, ReviewThreadId)`. `BranchName` was not imported because the file does not use it at current head.

The review approved the slice with `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, selected-file absence of `CodexWatcher.Core.Ids`, direct-owner import scans, selected-file behavior-surface inspection, and a broad remaining-user classification. The approved diff did not change CLI exports, data declarations, record fields, derived instances, `CliDomain`, parser/rendering behavior, option names/errors, dry-run text, fanout-adjacent plumbing, child args, tests, package descriptors, public facade exposure, docs, runtime compatibility files, or behavior.

This is a status-only update because future coordination meaning did not change. The active roadmap now records round-180 evidence, removes `src/CodexWatcher/Cli/Types.hs` from the milestone-003 remaining production users, and records that the only remaining `direction-011f` CLI production user is `src/CodexWatcher/Cli/Command/IssueFanout.hs`.

Milestone 003 remains in progress. Remaining production users still include `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, and `src/CodexWatcher/Cli/Command/IssueFanout.hs`. This update does not approve public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
