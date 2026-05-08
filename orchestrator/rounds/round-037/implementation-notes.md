### Changes Made
- `docs/agentic-workflow-framework/release-metadata-policy.md`: added the
  source-backed release metadata policy for `agent-workflow-core`,
  `agent-workflow-codex`, and `agent-workflow-github`, including field
  requirements, package-specific metadata defaults, changelog/release-note
  gates, metadata truth rules, and descriptor-time checks.
- `docs/agentic-workflow-framework/README.md`: added a narrow link to the new
  release metadata policy in the implemented contract document list.
- `orchestrator/rounds/round-037/implementation-notes.md`: recorded this
  implementation summary and verification results for reviewer handoff.

### Tests
- `git diff --check`: passed.
- `git diff --name-only` plus
  `git ls-files --others --exclude-standard`: reviewed after implementation;
  tracked changes are limited to the README link and the pre-existing
  controller-owned `orchestrator/state.json`; untracked files are the new
  policy, this implementation note, and the pre-existing round `selection.md`
  and `plan.md` artifacts.
- `cabal build all`: not run because the implementation is docs-only and did
  not touch Haskell source, Cabal descriptors, tests, generated fixtures, or
  other non-documentation implementation files.
- `cabal test watcher-core-test`: not run for the same docs-only reason.

### Notes
The new policy deliberately does not create standalone package descriptors,
changelog entries, release notes, source-distribution artifacts, publication
artifacts, or upload approval. Current top-level `moifold` metadata is treated
as evidence that descriptor rounds must reconfirm, not as automatic final
metadata for every future package candidate.
