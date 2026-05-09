### Squash Commit
- Title: Document import facade cleanup policy
- Summary: This round records an evidence-backed cleanup policy for the six selected public moifold import facades. It refreshes selected-facade import and Cabal exposure evidence, preserves the conservative `keep`/`defer` classifications from the approved inventory and replacement-readiness rounds, updates the framework compatibility policy, and explicitly keeps deprecation, Cabal exposure changes, runtime compatibility-file policy, and facade removal out of scope.
### Merge Readiness
- Base branch freshness: confirmed. The local base branch `codex/workflow-facade-extraction` and round `HEAD` both resolve to `c3ef5cbd0f2549c2a2b134b1cc779f2bd928ddc4`.
- Merge ordering satisfied: yes. The round selection records `depends_on_round_ids: []`, `merge_after_item_ids: []`, no parallel group, and serial controller context; the later runtime compatibility cleanup policy remains a separate sibling direction.
- Pending dependencies: none.
### Follow-Up Notes
The reviewer approved the docs-only round after `cabal build all`, `cabal test watcher-core-test`, workflow package validation, diff checks, selected-facade import scans, Cabal exposure scan, and banned-claim inspection. No implementation source, imports, Cabal descriptors, runtime compatibility files, deprecation pragmas, or removal approvals were changed.
