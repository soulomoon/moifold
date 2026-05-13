### Goal

Migrate `test/AppServerProbeSpec.hs` away from the `CodexWatcher.Core.Ids`
compatibility facade for its `ThreadId` use by importing the direct app-server
agent identifier owner, while preserving all existing app-server probe command
coverage.

### Approach

Keep the round to the selected one-file import convergence slice. The test
already uses `ThreadId` only for app-server probe request assertions and fixture
responses, and `CodexWatcher.Workflow.Agent.Ids` is the direct owner that
exports `ThreadId (..)` and `unThreadId`. The implementation should therefore
be an import-owner change only, with no assertion rewrites, helper moves,
production edits, package descriptor edits, compatibility facade edits, or
public removal/deprecation claims.

Worker fan-out is not used. The scope is serial, one-file, and has no
non-overlapping ownership boundaries that would justify `worker-plan.json`.

### Steps

1. In `test/AppServerProbeSpec.hs`, replace the import of
   `CodexWatcher.Core.Ids (ThreadId (..), unThreadId)` with
   `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), unThreadId)`.
2. Leave the existing `CodexWatcher.Workflow.Agent.Codex.Transport`
   `AppServerEndpoint` import unchanged.
3. Do not change test bodies, helper functions, expected request methods,
   request ids, rendered thread ids, success output checks, or failure checks.
4. Confirm no other files were edited for this round except the implementation
   notes the implementer must write.
5. Record in implementation notes that `CodexWatcher.Core.Ids` remains
   available and that this round is preferred-import convergence only, not
   facade deprecation, Cabal exposure removal, or public compatibility removal.

### Verification

Run the roadmap baseline checks:

1. `cabal build all`
2. `cabal test watcher-core-test`
3. `git diff --check`

If staging is performed before review, also run:

1. `git diff --cached --check`

Reviewer alignment checks should confirm the round lineage remains
`2026-05-11-00-highest-value-cleanup` / `rev-001`, `CodexWatcher.Core.Ids`
remains exposed, and the diff contains no behavior, package descriptor, docs,
or compatibility-removal change. The app-server probe coverage is exercised
through `watcher-core-test`; this plan does not require adding a new focused
test selector to the custom test harness.
