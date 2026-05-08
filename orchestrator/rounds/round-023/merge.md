### Squash Commit
- Title: Route IssueImplement issue-close daemon observations through indexed projection
- Summary: Round 023 routes `IssueWaitingForIssueClose` plus `ObservedIssueClosed` through the moifold-owned indexed IssueImplement projection while preserving the existing daemon result surface. The approved diff keeps close polling and retry ownership in the domain loop, preserves `CloseIssue` before `SleepUntilNextPoll`, wrong-PR rejection, dry-run close rendering, execute-mode idle text, terminal `IssueComplete` evidence, `StopDaemon`, compatibility writes, request-id behavior, and daemon parity coverage.

### Merge Readiness
- Base branch freshness: confirmed locally. The round branch is based exactly on `codex/workflow-facade-extraction` at `35cda48` (`Mark workflow roadmap round 022 complete`), with `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` returning `0 0`; `origin` does not currently advertise a `codex/workflow-facade-extraction` branch to compare.
- Merge ordering satisfied: yes. The declared merge-after dependency `item-022-indexed-issue-implementation-post-merge-review-daemon` is present on base via implementation commit `5254194` and roadmap completion commit `35cda48`.
- Pending dependencies: none for this round. `review.md` and `review-record.json` both approve round 023, with `cabal test watcher-core-test`, `cabal build all`, and `git diff --check` recorded as passing.

### Follow-Up Notes
Next round should start `item-024-indexed-issue-implementation-lifecycle-hardening` after this squash merge updates the base and marks item 023 done. Keep the item-024 audit focused on lifecycle, repair, healthcheck, child ownership, and compatibility-facade cleanup after all live IssueImplement daemon observations have indexed routing.
