### Source Round
- Round id: `round-113`
- Merged commit: `acd9a3a` (`Move RunnerGuard to direct Codex app-server imports`)
- Evidence: `orchestrator/rounds/round-113/selection.md`,
  `orchestrator/rounds/round-113/plan.md`,
  `orchestrator/rounds/round-113/implementation-notes.md`,
  `orchestrator/rounds/round-113/review.md`,
  `orchestrator/rounds/round-113/review-record.json`, and
  `orchestrator/rounds/round-113/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed:
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`,
  `orchestrator/roadmap-updates/round-113-roadmap-update.md`, and
  `orchestrator/state.json`

### Rationale
Round 113 completed the narrow RunnerGuard import-convergence slice authorized
after rounds 111 and 112 satisfied the two RunnerGuard behavior-coverage
blockers recorded by round 110. The merged, reviewed production change moved
only `src/CodexWatcher/RunnerGuard.hs` from the public
`CodexWatcher.AppServerClient` compatibility facade to direct owner imports
from `CodexWatcher.Workflow.Agent.Codex.Client` and
`CodexWatcher.Workflow.Agent.Codex.Transport`.

This update is status-only and keeps the active roadmap revision at `rev-001`.
The round was import-only: no code bodies, behavior, request ids, repair
prompts, failure formatting, public facade exposure, Cabal/package metadata,
public API, docs, direct owner modules, tests, or other importers changed.
Validation evidence includes target import scans, focused RunnerGuard REPL
coverage, `cabal test watcher-core-test`, `cabal build all`,
descriptor/facade and direct-owner diff guards, no `worker-plan.json`,
whitespace checks, and JSON validation.

Milestone 003 and direction 010 remain in progress. Other
`CodexWatcher.AppServerClient` source users still remain in
`Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`,
`AutomaticLoop/Runner.hs`, `Healthcheck.hs`,
`Cli/Command/AppServerProbe.hs`, `Cli/Command/Observe.hs`, and
`Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports. The
public compatibility facade remains exposed, and this update does not approve
public facade removal or deprecation, Cabal exposure or public API removal,
release approval, milestone completion, or terminal completion.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
