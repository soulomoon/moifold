### Squash Commit
- Title: Port IssueImplement policy transitions to indexed adapter
- Summary: This round adds the moifold-owned indexed IssueImplement adapter and exposes it from the main library, then proves indexed-vs-compatibility parity across the IssueImplement policy surface. It also aligns ignored merged-PR compatibility and replay behavior with the existing state-machine idempotent sleep behavior, while keeping live daemon routing unchanged.

### Merge Readiness
- Base branch freshness: confirmed locally. `orchestrator/round-018-indexed-issue-implementation-policy` and `codex/workflow-facade-extraction` both point at `12c9aff`, and the merge-base is the same commit. No upstream is configured for `codex/workflow-facade-extraction`, so remote freshness was not applicable from this worktree.
- Merge ordering satisfied: yes. Roadmap item `item-018-indexed-issue-implementation-policy` declares `Merge after: item-017-indexed-issue-implementation-next-domain-plan`; item 017 is marked done in rev-004 and the user confirmed it is already completed on base.
- Pending dependencies: none.

### Follow-Up Notes
Next round `item-019-indexed-issue-implementation-plan-and-pr-setup-daemon` can begin routing live plan-mode and PR setup IssueImplement observations through the indexed adapter. Preserve the current boundary: PR discovery, branch advancement, command parsing, compatibility writes, dry-run text, action ordering, and request-id behavior stay moifold-owned and text-compatible.
