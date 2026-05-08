### Changes Made
- `docs/agentic-workflow-framework/package-identity-versioning-contract.md`: added the package identity and versioning contract for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, including package-name decisions, pre-1.0 versioning policy, module namespace policy, semantic-versioning expectations, compatibility analysis, dependency ordering, and release-gate limits.
- `docs/agentic-workflow-framework/README.md`: added one narrow document link so the new package identity contract is discoverable with the existing framework contract docs.
- `orchestrator/rounds/round-036/implementation-notes.md`: recorded the implementation summary, verification, and artifact-only assumptions for the round.

### Tests
- `git diff --check`: passed; the working tree diff has no whitespace errors.
- `git diff --name-only` plus untracked-file listing: confirmed this implementer's edits are limited to the planned framework docs and round artifacts. The global working tree also reports `orchestrator/state.json`, which was already modified before these edits and was not touched by this implementation.

### Notes
This implementation is artifact-only. It does not edit Cabal descriptors, Haskell source, tests, generated fixtures, compatibility facades, release notes, changelogs, roadmap files, or `orchestrator/state.json`. `cabal build all` and `cabal test watcher-core-test` were not required because no Haskell, Cabal, test, generated fixture, or other non-documentation implementation files were touched.
