### Changes Made
- `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-003/roadmap.md`: added the rev-003 roadmap, marked `item-012-indexed-next-domain-plan` done, selected `IssuePlanning` as the next indexed adoption domain, explicitly deferred `IssueImplement`, and added ordered non-parallel-safe items 013-017 with concrete parity surfaces.
- `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-003/verification.md`: carried forward the rev-002 baseline verification commands and added issue-planning-specific parity, graph normalization, daemon, retry, compatibility-write, request-id, and fanout checks.
- `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-003/retry-subloop.md`: carried forward the retry-subloop contract for rev-003 and added issue-planning retry examples for parity, graph, daemon, retry/block, compatibility-write, and fanout failures.
- `orchestrator/rounds/round-012/implementation-notes.md`: recorded this artifact-only implementation and verification evidence.

### Tests
- No production tests were added or changed. This round is an artifact-only roadmap revision and intentionally did not edit production source, test modules, golden fixtures, or rev-002 files.

### Notes
Verification run:
- `git diff --check`: passed.
- `git diff --no-index --check` over the four new artifact files: passed.
- `git diff --cached --check`: not run because no files were staged.
- Artifact inspection: confirmed `rev-003/roadmap.md`, `rev-003/verification.md`, and `rev-003/retry-subloop.md` exist; `rev-003/roadmap.md` keeps roadmap id `2026-05-07-00-workflow-kernel-indexing`; items 013-017 are ordered and non-parallel-safe; `worker-plan.json` does not exist.

No `worker-plan.json` was created. No files were staged. `orchestrator/state.json` was already controller-owned dirty state and was not edited.
