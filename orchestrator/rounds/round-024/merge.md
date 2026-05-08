### Squash Commit
- Title: Harden IssueImplement lifecycle ownership after indexed routing
- Summary: Round 024 hardens the IssueImplement lifecycle after full indexed daemon routing by adding focused coverage for child launch manifests and dry-run command shape, launch write ordering, runtime terminal success gating through issue-close verification, healthcheck lifecycle reporting, repair CLI ordering, and package-boundary source scans. The approved diff keeps lifecycle ownership in moifold, preserves compatibility facade behavior, avoids event codec and golden fixture changes, and only exports the pure IssueFanout helpers needed for the new tests.

### Merge Readiness
- Base branch freshness: confirmed locally. The round branch is based exactly on `codex/workflow-facade-extraction` at `ce5abf0` (`Mark workflow roadmap round 023 complete`), with `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` returning `0 0`; `origin` does not currently advertise a `codex/workflow-facade-extraction` branch to compare.
- Merge ordering satisfied: yes. The declared merge-after dependency `item-023-indexed-issue-implementation-close-daemon` is present on base via implementation commit `b712ce2` and roadmap completion commit `ce5abf0`; round 023's `merge.md` also records no pending dependencies.
- Pending dependencies: none. `review.md` and `review-record.json` approve round 024 after `cabal test watcher-core-test`, `cabal build all`, whitespace checks, required source scans, lifecycle routing scans, and golden/event codec diff checks all passed.

### Follow-Up Notes
The current round worktree contains the approved unstaged implementation diff plus this merge handoff; no staging, commit, or merge has been performed. The controller can squash this round after preserving the reviewed diff and then advance to the next roadmap item.
