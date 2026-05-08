### Changes Made
- `docs/agentic-workflow-framework/package-extraction-readiness.md`: added a source-backed extraction readiness report for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, including import-graph evidence, Cabal dependency ownership, compatibility facade mapping, validation commands, and remaining moifold-owned blockers.
- `docs/agentic-workflow-framework/README.md`: added a narrow link to the readiness report for discoverability.

### Tests
- No test files changed. The round is artifact-only because the import graph, Cabal sections, and existing recursive package-boundary assertions matched the report evidence.
- `git diff --check`: passed.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `git diff --cached --check`: not run because no files were staged.

### Notes
The report evidence did not reveal a concrete Cabal, public-module, or boundary-test mismatch, so no code, Cabal, or test cleanup was made. I did not stage changes and did not edit roadmap files or `orchestrator/state.json`.
