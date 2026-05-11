### Squash Commit
- Title: Move AppServerProbe off AppServerClient facade
- Summary: Round 115 performs the approved import-only migration for `src/CodexWatcher/Cli/Command/AppServerProbe.hs`, replacing the `CodexWatcher.AppServerClient` compatibility-facade import with direct imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`. The implementation leaves command behavior, request handling, tests, package metadata, public facade exposure, direct owner modules, protocol code, docs, and other remaining facade users unchanged.

### Merge Readiness
- Base branch freshness: confirmed locally. The round branch `orchestrator/round-115-highest-value-cleanup-slice`, `HEAD`, and local base branch `codex/workflow-facade-extraction` all point at `4fdd61f1107543dce8edead60a8ff2e78bb12036`, so local ancestry is clean. Remote freshness could not be established because `origin` did not advertise either `codex/workflow-facade-extraction` or `orchestrator/round-115-highest-value-cleanup-slice`.
- Merge ordering satisfied: yes. `orchestrator/state.json` records round 115 at `stage = "merge"` with `merge_ready = true`, and `orchestrator/rounds/round-115/review.md` plus `review-record.json` record an approved review for the selected AppServerProbe import migration.
- Pending dependencies: none. The selected item records `depends_on_round_ids = []`, no worker fan-out plan exists, and the observed dirty paths are limited to `orchestrator/state.json`, `src/CodexWatcher/Cli/Command/AppServerProbe.hs`, and round-115 artifacts.

### Follow-Up Notes
Remaining `CodexWatcher.AppServerClient` source users outside `AppServerProbe.hs` are intentionally out of scope for this squash. This merge note does not approve facade removal, Cabal/API exposure cleanup, docs changes, migration of other importers, release/publication, milestone completion, or terminal completion.
