### Squash Commit
- Title: Remove stale AppServerClient import from WorkflowEventLogSpec
- Summary: This round completes `round-149-workflow-event-log-spec-appserverclient-import-cleanup` by removing the now-unused exact `import CodexWatcher.AppServerClient` line from `test/WorkflowEventLogSpec.hs`. The approved implementation is import-only: no replacement import, no test-body changes, no production changes, no Cabal or docs changes, and no public compatibility facade deprecation or removal.

### Merge Readiness
- Base branch freshness: confirmed. `codex/workflow-facade-extraction` resolves to `4fa33392f5f36bc6879dfdef95af82ecba380764`, `HEAD` is the same commit, `git merge-base codex/workflow-facade-extraction HEAD` is the same commit, `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` passed, and `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reported `0 0`. The uncommitted round diff is therefore prepared directly on the current local base.
- Merge ordering satisfied: yes. `orchestrator/state.json` records `stage: "merge"`, `active_round_id: "round-149"`, active round `stage: "merge"`, `merge_ready: true`, `depends_on_round_ids: []`, `merge_after_item_ids: []`, `parallel_group: null`, and `pending_merge_rounds: []`.
- Pending dependencies: none.
- Review approval: confirmed. `orchestrator/rounds/round-149/review.md` has decision `APPROVED`, and `orchestrator/rounds/round-149/review-record.json` records `"decision": "approved"` for `round-149-workflow-event-log-spec-appserverclient-import-cleanup`.

### Expected Files
- `test/WorkflowEventLogSpec.hs`: expected implementation change; diff is exactly the deletion of `import CodexWatcher.AppServerClient`.
- `orchestrator/rounds/round-149/merge.md`: expected merger artifact for this role.
- `orchestrator/state.json`: existing controller-owned state modification observed and preserved; this merger did not edit it.
- No source, test-body, Cabal, docs, public facade, roadmap, review, plan, or implementation-note edits are part of the merger role.

### Validation Evidence
- `git diff -- test/WorkflowEventLogSpec.hs`: passed; current diff is exactly one import-line deletion.
- `rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowEventLogSpec.hs`: passed with no matches.
- `rg -n 'AppServerTurn|AppServerEndpoint|AppServerClientFailure|JsonRpcError|formatAppServerClientFailure|AppServerClientOptions|defaultAppServerClientOptions' test/WorkflowEventLogSpec.hs`: passed with no matches.
- `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal agent-workflow-*`: passed as inventory for this round; no match remains in `test/WorkflowEventLogSpec.hs`, and remaining matches are out of scope follow-ups.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; there are no staged files.
- Reviewer-recorded baseline checks also passed: `cabal test watcher-core-test` and `cabal build all`.

### Explicit Non-Goals
- No production code changes.
- No test-body, helper, fixture, assertion, or test-registration changes.
- No replacement import in `test/WorkflowEventLogSpec.hs`.
- No changes to `src/CodexWatcher/AppServerClient.hs`.
- No Cabal exposed-module cleanup.
- No documentation or deprecation-policy cleanup.
- No public compatibility facade deprecation, removal, exposure change, or migration requirement.
- No runtime compatibility-file changes.
- No release, publication, milestone-completion, roadmap-terminal, or family-closeout claim.

### Follow-Up Notes
Remaining `CodexWatcher.AppServerClient` users are explicitly outside this round and need later exact selections and reviewed gates:

- `moifold.cabal`
- `src/CodexWatcher/AppServerClient.hs`
- `test/BoundaryPolicySpec.hs`
- `test/WorkflowExecutionSpec.hs`
- `test/Main.hs`
- `docs/agentic-workflow-framework/package-extraction-readiness.md`
- `docs/agentic-workflow-framework/release-notes.md`
- `docs/agentic-workflow-framework/release-candidate-bundle.md`
- `docs/agentic-workflow-framework/package-identity-versioning-contract.md`
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`

Ready for the controller to squash merge once it performs its normal final status check. This artifact does not commit, stage, merge, or update controller state.
