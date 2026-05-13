### Source Round
- Round id: `round-181`
- Merged commit: `0379e2ae9815029ffd53f45083ba5b8df5af8dce`
- Evidence: `orchestrator/rounds/round-181/selection.md`, `orchestrator/rounds/round-181/plan.md`, `orchestrator/rounds/round-181/implementation-notes.md`, `orchestrator/rounds/round-181/review.md`, `orchestrator/rounds/round-181/review-record.json`, and `orchestrator/rounds/round-181/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/roadmap.md`

### Rationale
Round 181 completed the selected `round-181-issue-fanout-core-ids-split-import-migration` item under `milestone-003-core-ids-production-import-burndown` and `direction-011f-core-ids-cli-production-imports`.

The merged implementation was an import-only migration of `src/CodexWatcher/Cli/Command/IssueFanout.hs` away from the `CodexWatcher.Core.Ids` compatibility facade and onto direct owner imports: `CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId)` and `CodexWatcher.Workflow.GitHub.Ids (BranchName, IssueNumber, RepoName)`.

The review approved the slice with `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, selected-file absence of `CodexWatcher.Core.Ids`, selected-file direct-owner scans, and broad remaining `Core.Ids` classification. The approved diff did not change fanout planning, active issue discovery, child launch state writes, request-id progression, command rendering, dry-run text, process execution, parser/type modules, public facade exposure, Cabal, docs, runtime compatibility files, or behavior.

This is a status-only update because future coordination meaning did not change. The active roadmap now records round-181 evidence, removes `src/CodexWatcher/Cli/Command/IssueFanout.hs` from the milestone-003 remaining production users, and records that `direction-011f` CLI production imports are complete for `src/CodexWatcher/Cli/Parser/Common.hs`, `src/CodexWatcher/Cli/Types.hs`, and `src/CodexWatcher/Cli/Command/IssueFanout.hs`.

Milestone 003 remains in progress. Remaining production users after round 181 are `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, and `src/CodexWatcher/Domain/IssueImplement/Loop.hs`. This update does not approve public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
