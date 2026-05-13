### Source Round
- Round id: `round-185`
- Merged commit: `5d7a1c0`
- Evidence: `orchestrator/rounds/round-185/selection.md`, `orchestrator/rounds/round-185/plan.md`, `orchestrator/rounds/round-185/implementation-notes.md`, `orchestrator/rounds/round-185/review.md`, `orchestrator/rounds/round-185/review-record.json`, and `orchestrator/rounds/round-185/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/roadmap.md`

### Rationale
Round 185 completed the selected `round-185-issue-planning-loop-core-ids-import-migration-or-classification` item under `milestone-003-core-ids-production-import-burndown` and `direction-011e-core-ids-domain-loop-production-imports`.

The merged implementation was an import-only migration of `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` away from the `CodexWatcher.Core.Ids` compatibility facade and onto direct owner imports: `CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId, TurnId, nextRequestId)` and `CodexWatcher.Workflow.GitHub.Ids (IssueNumber, RepoName)`.

The review approved the slice with `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`, selected-file no-`Core.Ids` scan, selected-file direct-owner scan, broad remaining `Core.Ids` classification, and focused planning-loop evidence. The approved diff did not change request-id progression, planner thread/turn handling, repo/issue rendering, event append order, daemon transition behavior, app-server turn classification, failure text, public facade exposure, Cabal, docs, runtime compatibility files, or behavior.

This is a status-only update because future coordination meaning did not change. The active roadmap now records round-185 evidence, removes `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` from the milestone-003 remaining production users, and records that the IssuePlanning half of `direction-011e` is complete while `src/CodexWatcher/Domain/IssueImplement/Loop.hs` remains for a later round.

Milestone 003 remains in progress. The remaining production user after round 185 is `src/CodexWatcher/Domain/IssueImplement/Loop.hs` only. This update does not approve public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
