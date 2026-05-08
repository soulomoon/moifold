### Changes Made
- `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004/verification.md`: corrected copied IssuePlanning wording so the parity requirement explicitly compares compatibility IssueImplement behavior with indexed IssueImplement behavior.
- `orchestrator/rounds/round-017/implementation-notes.md`: recorded artifact-only implementation evidence for round 017.

### Tests
- Artifact validation: confirmed `round-017/plan.md`, `round-017/selection.md`, `rev-004/roadmap.md`, `rev-004/verification.md`, `rev-004/retry-subloop.md`, and `rev-003/verification.md` are present; confirmed `round-017/worker-plan.json` does not exist; confirmed `rev-004/roadmap.md` keeps roadmap id `2026-05-07-00-workflow-kernel-indexing`, revision `rev-004`, marks item 017 done, and orders IssueImplement items 018-024 after item 017; confirmed `rev-004/verification.md` and `retry-subloop.md` are IssueImplement-specific and preserve compatibility/schema/boundary guarantees.
- `git diff --check`: passed.

### Notes
This round stayed artifact-only. No production source, tests, golden fixtures, daemon behavior, event schemas, `rev-003` files, or controller-owned `orchestrator/state.json` were edited by me. `orchestrator/state.json` was already dirty with active round controller metadata when implementation began and was left untouched.

No production build or test command was run because the selected item is an artifact-only planning round and the diff does not touch production code, tests, golden fixtures, daemon behavior, or event schemas.
