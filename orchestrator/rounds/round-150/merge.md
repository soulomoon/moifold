### Squash Commit
- Title: Remove stale AppServerClient import from WorkflowExecutionSpec
- Summary: Round 150 completes `round-150-workflow-execution-spec-stale-appserverclient-import-removal` by deleting only the stale `import CodexWatcher.AppServerClient` line from `test/WorkflowExecutionSpec.hs`. No replacement import was added, no test body or helper changed, and no production, Cabal, docs, compatibility facade, policy, or roadmap files are part of the implementation change.

### Merge Readiness
- Base branch freshness: confirmed. Current base branch `codex/workflow-facade-extraction`, branch HEAD, and merge base are all `dc0d94e`; `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` passed.
- Merge ordering satisfied: yes. `orchestrator/state.json` has `stage: "merge"`, `active_round_id: "round-150"`, active round `stage: "merge"`, `merge_ready: true`, empty `depends_on_round_ids`, empty `merge_after_item_ids`, and empty `pending_merge_rounds`.
- Pending dependencies: none.
- Review approval: approved. `orchestrator/rounds/round-150/review.md` records no findings and decision `APPROVED`; `review-record.json` records `"decision": "approved"`.
- Expected files: implementation diff is limited to `test/WorkflowExecutionSpec.hs`; merger output is this file, `orchestrator/rounds/round-150/merge.md`. The tracked diff also includes pre-existing controller-owned `orchestrator/state.json`, which is not part of the implementation change and was not edited by this merger.
- Validation evidence: current `git diff --check` passed; current `git diff --cached --check` passed; current selected-file facade scan `rg -n "^import CodexWatcher\\.AppServerClient$|CodexWatcher\\.AppServerClient" test/WorkflowExecutionSpec.hs` returned no matches; current selected-file AppServerClient-owned symbol scan returned no matches; current broad facade scan shows only expected out-of-scope users. Review evidence also records `cabal test watcher-core-test` passed, `cabal build all` passed, selected-file diff is exactly one import-line deletion, and staged whitespace check passed.

### Non-Goals
- No production code changes.
- No test body, helper, assertion, fixture, runner wiring, or failure-message changes.
- No replacement direct-owner import in `test/WorkflowExecutionSpec.hs`.
- No changes to `src/CodexWatcher/AppServerClient.hs`, Cabal exposure, docs, public facade availability, compatibility policy, deprecation wording, runtime compatibility files, roadmap state, or milestone completion claims.
- No claim that `CodexWatcher.AppServerClient` is deprecated, removable, or fully migrated.

### Follow-Up Notes
Remaining `CodexWatcher.AppServerClient` users are expected and out of scope for this round:

- `moifold.cabal`: exposed-module entry for the public compatibility facade.
- `src/CodexWatcher/AppServerClient.hs`: public compatibility facade module.
- `test/Main.hs`: remaining exact import.
- `test/BoundaryPolicySpec.hs`: policy/reference strings.
- `docs/agentic-workflow-framework/release-candidate-bundle.md`: compatibility facade references.
- `docs/agentic-workflow-framework/release-notes.md`: compatibility facade reference.
- `docs/agentic-workflow-framework/package-extraction-readiness.md`: compatibility facade references.
- `docs/agentic-workflow-framework/package-identity-versioning-contract.md`: compatibility facade reference.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`: compatibility/deprecation policy references.

This round is ready for the controller to squash merge after preserving the existing controller-owned state change and this merge artifact according to the repo-local orchestrator flow.
