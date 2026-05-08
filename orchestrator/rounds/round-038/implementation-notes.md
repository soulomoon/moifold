### Changes Made
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`: added the approved artifact-only compatibility policy for the future `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates, including evidence sources, preferred imports, compatibility facade status, deprecation-readiness gates, removal gates, and release-note constraints.
- `docs/agentic-workflow-framework/README.md`: added one implemented-contract index link to the new compatibility and deprecation policy.
- `orchestrator/rounds/round-038/implementation-notes.md`: recorded this implementation summary for round review.

### Tests
- `git diff --check`: validates the working-tree diff has no whitespace errors.
- `git diff --no-index --check /dev/null docs/agentic-workflow-framework/compatibility-deprecation-policy.md`: validates the new policy file has no whitespace errors.
- Diff inspection: confirmed the implementation changes are limited to the planned docs artifact, the optional docs README index link, and this round implementation note, aside from pre-existing controller-owned `orchestrator/state.json` state.

### Notes
This round intentionally did not edit Haskell source, Cabal descriptors, tests, generated fixtures, compatibility facades, compatibility files, roadmap files, review artifacts, merge artifacts, changelogs, release notes, package descriptors, source-distribution artifacts, or publication artifacts. Because the implementation remained documentation-only, `cabal build all` and `cabal test watcher-core-test` were not required by the round plan.
