### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-142-pr-review-launch-cli-spec-endpoint-direct-owner-migration`
- Extracted item summary: Migrate only `test/PrReviewLaunchCliSpec.hs` from `CodexWatcher.AppServerClient (AppServerEndpoint (..))` to the direct transport owner import `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`, preserving PR-review launch CLI coverage and leaving the public compatibility facade unchanged.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/PrReviewLaunchCliSpec.hs` only; replace its exact `CodexWatcher.AppServerClient (AppServerEndpoint (..))` import with `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`; preserve all PR-review worker/reviewer launch, dry-run command rendering, endpoint path rendering, runtime-owner skip, JSON-RPC failure, and decode-failure assertions.
- Out of scope: all production files; all other tests and test-support files; `test/AutomaticLoopRunnerSpec.hs`; workflow specs with broader `CodexWatcher.AppServerClient` imports; `test/Main.hs`; `test/TestSupport/Workflow.hs`; `test/FacadeImportPolicySpec.hs` and source-scan policy expectations; public `CodexWatcher.AppServerClient` facade implementation or exports; `CodexWatcher.Workflow.Agent.Codex.Client`; direct owner exports; package descriptors; docs/policy wording; public facade deprecation/removal; Cabal exposure cleanup; package descriptor cleanup; release approval; milestone completion; terminal completion; or public compatibility removal.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds: 1`, so this selection opens one round only.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress after round 141 removed `test/IssueFanoutAppServerSpec.hs` from the remaining `CodexWatcher.AppServerClient` facade importers. Current live scan evidence shows no remaining production `CodexWatcher.AppServerClient` source imports; remaining hits are public facade/exposure, docs/policy references, policy/test support, broader workflow specs, `test/Main.hs`, `test/AutomaticLoopRunnerSpec.hs`, and the endpoint-only `test/PrReviewLaunchCliSpec.hs` import.

This selects a concrete direct-owner migration instead of another readiness-only gate, matching the current steering for this family. `test/PrReviewLaunchCliSpec.hs` imports only `AppServerEndpoint (..)` from the facade, while `AppServerEndpoint (..)` is already exported by the direct owner module `CodexWatcher.Workflow.Agent.Codex.Transport`. Round 123 added the PR-review launch CLI behavior coverage, and round 124 migrated the production `Domain/PrReview/LaunchCli.hs` importer to direct client and transport owners, so this test-side endpoint import can be migrated without changing PR-review launch behavior, app-server protocol, session handling, command rendering, failure formatting, or public compatibility exposure.

The selected slice should run before any public facade or Cabal cleanup because it removes one more concrete remaining test facade importer while keeping policy parity owners and broader facade users intact for later exact selections. `test/AutomaticLoopRunnerSpec.hs` remains out of scope because it imports both `AppServerClientFailure (..)` and `AppServerEndpoint`; workflow specs, `test/Main.hs`, and `test/TestSupport/Workflow.hs` remain broader or policy-sensitive follow-up surfaces.
