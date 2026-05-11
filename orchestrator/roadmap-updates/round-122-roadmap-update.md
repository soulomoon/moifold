### Source Round
- Round id: `round-122`
- Merged commit: `5c268da` (`Move AutomaticLoop runner off AppServerClient facade`)
- Evidence: `orchestrator/rounds/round-122/selection.md`, `orchestrator/rounds/round-122/implementation-notes.md`, `orchestrator/rounds/round-122/review.md`, `orchestrator/rounds/round-122/review-record.json`, `orchestrator/rounds/round-122/merge.md`, `git show --stat --oneline --name-only 5c268da`, and live import scans over `src`, `app`, and `test`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md` and `orchestrator/roadmap-updates/round-122-roadmap-update.md`

### Rationale
Round 122 is a reviewed import-only migration for `src/CodexWatcher/AutomaticLoop/Runner.hs`. The merged commit moves the runner from the public `CodexWatcher.AppServerClient` compatibility facade to the direct owner module `CodexWatcher.Workflow.Agent.Codex.Transport` for exactly `AppServerEndpoint`, `appServerInterpreterFromEndpoint`, and `defaultAppServerClientOptions`.

The roadmap status changes only to record that `AutomaticLoop/Runner.hs` is no longer a production source user of the public facade. The accepted evidence shows no code-body, behavior, test, docs, package descriptor, public facade, direct-owner module, protocol module, runtime file, app code, PR-review launch, issue-fanout, test-policy/support import, or other importer change. The round passed the focused `AutomaticLoopRunnerSpec.automaticLoopRunnerTests` REPL gate, `cabal test watcher-core-test`, `cabal build all`, whitespace checks, import scans, diff inspection, forbidden-path guard, no-worker-plan guard, and JSON checks.

Live import scans after round 122 show the remaining production `CodexWatcher.AppServerClient` source users are `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` and `src/CodexWatcher/Cli/Command/IssueFanout.hs`. Test-policy and test-support imports remain. `src/CodexWatcher/AutomaticLoop/Runner.hs` is now absent from source facade users.

Milestone 003 and direction 010 remain in progress. This update does not approve public facade removal or deprecation, Cabal/API exposure cleanup, docs cleanup, package descriptor cleanup, protocol/runtime/owner changes, PR-review launch migration, issue-fanout migration, test-policy/support import migration, milestone completion, release or terminal completion, or public compatibility removal.

No new roadmap revision is needed because round 122 only advances the existing `direction-010-appserverclient-import-convergence` status and does not change sequencing, dependencies, milestone boundaries, or state metadata.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
