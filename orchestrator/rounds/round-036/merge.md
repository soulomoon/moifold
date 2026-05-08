### Squash Commit
- Title: Document workflow package identity and versioning contract
- Summary: Adds the docs-only package identity and versioning contract for the future external `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates. The round records final package-name assumptions, conservative pre-1.0 initial version policy, current module namespace policy, semantic-versioning expectations, compatibility limits, and release-gate boundaries while preserving the current `moifold` package shape and avoiding descriptor, source, module, compatibility facade, or publication changes.

### Merge Readiness
- Base branch freshness: confirmed locally. `codex/workflow-facade-extraction` and `orchestrator/round-036-external-package-slice` both point at `49ddd32`; `origin` does not advertise `codex/workflow-facade-extraction`, so remote freshness could not be confirmed against an `origin/<base>` ref.
- Merge ordering satisfied: yes. The active roadmap is serial (`max_parallel_rounds=1`), `last_completed_round` is `round-035`, this round declares no `depends_on_round_ids` and no `merge_after_item_ids`, and `pending_merge_rounds` is empty.
- Pending dependencies: none.

### Follow-Up Notes
Review approved the round after source-backed scope inspection and validation, including `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

This merge should remain docs/artifact-only. It should not be treated as package publication approval, standalone descriptor migration, source movement, module rename approval, compatibility-facade removal, changelog/release-note readiness, source-distribution readiness, or public release readiness.
