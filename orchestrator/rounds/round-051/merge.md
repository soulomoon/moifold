### Squash Commit
- Title: Record publication gate hold decision
- Summary: Records the terminal publication-gate decision for `item-051-explicit-publication-gate` as a deliberate hold for the `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates. The approved docs-only payload adds the decision record, links it from the framework docs index, and preserves the round artifacts showing that package validation, local build/test, Haddock generation, consumer example validation, CI configuration scans, and no-publication scans were reviewed without authorizing any externally visible publication action.

### Merge Readiness
- Base branch freshness: confirmed. `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` returned `0 0` for branch `orchestrator/round-051-external-package-slice`.
- Merge ordering satisfied: yes. Round 051 depends on rounds 036-050 and merge-after items 036-050; controller-observed launch state says rounds 036-050 are already merged into the active roadmap/base, and round 050 supplied the release-candidate evidence bundle consumed by this terminal gate.
- Pending dependencies: none for this squash merge. The reviewed payload is approved for `item-051-explicit-publication-gate`; publication remains deliberately held and is not a dependency for merging this docs-only decision record.

### Follow-Up Notes
Publication is deliberately held because hosted CI was not observed for the current branch, Haddock per-export and link-destination warnings remain, and there is no explicit operator approval for externally visible package upload.

This merge does not authorize package upload, Hackage publication, tag creation, GitHub release creation, release announcements, publication commands, or workflow-triggering actions.

`orchestrator/state.json` has an unrelated unstaged change in this worktree and was not edited by the merger role.
