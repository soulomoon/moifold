### Squash Commit
- Title: Move BoundaryPolicySpec to direct GitHub ids import
- Summary: Round 098 moves the GitHub-only `test/BoundaryPolicySpec.hs` import from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct owner module `CodexWatcher.Workflow.GitHub.Ids`. The boundary-policy assertions, command parity checks, package exposure, production code, and public compatibility facade surface remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed. Local `codex/workflow-facade-extraction`, round branch `HEAD`, and their merge base are all `02093a952e8aab12578c2c8512c7b12df9e96b4d`.
- Merge ordering satisfied: yes. `state.json` records `last_completed_round` as `round-097`, this round has no `depends_on_round_ids`, no `merge_after_item_ids`, and `pending_merge_rounds` is empty.
- Pending dependencies: none.

### Follow-Up Notes
Reviewer approval is recorded in `review.md` and `review-record.json`. The reviewed verification set passed: `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`. Squash merge should include the round implementation diff plus round-098 artifacts only; no package descriptor, roadmap, production, app, fixture, runtime compatibility, parser, renderer, prompt, command-output, replay, healthcheck, repair, or restart behavior changes are part of this round.
