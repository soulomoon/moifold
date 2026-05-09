### Squash Commit
- Title: Record Core.Ids split import evidence
- Summary: Record the approved round-060 evidence for `CodexWatcher.Core.Ids`, including the refreshed combined-facade import scan, split `Agent.Ids` and `GitHub.Ids` usage, Cabal exposure assertions, ownership grouping, historical count comparison, and conservative migration risks. The round is evidence-only and does not change source, tests, package metadata, docs policy, roadmap files, runtime compatibility files, public facades, or `orchestrator/state.json`.

### Merge Readiness
- Base branch freshness: confirmed. `orchestrator/round-060-core-ids-split-import-evidence` and base branch `codex/workflow-facade-extraction` both point at `7f88d0a`; `git log codex/workflow-facade-extraction..HEAD` and `git log HEAD..codex/workflow-facade-extraction` are empty.
- Merge ordering satisfied: yes. The round is in serial mode, `depends_on_round_ids` is empty, `merge_after_item_ids` is empty, `pending_merge_rounds` is empty, and the approved review confirms the visible diff is limited to round-local artifacts.
- Pending dependencies: none.

### Follow-Up Notes
Ready for focused squash merge with title `Record Core.Ids split import evidence`. The controller should merge only the round-local artifacts for round 060 and then perform its normal roadmap-update bookkeeping.
