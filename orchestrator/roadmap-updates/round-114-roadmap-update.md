### Source Round
- Round id: `round-114`
- Merged commit: `0a5a842 Add AppServerProbe command coverage`
- Evidence: `orchestrator/rounds/round-114/selection.md`, `orchestrator/rounds/round-114/implementation-notes.md`, `orchestrator/rounds/round-114/review.md`, `orchestrator/rounds/round-114/review-record.json`, and `orchestrator/rounds/round-114/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`; `orchestrator/roadmap-updates/round-114-roadmap-update.md`; `orchestrator/state.json` status only

### Rationale
`round-114` satisfies the AppServerProbe command coverage gate recorded under `direction-010-appserverclient-import-convergence`. The reviewed change added focused endpoint-backed `probeAppServer` command coverage for `initialize`, optional `thread/read`, smoke `thread/start`, smoke `turn/start`, request ids and selected params, success output, and selected JSON-RPC/decode failure formatting.

The active roadmap should record this as evidence for a later import-only `Cli/Command/AppServerProbe.hs` migration decision, not as migration itself. The round was test-only: it added `test/AppServerProbeSpec.hs`, wired `appServerProbeCommandTests` into `test/Main.hs`, and added only `AppServerProbeSpec` to `watcher-core-test` metadata in `moifold.cabal`. It did not change production `AppServerProbe`, `CodexWatcher.AppServerClient`, direct owner client/transport modules, app-server protocol modules, facade exposure, Cabal exposed modules, public API, docs, or other importers.

Milestone 003 and direction 010 remain in progress. Current `CodexWatcher.AppServerClient` source users still remain, including `Cli/Command/AppServerProbe.hs`, and the public compatibility facade remains exposed. This update does not approve production import migration, public facade removal or deprecation, Cabal exposure or public API removal, release approval, milestone completion, or terminal completion.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
