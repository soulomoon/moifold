### Squash Commit
- Title: Add moifold consumer validation evidence
- Summary: Adds evidence-only validation that moifold consumes the standalone `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates through the intended local package wiring. The round records descriptor and package-boundary scans, compatibility-facade evidence, package validation without publication, the external consumer example build/run, moifold build and `watcher-core-test` results, and safe CLI/render-service/empty-root healthcheck smoke checks, while leaving implementation code, descriptors, CI, release artifacts, roadmap files, generated artifacts, and controller state out of the payload.

### Merge Readiness
- Base branch freshness: confirmed; `orchestrator/round-049-external-package-slice` and `codex/workflow-facade-extraction` both resolve to `820684ffbbac25d34e45abeb80a2b506410a27ea` before the staged payload, and the base is an ancestor of the round worktree HEAD.
- Merge ordering satisfied: yes; `round-049` is the active serial merge-stage round, `last_completed_round` is `round-048`, there are no pending merge rounds, and declared dependencies `round-036` through `round-048` / `item-036` through `item-048` are already completed on base.
- Pending dependencies: none.

### Follow-Up Notes
This round does not approve publication, assemble a release-candidate bundle, upload packages, change package versions/descriptors, remove compatibility facades, or alter event/runtime/healthcheck/repair/prompt policy. The next release-gate work can use this validation evidence as input, but generated `dist-newstyle/` artifacts and `orchestrator/state.json` should remain outside the squash payload.
