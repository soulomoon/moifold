### Changes Made
- `orchestrator/rounds/round-060/core-ids-split-import-evidence.md`: added the requested evidence-only inventory for `CodexWatcher.Core.Ids`, including current facade shape, refreshed recursive import scans, split replacement usage, Cabal exposure assertions, docs references, ownership grouping, historical comparison with rounds 054/056, and conservative migration risks.
- `orchestrator/rounds/round-060/implementation-notes.md`: recorded implementation scope and verification results for this round.

### Tests
- No source, test, Cabal, runtime compatibility, docs policy, roadmap, project-contract, or state files were intentionally edited.
- `git diff --check`: passed.

### Notes
All planned scan paths were present, so no absent path adaptation was required for the four required `rg` scans.

The refreshed combined-facade import count is 65, matching the prior round-054 and round-056 claims. The split-module scan found 10 importers, all in reusable package source, the package-consumer example, or the facade implementation itself.

`orchestrator/state.json` was already modified before this implementation pass. I did not edit it.
