### Source Round
- Round id: round-179
- Merged commit: df7afa5d9305a7a4323615a48065a0f4265ae7fe
- Evidence: `orchestrator/rounds/round-179/selection.md`, `orchestrator/rounds/round-179/implementation-notes.md`, `orchestrator/rounds/round-179/review.md`, `orchestrator/rounds/round-179/review-record.json`, and `orchestrator/rounds/round-179/merge.md`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/roadmap.md`

### Rationale
Round 179 landed the `round-179-cli-parser-common-core-ids-split-import-migration` slice for `milestone-003-core-ids-production-import-burndown` under `direction-011f-core-ids-cli-production-imports`. The merged implementation moved only `src/CodexWatcher/Cli/Parser/Common.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct owner imports from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId` and `TurnId`, and `CodexWatcher.Workflow.GitHub.Ids` for `IssueNumber`, `RepoName`, and `ReviewThreadId`.

The round was approved with `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, selected-file `Core.Ids` scans, selected-file direct-owner scans, and broad remaining-user classification. The implementation evidence records an import-only diff: no parser exports, helper bodies, option/help/metavar/default/error text, command rendering, dry-run text, child args, fanout manifest behavior, tests, Cabal files, docs, runtime compatibility files, public facade exposure, or behavior changed.

This update records compact status evidence in the active `rev-002` roadmap and removes `src/CodexWatcher/Cli/Parser/Common.hs` from the milestone-003 remaining production users. Milestone 003 remains in progress. Remaining production users still include `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/Cli/Types.hs`, and `src/CodexWatcher/Cli/Command/IssueFanout.hs`.

This is status-only evidence and does not change future coordination meaning, sequencing, parallel lanes, extraction scope, verification meaning, or retry policy. It does not approve public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: not applicable
