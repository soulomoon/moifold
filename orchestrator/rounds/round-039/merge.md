### Squash Commit
- Title: Add standalone agent-workflow-core package descriptor
- Summary: Adds the first standalone `agent-workflow-core` Cabal descriptor and local project wiring while preserving the existing `agent-workflow-core/src` module layout and retained `moifold:agent-workflow-core` internal sublibrary. The round also extends package-boundary assertions so both the standalone descriptor and internal sublibrary prove the approved core-only dependency surface.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; `HEAD`, merge base, and the local base branch are all `3abf2bc22876e9bf4f9d1f42d0de041a2abe9dbc`. Remote freshness could not be checked because `origin` has no `codex/workflow-facade-extraction` head.
- Merge ordering satisfied: yes. `round-039` declares no `depends_on_round_ids`, no `merge_after_item_ids`, and no parallel group; the active roadmap lane is serial.
- Pending dependencies: none.

### Follow-Up Notes
Review approved the round after package-specific validation, boundary scans, `cabal build all`, `cabal test watcher-core-test`, and whitespace checks. The merge should squash only this standalone core descriptor/build-surface slice; adapter descriptors, moifold consumer rewiring, compatibility facade changes, release artifacts, roadmap updates, and state updates remain outside this merge artifact.
