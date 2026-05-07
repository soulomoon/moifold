### Squash Commit
- Title: Extract checked-action failure traversal into workflow core
- Summary: This round extracts the reusable checked-action failure traversal and failure-report shape into `agent-workflow-core`, while keeping moifold-specific executors, command reports, classifiers, and daemon failure mapping in the facade layer. Focused coverage now verifies the generic core traversal, facade compatibility, package-boundary guard, daemon failure path, metadata ordering, and dry-run parity.

### Merge Readiness
- Base branch freshness: confirmed. `codex/workflow-facade-extraction` is the configured base branch and is an ancestor of the round worktree HEAD; there is no divergent commit ordering to resolve for this round.
- Merge ordering satisfied: yes. The active roadmap item declares `Merge after: none`, and `orchestrator/state.json` has no pending merge rounds.
- Pending dependencies: none. The active roadmap item declares `Depends on: none`, and review approval records no merge-after dependencies.

### Follow-Up Notes
Merge readiness is confirmed for a squash merge of `orchestrator/round-001-checked-action-failure-core`. Use the squash title above; subsequent rounds can build on `item-001-checked-action-failure-core` once this merge lands.
