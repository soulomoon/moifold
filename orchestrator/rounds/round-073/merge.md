### Squash Commit
- Title: Record final compatibility surface report
- Summary: Round 073 records the final compatibility-surface report for the approved rev-003 hold path. The report keeps public import facades and runtime compatibility surfaces available, records the removed-surface set as empty, carries forward round 071 and round 072 blockers, preserves directions 021 and 022 as held/not currently lawful, and leaves direction 024, publication, release, deprecation, migration, removal, Cabal exposure changes, production import rewrites, and compatibility behavior changes out of scope.

### Merge Readiness
- Base branch freshness: confirmed. `HEAD` is `6852b70` on `orchestrator/round-073-final-compatibility-surface-report`, and `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` passed. This is acceptable for the artifact-only round because there is no tracked diff and changed paths are round-local artifacts.
- Merge ordering satisfied: yes. `selection.md` declares no `depends_on_round_ids` and no `merge_after_item_ids`; rev-003 names this held-path final report as the lawful serial dispatch after the approved round 072 hold status.
- Pending dependencies: none blocking merge. The carried-forward external evidence, approval, unsupported-user, and per-surface blockers remain cleanup blockers recorded by the report, not blockers to merging this approved report artifact.

### Follow-Up Notes
This merge preparation does not approve removal, migration, deprecation, package publication, release, Cabal exposure changes, production import rewrites, compatibility behavior changes, or `direction-024-terminal-cleanup-gate`.

Focused readiness checks passed for status, current head, base ancestry, review-record approval, absent worker fan-out, changed-path confinement, diff checks, and trailing-whitespace scan. `cabal build all`, `cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh` remain skipped under the rev-003 artifact-only allowance.
