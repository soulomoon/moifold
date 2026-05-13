### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-149-workflow-event-log-spec-appserverclient-import-cleanup`
- Extracted item summary: Move only `test/WorkflowEventLogSpec.hs` off the `CodexWatcher.AppServerClient` compatibility facade by removing its now-unused exact facade import, preserving the focused workflow event-log assertions and leaving the public facade exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/WorkflowEventLogSpec.hs` import-only cleanup for the exact `CodexWatcher.AppServerClient` import; focused scans proving the selected file no longer imports the facade and does not reference AppServerClient-owned symbols; broad scan recording remaining `CodexWatcher.AppServerClient` users as out of scope; validation that workflow event-log tests remain reachable through `watcher-core-test`.
- Out of scope: production files; `test/WorkflowExecutionSpec.hs`; `test/Main.hs`; `test/BoundaryPolicySpec.hs` policy strings; `src/CodexWatcher/AppServerClient.hs`; direct owner module exports; package descriptors; docs; public facade exposure; Cabal exposure cleanup; deprecation or removal policy; runtime compatibility files; milestone completion; release state; terminal roadmap state.
- Concurrent batch context: none. `max_parallel_rounds` is 1 and this selection owns only the round-149 selection artifact. Later remaining test importers need separate exact selections.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [],
  "merge_after_item_ids": [],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress after round 148. The active roadmap and user steering both prefer concrete migration/removal-enabling cleanup over another readiness-only artifact when a safe slice exists, while still forbidding public `CodexWatcher.AppServerClient` facade deletion, Cabal exposure cleanup, docs cleanup, or deprecation without exact gates.

The current live scan still finds exact `CodexWatcher.AppServerClient` imports in `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, and `test/Main.hs`. `test/TestSupport/Workflow.hs` has already been migrated by round 148. A focused symbol scan of `test/WorkflowEventLogSpec.hs` finds the exact facade import but no remaining `AppServerTurn`, `AppServerEndpoint`, `AppServerClientFailure`, `JsonRpcError`, `formatAppServerClientFailure`, `AppServerClientOptions`, or `defaultAppServerClientOptions` use in that file, so this is the smallest lawful direct cleanup slice: remove the stale facade import without introducing new direct-owner imports or touching behavior.

This should run before public facade or Cabal cleanup because it reduces one more concrete internal test dependency on the compatibility facade while leaving all removal gates intact. The implementation should preserve test bodies, helper behavior, fixtures, package metadata, docs/policy references, and the public compatibility module. Validation should include:

- `rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowEventLogSpec.hs`
- `rg -n 'AppServerTurn|AppServerEndpoint|AppServerClientFailure|JsonRpcError|formatAppServerClientFailure|AppServerClientOptions|defaultAppServerClientOptions' test/WorkflowEventLogSpec.hs`
- `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal agent-workflow-*`
- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` when staging is involved
