### Squash Commit
- Title: Record no-lawful-removal hold status
- Summary: Record the approved artifact-only round-072 status that milestone 008 is dependency-reached but blocked and held for removal because no exact public import facade or runtime compatibility surface has satisfied every active removal gate and exact reviewer approval. The round preserves the round-071 external/operator/downstream blockers, classifies both milestone-008 removal directions as not currently lawful, leaves compatibility behavior unchanged, and does not select milestone 009.

### Merge Readiness
- Base branch freshness: confirmed. `HEAD`, `codex/workflow-facade-extraction`, and their merge base are all `3efc9ce24d453886f96dd527045e7e91f622a730`; `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reports `0	0`.
- Merge ordering satisfied: yes. `selection.md` declares no `depends_on_round_ids`, no `merge_after_item_ids`, and no `parallel_group`; there is no concurrent batch ordering to satisfy for this artifact-only hold/status round.
- Pending dependencies: none for merge preparation. The round is explicitly approved in `review.md`, and `review-record.json` has `"decision": "approved"`.

### Follow-Up Notes
This is a hold/status artifact only. Milestone 008 is not complete, no deprecation or removal is approved, milestone 009 is not selected, and no package publication, upload, release, Cabal exposure change, production import rewrite, compatibility schema change, runtime compatibility behavior change, healthcheck change, repair change, replay change, restart-script change, or operator behavior change is approved by this round.

Cleanup remains gated on a later selected round that names an exact surface, records every satisfied gate, preserves or proves the required behavior and downstream/operator evidence, records any needed unsupported-user decision, and receives exact reviewer/operator approval for that surface.
