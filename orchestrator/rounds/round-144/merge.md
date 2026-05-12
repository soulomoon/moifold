### Squash Commit
- Title: Move RunnerGuardSpec to AppServerClient owner imports
- Summary: Round 144 moves only `test/RunnerGuardSpec.hs` off the `CodexWatcher.AppServerClient` compatibility facade by importing `AppServerClientFailure (..)`, `JsonRpcError (..)`, and `formatAppServerClientFailure` from `CodexWatcher.Workflow.Agent.Codex.Client`, and `AppServerEndpoint` from `CodexWatcher.Workflow.Agent.Codex.Transport`. The implementation diff is import-only and preserves the existing RunnerGuard assertions, fixtures, failure formatting, repair-launch sequencing, endpoint-backed fake app-server coverage, and guard config helper coverage.

### Merge Readiness
- Base branch freshness: confirmed locally. `HEAD`, `orchestrator/round-144-highest-value-cleanup-slice`, and `codex/workflow-facade-extraction` all resolve to `915141f5abc260d97e188c4442a531425be9a5bb`; `git diff --name-status codex/workflow-facade-extraction...HEAD` is empty. `origin` does not advertise a `codex/workflow-facade-extraction` remote ref, so freshness is verified against the local base branch named in `orchestrator/state.json`.
- Merge ordering satisfied: yes. `orchestrator/state.json` has `stage: "merge"`, active round `round-144`, `merge_ready: true`, `depends_on_round_ids: []`, `merge_after_item_ids: []`, `parallel_group: null`, `pending_merge_rounds: []`, and `max_parallel_rounds: 1`.
- Pending dependencies: none.
- Review evidence: `orchestrator/rounds/round-144/review-record.json` records `decision: "approved"`, and `review.md` marks the round `APPROVED`.

### Selected Scope
- Milestone: `milestone-003-import-convergence-package-boundaries`.
- Direction: `direction-010-appserverclient-import-convergence`.
- Extracted item: `round-144-runner-guard-spec-appserverclient-direct-owner-migration`.
- Scope approved for merge: the `test/RunnerGuardSpec.hs` AppServerClient direct-owner import migration only, plus the round artifacts and orchestrator control state for round 144.

### Expected Files In Merge
- `test/RunnerGuardSpec.hs`
- `orchestrator/state.json`
- `orchestrator/rounds/round-144/selection.md`
- `orchestrator/rounds/round-144/plan.md`
- `orchestrator/rounds/round-144/implementation-notes.md`
- `orchestrator/rounds/round-144/review.md`
- `orchestrator/rounds/round-144/review-record.json`
- `orchestrator/rounds/round-144/merge.md`

### Checks Already Passed
- `rg -n "CodexWatcher\\.AppServerClient|Workflow\\.Agent\\.Codex\\.(Client|Transport)|AppServerClientFailure|JsonRpcError|formatAppServerClientFailure|AppServerEndpoint" test/RunnerGuardSpec.hs`
- `rg -n "CodexWatcher\\.AppServerClient" src app test docs *.cabal agent-workflow-* || true`
- `git diff -- test/RunnerGuardSpec.hs`
- `git diff --name-only`
- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check`

### Follow-Up Notes
This merge does not approve public facade deprecation or removal, Cabal exposure cleanup, public API cleanup, package descriptor cleanup, docs cleanup, milestone completion, release approval, terminal completion, or any broader compatibility-surface removal. Remaining `CodexWatcher.AppServerClient` facade users, facade exposure, policy references, and documentation cleanup stay out of scope for later approved rounds.
