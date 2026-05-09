### Squash Commit
- Title: Document runtime compatibility cleanup policy
- Summary: Adds the runtime compatibility-file cleanup policy to the framework compatibility/deprecation docs and records the round-local evidence artifact for round 057. The policy preserves event logs as workflow truth, treats runtime compatibility files as moifold-owned operator/runtime contracts, keeps classifications conservative from the round 053 inventory and round 055 behavior gates, and makes clear that no selected runtime compatibility surface is approved for migration, schema change, write-timing change, behavior change, deprecation, or removal.
### Merge Readiness
- Base branch freshness: confirmed; local `codex/workflow-facade-extraction` and the round worktree both resolve to `53d355a02b37a62eb4f43337552110b215d9baa5`, with the round changes applied as the current worktree delta.
- Merge ordering satisfied: yes; scheduler fields list no `depends_on_round_ids` and no `merge_after_item_ids`, the serial controller context has no concurrent batch, and the prerequisite runtime behavior gates from round 055 plus sibling import-facade policy from round 056 are already complete in the base history.
- Pending dependencies: none
### Follow-Up Notes
Round 057 is approved by `review.md` and `review-record.json`. The reviewed diff is docs/policy/artifact-only: `docs/agentic-workflow-framework/compatibility-deprecation-policy.md` plus round-local artifacts under `orchestrator/rounds/round-057/`; `orchestrator/project-contract.md` remains unchanged because its existing runtime compatibility-file invariant already covers the policy.
