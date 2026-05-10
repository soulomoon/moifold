### Source Round
- Round id: `round-080-public-deprecation-readiness-decision`
- Merged commit: `7c8a3cd`
- Evidence: `orchestrator/rounds/round-080/selection.md`, `orchestrator/rounds/round-080/deprecation-readiness-decision.md`, `orchestrator/rounds/round-080/review.md`, `orchestrator/rounds/round-080/review-record.json`, and `orchestrator/rounds/round-080/merge.md`.

### Roadmap Change
- Roadmap id: `2026-05-10-00-facade-removal-readiness`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-080-roadmap-update.md`

### Rationale
Round 080 completed `direction-006-deprecation-readiness` with an approved artifact-only public deprecation-readiness decision. The reviewed decision records all four selected facades as `defer`: `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.

The approved evidence supports preferred-import guidance and continued internal migration work for pure reexport users, but it does not satisfy the gates for public deprecation wording, `DEPRECATED` pragmas, Cabal exposure changes, public API changes, or removal. `CodexWatcher.AppServerClient` and `CodexWatcher.Core.Ids` still have remaining local facade imports and only bounded downstream inventory. `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` still carry mixed moifold bridge behavior from the round-079 hold. The round also records absent public deprecation/Cabal/Haddock alignment for all selected surfaces.

Because direction 006 now has an approved decision, milestone 003 can move from pending to in progress. Milestone 003 cannot be marked complete because `direction-007-cabal-exposure-decision` is still pending, and round 080 explicitly approved no docs, Haddock, Cabal/package descriptor, public API, deprecation pragma, public deprecation wording, exposed-module, facade removal, release, or publication change. This is a status-only update within `rev-001`; the active roadmap revision remains unchanged.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
