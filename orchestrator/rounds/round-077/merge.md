### Squash Commit
- Title: Migrate selected AppServerClient imports to direct Codex modules
- Summary: Round 077 migrates the smallest approved behavior-neutral set of internal `CodexWatcher.AppServerClient` import sites to direct `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport` imports. The compatibility facade remains live and unchanged, and review evidence confirms no Cabal, docs, runtime compatibility, event schema, healthcheck, repair, deprecation, removal, or public exposure behavior changed.

### Merge Readiness
- Base branch freshness: confirmed. The round worktree is on `orchestrator/round-077-internal-import-migration-readiness`; local `HEAD` and local base branch `codex/workflow-facade-extraction` both resolve to `504f9269f95ff363be35636b524adbf681ffce60`, so the round diff is working-tree-only on the configured base. A targeted fetch for `origin/codex/workflow-facade-extraction` failed because that remote ref is not advertised by `origin`, so freshness is confirmed against the local configured base only.
- Merge ordering satisfied: yes. `orchestrator/state.json` records `last_completed_round` as `round-076`, `pending_merge_rounds` as empty, and active round `round-077` with `merge_ready: true`. The selected item depends on rounds 075 and 076 and must merge after `round-075-import-scan-refresh` and `round-076-behavior-owner-classification`; those prerequisites are already completed before this round.
- Pending dependencies: none.

### Follow-Up Notes
Do not treat this merge as facade removal, deprecation approval, Cabal exposure approval, or runtime compatibility-file cleanup. The remaining 13 `CodexWatcher.AppServerClient` imports are deferred broad-import sites recorded in `implementation-notes.md` for later milestone-002 slices.
