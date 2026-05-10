### Squash Commit
- Title: Record compatibility fixture gap inventory
- Summary: Records the approved artifact-only compatibility fixture gap inventory for round-087, covering planning, daemon, block, repair, runtime-owner, checked-in compatibility snapshots, and live `issue-snapshot.json` surfaces. The round documents current producers/readers, healthcheck read and non-read behavior, existing fixture coverage, policy references, and prioritized blockers without changing production code, tests, Cabal files, docs, fixtures, roadmap files, runtime behavior, compatibility file names, or compatibility surface availability.

### Merge Readiness
- Base branch freshness: confirmed. `git merge-base HEAD codex/workflow-facade-extraction`, `git rev-parse HEAD`, and `git rev-parse codex/workflow-facade-extraction` all resolved to `6ca732f54f125cd67dc14e542093d75b659f5f7b`.
- Merge ordering satisfied: yes. Round state and selection declare no `depends_on_round_ids`, no `merge_after_item_ids`, no `parallel_group`, and `pending_merge_rounds` is empty.
- Pending dependencies: none. `review.md` and `review-record.json` approve the artifact-only inventory, and `git diff --check` passed.

### Follow-Up Notes
`git status --short --untracked-files=all` shows the expected controller-owned state change and round-local artifacts only: `orchestrator/state.json`, selection, plan, compatibility fixture gap inventory, implementation notes, review, review record, and this merge artifact. The squash merge should preserve the inventory's non-goal boundary: it is evidence for later fixture/healthcheck/contract rounds, not approval for deletion, rename, deprecation, migration, Cabal exposure changes, or runtime behavior changes.
