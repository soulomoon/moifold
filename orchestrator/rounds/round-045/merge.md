### Squash Commit
- Title: Refresh workflow package boundary tests
- Summary: Strengthens the watcher-core boundary regression tests for the standalone `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package layout. The round adds exact `cabal.project` package assertions, verifies moifold consumes the standalone package names with approved bounds, and requires each standalone package's recursive source-module inventory to match its Cabal `exposed-modules` inventory while preserving the existing ownership, dependency, metadata, forbidden-import, forbidden-token, and no-reexport checks.

### Merge Readiness
- Base branch freshness: confirmed. The worktree is on `orchestrator/round-045-external-package-slice`; `codex/workflow-facade-extraction` is an ancestor of `HEAD`, and both currently resolve to `5f77debd1fca77fa3b282d8d1b62efc898619600` before applying the approved worktree diff.
- Merge ordering satisfied: yes. `orchestrator/state.json` records `last_completed_round` as `round-044`, `pending_merge_rounds` as empty, and `merge_ready` as `true` for `round-045`.
- Pending dependencies: none. Declared predecessors `round-042`, `round-043`, and `round-044` / items `item-042-moifold-local-consumer-wiring`, `item-043-package-check-and-sdist`, and `item-044-ci-build-matrix` are satisfied by the current controller state.

### Follow-Up Notes
Review approved this round with no findings. Local validation passed for `cabal test watcher-core-test`, `cabal build all`, `scripts/validate-workflow-packages.sh`, `git diff --check`, the cached-diff hygiene check, the focused boundary-test symbol scan, and the upload-command scan. The package validation script generated local source-distribution artifacts under `dist-newstyle/sdist/`; keep those uncommitted. The implementation diff is limited to `test/Main.hs`; the worktree also carries controller activation in `orchestrator/state.json` and this merge artifact.
