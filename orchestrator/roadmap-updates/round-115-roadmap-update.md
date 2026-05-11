### Source Round
- Round id: `round-115`
- Merged commit: `dab7a84 Move AppServerProbe off AppServerClient facade`
- Evidence: `orchestrator/rounds/round-115/selection.md`, `orchestrator/rounds/round-115/implementation-notes.md`, `orchestrator/rounds/round-115/review.md`, `orchestrator/rounds/round-115/review-record.json`, and `orchestrator/rounds/round-115/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`; `orchestrator/roadmap-updates/round-115-roadmap-update.md`; `orchestrator/state.json` status only

### Rationale
`round-115` satisfies the import-only AppServerProbe migration step made ready by round 114's command coverage. The reviewed change moved only `src/CodexWatcher/Cli/Command/AppServerProbe.hs` from importing `CodexWatcher.AppServerClient` to importing direct Codex owner modules: `CodexWatcher.Workflow.Agent.Codex.Client` for the failure formatter and thread/turn id parsers, and `CodexWatcher.Workflow.Agent.Codex.Transport` for client options and request sending.

The active roadmap should record this as one narrow `direction-010-appserverclient-import-convergence` completion, not as broader cleanup. The round was import-only: no code bodies, behavior, tests, public facade exposure, package descriptors, public API, docs, direct owner modules, protocol modules, or other importers changed. The public `CodexWatcher.AppServerClient` compatibility facade remains exposed.

Milestone 003 and direction 010 remain in progress. Current `CodexWatcher.AppServerClient` source users still remain outside `AppServerProbe.hs`, including `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Healthcheck.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports. This update does not approve public facade removal or deprecation, Cabal exposure or public API removal, docs changes, release approval, milestone completion, or terminal completion.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
