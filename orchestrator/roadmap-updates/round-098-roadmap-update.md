### Source Round
- Round id: `round-098`
- Merged commit: `c223018`
- Evidence: `orchestrator/rounds/round-098/selection.md`, `orchestrator/rounds/round-098/plan.md`, `orchestrator/rounds/round-098/implementation-notes.md`, `orchestrator/rounds/round-098/review.md`, `orchestrator/rounds/round-098/review-record.json`, and `orchestrator/rounds/round-098/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`

### Rationale
Round 098 completed one narrow `direction-011-core-ids-import-convergence` slice by moving the GitHub-only `test/BoundaryPolicySpec.hs` import from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct owner module `CodexWatcher.Workflow.GitHub.Ids`. Reviewer evidence records that the assertions and command parity checks were preserved, `moifold.cabal` had no diff, `CodexWatcher.Core.Ids` remained publicly exposed, and both `cabal test watcher-core-test` and `cabal build all` passed.

This is a status-only update to the active roadmap revision. It reduces one test dependency on the combined ids facade, but it does not complete milestone 003 or all of direction 011. Remaining `Core.Ids` combined users still require parser, renderer, serialization, prompt/output, runtime-config, and fixture stability evidence before broader convergence. The round also does not approve production import convergence, public deprecation, facade removal, Cabal exposure changes, parser/renderer/command behavior changes, compatibility-file cleanup, release approval, milestone completion, or terminal completion.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
