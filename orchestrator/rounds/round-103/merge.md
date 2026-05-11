### Squash Commit
- Title: Record Core.Ids remaining blocker readiness
- Summary: Round 103 records artifact-only readiness evidence for the remaining `CodexWatcher.Core.Ids` import set after rounds 098 through 102. The approved evidence confirms the five prior safe single-domain candidates no longer import the facade, records the live 39-import remaining set, classifies the remaining users as blocker-class or test-policy evidence surfaces, and recommends closing direction 011's current single-domain queue before any later split-import or bridge-readiness work.

### Merge Readiness
- Base branch freshness: confirmed. `HEAD`, the configured local base `codex/workflow-facade-extraction`, and their merge-base all resolve to `698ab995403fc8eb3a79f97ca58a646686cca74d`, with ahead/behind count `0/0`. `origin` has no `origin/codex/workflow-facade-extraction` ref; after fetching `origin main`, `origin/main` is an ancestor of `HEAD` with ahead/behind count `0/238`.
- Merge ordering satisfied: yes. Controller state is at `stage: merge` for active `round-103`, `max_parallel_rounds` is `1`, `pending_merge_rounds` is empty, `last_completed_round` is `round-102`, and both `review.md` and `review-record.json` approve `round-103-core-ids-remaining-blocker-readiness`.
- Pending dependencies: none. The selection and controller state declare empty `depends_on_round_ids` and empty `merge_after_item_ids`, with no parallel group.

### Follow-Up Notes
Ready for squash merge as an artifact-only readiness round. Keep the squash focused on round-103 artifacts and the existing controller-owned state transition; do not include source, test, app, package descriptor, roadmap, public facade, fixture, runtime compatibility, parser, renderer, command-output, event-schema, prompt, healthcheck, repair, replay, restart, behavior, deprecation, Cabal exposure removal, release approval, milestone completion, or terminal-completion changes.
