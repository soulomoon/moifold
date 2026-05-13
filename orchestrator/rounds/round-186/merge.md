### Squash Commit
- Title: Round 186: Migrate issue implement loop ID imports
- Summary: Round 186 migrates `src/CodexWatcher/Domain/IssueImplement/Loop.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by replacing it with direct `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` imports. The reviewed diff is import-only for the issue-implementation loop, keeps use sites unchanged, and preserves the verified request-id, worker/reviewer-thread, command-rendering, event-ordering, daemon-transition, turn-classification, and failure-text behavior.

### Merge Readiness
- Base branch freshness: confirmed against the local `codex/workflow-facade-extraction` base; round branch `orchestrator/round-186-highest-value-cleanup-slice` and the local base both resolve to `d48807ad7cb75b8fc08626a503a7aec9ad0484a5`, with no committed branch drift before squash.
- Merge ordering satisfied: yes. The selection declares no `depends_on_round_ids` and no `merge_after_item_ids`; `max_parallel_rounds` is serial at `1`; state has `round-186` in `stage: merge`; review-record decision is `approved`.
- Pending dependencies: none.

### Follow-Up Notes
The broad `CodexWatcher.Core.Ids` scan found no remaining production users beyond the public facade module itself. Remaining matches are outside this production-import slice: Cabal/package exposure, tests/fixtures, docs, and policy references.

This merge readiness note does not approve milestone completion, terminal completion, public facade removal or deprecation, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, or release approval. The roadmap update and its review decide the post-merge status.
