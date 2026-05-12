### Squash Commit
- Title: Move WorkflowEventLogSpec off EventLog facade owners
- Summary: Updates `test/WorkflowEventLogSpec.hs` so reusable EventLog core and workflow audit assertions import their direct owner modules, while the remaining compatibility-facade uses stay limited to the intentional Moifold bridge-wrapper parity checks.

### Merge Readiness
- Base branch freshness: confirmed. `codex/workflow-facade-extraction` and the round branch resolve to `488ed06ff7ce395a889e5d1bd2f92e5295ae51ef`, and the base branch is an ancestor of the round HEAD.
- Merge ordering satisfied: yes. Round 134 is serial, with no `depends_on_round_ids`, no `merge_after_item_ids`, and no parallel group.
- Pending dependencies: none.

### Follow-Up Notes
Round 134 is approved in `review.md` and `review-record.json`. The review evidence reports focused facade scans, diff checks, `cabal test watcher-core-test`, and `cabal build all` all passed. This merge note does not approve facade removal, deprecation, Cabal exposure changes, docs changes, runtime compatibility changes, event schema changes, or fixture shape changes.
