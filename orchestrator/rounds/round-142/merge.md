### Squash Commit
- Title: Migrate PrReviewLaunchCliSpec endpoint import to direct transport owner
- Summary: This round migrates only `test/PrReviewLaunchCliSpec.hs` from the public `CodexWatcher.AppServerClient (AppServerEndpoint (..))` compatibility-facade import to `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`. The PR-review launch CLI assertions and helper definitions remain unchanged, while the public compatibility facade stays available for later exact cleanup rounds.

### Merge Readiness
- Base branch freshness: confirmed; `orchestrator/round-142-highest-value-cleanup-slice`, `HEAD`, `codex/workflow-facade-extraction`, and their merge-base are all `e9a32618d09e403c92426a445210ef7c05d08829`.
- Merge ordering satisfied: yes; review decision is approved, state has `merge_ready: true`, `depends_on_round_ids: []`, `merge_after_item_ids: []`, and `parallel_group: null`.
- Pending dependencies: none.

### Follow-Up Notes
Do not treat this as public facade deprecation, Cabal exposure cleanup, milestone completion, release approval, or compatibility removal. Remaining `CodexWatcher.AppServerClient` users are intentionally left for later exact selections, including public facade/exposure, docs and policy references, broader workflow specs, `test/Main.hs`, `test/AutomaticLoopRunnerSpec.hs`, and test support surfaces.
