### Source Round
- Round id: `round-109`
- Merged commit: `b7c059f`
- Evidence: `orchestrator/rounds/round-109/selection.md`, `orchestrator/rounds/round-109/implementation-notes.md`, `orchestrator/rounds/round-109/review.md`, `orchestrator/rounds/round-109/review-record.json`, and `orchestrator/rounds/round-109/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`

### Rationale
Round 109 completed a narrow AppServerClient import-convergence slice under
direction 010. The approved implementation moved only
`src/CodexWatcher/Domain/PrReview/TurnClassifier.hs` from importing
`CodexWatcher.AppServerClient` to importing direct owner
`CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.

The approved diff did not change PR-review classifier exports, type
signatures, parsing, classification logic, `classifyPrReviewWorkerTurn`,
`classifyPrReviewReviewerTurn`, `classifyTurnCompletion`, missing-output
blocking, structured worker outcomes, reviewer-state JSON parsing,
reviewed-commit validation, reviewer prompt-version validation, prior/new
findings status handling, LGTM handling, solved/remaining review-thread
handling, incomplete/blocked reviewer outcomes, public facade exposure,
package descriptors, docs, fixtures, tests, protocol surfaces,
endpoint/session/timeout/fallback/command/failure-formatting behavior, or any
other `CodexWatcher.AppServerClient` importer. `CodexWatcher.AppServerClient`
remains available and unchanged as a public facade. Validation passed for the
old target import scan no matches, direct-owner import scan finding the
selected import, PR-review classifier test discovery,
`cabal test watcher-core-test`, `cabal build all`, descriptor/facade diff
check, no `worker-plan.json`, `git diff --check`,
`git diff --cached --check`, and `jq` validation.

This is a status-only update to the active roadmap revision. It does not
approve public facade removal or deprecation, Cabal exposure removal, package
descriptor cleanup, docs, fixtures, tests, protocol changes,
endpoint/session/timeout/fallback, command, or failure-formatting changes,
migration of other importers, release approval, milestone completion,
terminal completion, or a new roadmap revision. Milestone 003 remains in
progress. Current exact `CodexWatcher.AppServerClient` source import evidence
after round 109 still includes users in `RunnerGuard.hs`,
`Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`,
`AutomaticLoop/Runner.hs`, `Healthcheck.hs`,
`Cli/Command/AppServerProbe.hs`, `Cli/Command/Observe.hs`, and
`Cli/Command/IssueFanout.hs`, plus test-policy imports; those are
higher-risk endpoint/session/timeout/fallback/command/failure-formatting or
test-policy surfaces.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
