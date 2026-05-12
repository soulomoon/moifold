### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-144-runner-guard-spec-appserverclient-direct-owner-migration`
- Extracted item summary: Move only `test/RunnerGuardSpec.hs` off the `CodexWatcher.AppServerClient` compatibility facade by importing `AppServerClientFailure (..)`, `JsonRpcError (..)`, and `formatAppServerClientFailure` from `CodexWatcher.Workflow.Agent.Codex.Client`, and `AppServerEndpoint` from `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/RunnerGuardSpec.hs` import-only migration for `AppServerClientFailure (..)`, `JsonRpcError (..)`, `formatAppServerClientFailure`, and `AppServerEndpoint`; preserve the existing active-turn inspection, materialization fallback, failure-formatting, repair-launch sequence, endpoint-backed fake app-server, and runner guard config coverage.
- Out of scope: production code; test bodies; helper modules; test-suite wiring; package descriptors; docs/policy text; public `CodexWatcher.AppServerClient` facade implementation, exports, or Cabal exposure; direct owner module exports; broader workflow specs; `test/Main.hs`; `test/TestSupport/Workflow.hs`; `test/FacadeImportPolicySpec.hs`; runtime compatibility files; deprecation; public API removal; package descriptor cleanup; milestone completion; release approval; terminal completion; or public compatibility removal.
- Concurrent batch context: none; state has `max_parallel_rounds: 1`, and this round is a serial import-convergence slice after rounds 140-143.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress after round 143 removed `test/AutomaticLoopRunnerSpec.hs` from the remaining `CodexWatcher.AppServerClient` facade importers. Current live scan evidence still lists `test/RunnerGuardSpec.hs` importing `CodexWatcher.AppServerClient` for `AppServerClientFailure (..)`, `AppServerEndpoint`, `JsonRpcError (..)`, and `formatAppServerClientFailure`, while broader workflow specs, `test/Main.hs`, `test/TestSupport/Workflow.hs`, public facade/exposure, docs, and policy references remain for later exact selections.

This selects a concrete behavior-preserving direct-owner migration instead of another readiness-only gate, matching current steering and the accepted round 140-143 pattern. The direct owner evidence is already present: `CodexWatcher.Workflow.Agent.Codex.Client` exports the failure type, JSON-RPC error type, and failure formatter, while `CodexWatcher.Workflow.Agent.Codex.Transport` exports `AppServerEndpoint`. RunnerGuard production migration has already landed, and the RunnerGuard behavior blockers from rounds 110-112 were satisfied before that production import move; this test-side import migration can therefore stay import-only without changing endpoint parsing, app-server protocol, request sequencing, failure formatting, repair-launch behavior, or public compatibility exposure.

The selected slice should run before public facade or Cabal cleanup because it removes another concrete remaining test facade importer while keeping policy parity owners and broader workflow surfaces intact for later exact selections.
