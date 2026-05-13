### Source Round
- Round id: `round-178`
- Merged commit: `8d0cf6e6fde9d2f3ce90129fd23f7772c61f8e79`
- Evidence: `orchestrator/rounds/round-178/selection.md`, `orchestrator/rounds/round-178/plan.md`, `orchestrator/rounds/round-178/implementation-notes.md`, `orchestrator/rounds/round-178/review.md`, `orchestrator/rounds/round-178/review-record.json`, and `orchestrator/rounds/round-178/merge.md`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/roadmap.md`

### Rationale
Round 178 completed the selected `direction-011b-core-ids-golden-replay-production-import` slice by migrating only `src/CodexWatcher/GoldenReplay.hs` away from the `CodexWatcher.Core.Ids` compatibility facade. The file now imports `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, and `RepoName` from `CodexWatcher.Workflow.GitHub.Ids`, and `ThreadId` and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`.

The approved diff was import-only. Function bodies, exports, constructors, snapshot normalization, replay warnings, bootstrap events, old fixture behavior, package descriptors, public facade exposure, and behavior were unchanged. Reviewer evidence passed `cabal build all`, `cabal test watcher-core-test`, focused built-executable golden replay/bootstrap validation, `git diff --check`, selected-file import scans proving `GoldenReplay.hs` no longer imports `CodexWatcher.Core.Ids`, direct-owner scans proving both expected imports are present, and a broad remaining-user scan separating remaining production users from tests, docs, Cabal, and the public facade.

This is a status-only in-place update to `rev-002`. It records round 178 evidence and removes `src/CodexWatcher/GoldenReplay.hs` from the milestone-003 remaining production user list. Milestone 003 remains `[in-progress]` because production users still include `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `src/CodexWatcher/Cli/Types.hs`, `src/CodexWatcher/Cli/Parser/Common.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/Healthcheck.hs`, and `src/CodexWatcher/Domain/IssueImplement/Loop.hs`.

This update does not approve public facade deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: not applicable; proposed revision remains `rev-002`
