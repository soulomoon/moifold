### Squash Commit
- Title: Route IssueImplement post-merge review daemon observations through indexed projection
- Summary: Round 022 routes the post-merge final-review daemon surface through the moifold-owned indexed IssueImplement projection, then projects back to the existing daemon transaction surface. The approved diff covers final-review turn start plus clean, rework-required, incomplete, and blocked final-review outcomes, with dry-run/execute parity tests and source-scan guards preserving domain classifier ownership and compatibility boundaries.

### Merge Readiness
- Base branch freshness: confirmed. `orchestrator/round-022-indexed-issue-implementation-post-merge-review-daemon` is based on `a48cb7d`, matching local `codex/workflow-facade-extraction`; `a48cb7d` marks item 021 done after implementation commit `758cfe4`.
- Merge ordering satisfied: yes. Item 022 declares `Merge after: item-021-indexed-issue-implementation-handoff-and-merge-wait-daemon`, and item 021 is complete on base.
- Pending dependencies: none.

### Follow-Up Notes
Next round item 023 should keep the handoff from this round narrow: terminal issue-close polling and `ObservedIssueClosed` routing remain intentionally outside item 022 and should be handled there. Preserve the current domain ownership for final-review classification, prompt/version validation, reviewed-commit validation, and missing-field diagnostics.
