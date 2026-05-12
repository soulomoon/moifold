### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-143-automatic-loop-runner-spec-appserverclient-direct-owner-migration`
- Extracted item summary: Move only `test/AutomaticLoopRunnerSpec.hs` off the `CodexWatcher.AppServerClient` compatibility facade by importing `AppServerClientFailure (..)` from `CodexWatcher.Workflow.Agent.Codex.Client` and `AppServerEndpoint` from `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/AutomaticLoopRunnerSpec.hs` import-only migration for `AppServerClientFailure (..)` and `AppServerEndpoint`; focused validation that automatic-loop runner tests still exercise the same endpoint-backed execution, dry-run, and retry-classification behavior; selected-file and broad `CodexWatcher.AppServerClient` scans showing this spec no longer imports the facade.
- Out of scope: production code, test bodies, helper exports, test-suite wiring, Cabal metadata, docs/policy text, public facade exposure, Cabal exposed-module cleanup, package descriptor cleanup, deprecation, public API removal, runtime compatibility files, protocol/client/transport implementation changes, broader workflow spec migrations, `test/Main.hs`, and terminal milestone completion.
- Concurrent batch context: none; state has `max_parallel_rounds: 1`, and this round is a serial import-convergence slice after rounds 140-142.

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
Milestone 003 is still in progress and direction 010 remains the active AppServerClient import-convergence direction. Rounds 140, 141, and 142 already migrated the same exact endpoint-only test-support/spec pattern from `test/TestSupport/AppServer.hs`, `test/IssueFanoutAppServerSpec.hs`, and `test/PrReviewLaunchCliSpec.hs` to the direct transport owner, with behavior preserved and the public facade left exposed.

The live scan after round 142 still lists `test/AutomaticLoopRunnerSpec.hs` importing `CodexWatcher.AppServerClient (AppServerClientFailure (..), AppServerEndpoint)`. Current direct-owner evidence shows `AppServerClientFailure (..)` is exported by `CodexWatcher.Workflow.Agent.Codex.Client` and `AppServerEndpoint` is exported by `CodexWatcher.Workflow.Agent.Codex.Transport`, matching the user's steering and the roadmap's replacement ownership. This is a concrete behavior-preserving direct-owner migration with sufficient current evidence, so it should run before any readiness-only, policy-only, docs, public facade, or Cabal exposure work.
