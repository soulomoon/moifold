### Squash Commit
- Title: Author IssueImplement indexed roadmap revision
- Summary: Round 017 is an artifact-only roadmap round that authors `rev-004` for the indexed IssueImplement adoption sequence. It records item 017 as done, adds ordered IssueImplement follow-up items 018-024, and carries forward verification and retry contracts that preserve event schemas, golden logs, daemon results, dry-run/runtime rendering, request-id behavior, compatibility writes, lifecycle ownership, and package boundaries. No production source, tests, golden fixtures, rev-003 roadmap files, or implementation behavior are changed.

### Merge Readiness
- Base branch freshness: confirmed. `git rev-list --left-right --count HEAD...codex/workflow-facade-extraction` reports `0 0`.
- Merge ordering satisfied: yes. This round merges after `item-016-indexed-issue-planning-terminal-and-retry-daemon`; `rev-003` records item 016 done, and `orchestrator/state.json` records `last_completed_round` as `round-016`.
- Pending dependencies: none for merging round 017. Review decision is approved, and the only required merge-after item is already complete.

### Follow-Up Notes
After merge and update-roadmap, the controller should activate `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004/` before dispatching `item-018-indexed-issue-implementation-policy`.
