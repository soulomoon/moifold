### Changes Made
- test/AppServerProbeSpec.hs: replaced the `ThreadId`/`unThreadId` import from the `CodexWatcher.Core.Ids` compatibility facade with the direct owner import from `CodexWatcher.Workflow.Agent.Ids`, preserving the existing app-server probe command coverage.

### Tests
- test/AppServerProbeSpec.hs: existing app-server probe command tests continue to cover initialize, thread/read, thread/start, turn/start, success output, and failure behavior; no test bodies or helpers were changed.

### Notes
`CodexWatcher.Core.Ids` remains available. This round is preferred-import convergence only, not facade deprecation, Cabal exposure removal, docs cleanup, or public compatibility removal.
