### Source Round
- Round id: `round-099`
- Merged commit: `08bd47a`
- Evidence: `orchestrator/rounds/round-099/selection.md`, `orchestrator/rounds/round-099/plan.md`, `orchestrator/rounds/round-099/implementation-notes.md`, `orchestrator/rounds/round-099/review.md`, `orchestrator/rounds/round-099/review-record.json`, and `orchestrator/rounds/round-099/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`

### Rationale
Round 099 completed one narrow production agent-id-only `direction-011-core-ids-import-convergence` slice by moving the `src/CodexWatcher/Workflow/Execution.hs` `RequestId` import from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct owner module `CodexWatcher.Workflow.Agent.Ids`. Reviewer evidence records that workflow execution behavior, request-id threading, dry-run conversion, action partitioning, and checked execution behavior were preserved; no package descriptors or public facade exposure changed; and `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` passed.

This is a status-only update to the active roadmap revision. It reduces one production dependency on the combined ids facade, but it does not complete milestone 003 or all of direction 011. Remaining `Core.Ids` combined users still require parser, renderer, serialization, prompt/output, runtime-config, and fixture stability evidence before broader convergence. The round also does not approve AppServerClient, Workflow.EventLog, Workflow.Permission, combined Core.Ids user migration, public deprecation, facade removal, Cabal exposure removal, package descriptor cleanup, parser/renderer/command behavior changes, runtime compatibility cleanup, release approval, milestone completion, or terminal completion.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
