### Squash Commit
- Title: Record external operator inventory evidence
- Summary: Round 071 adds an artifact-only external operator and downstream inventory for the milestone-005 public import facades and milestone-006 runtime compatibility paths. The approved artifacts record observed repo-local consumers, unavailable external/downstream evidence, blocked operator evidence, unsupported-user decision gaps, and per-surface cleanup blockers without changing production behavior.

### Merge Readiness
- Base branch freshness: confirmed. `HEAD`, `codex/workflow-facade-extraction`, and their merge base are all `69f6203883cfdecd35a1dcc6fbae1ac817712224`; `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` returned `0	0`.
- Merge ordering satisfied: yes. Round 071 declares no `depends_on_round_ids`, no `merge_after_item_ids`, and no `parallel_group`; the selection records the default serial lane for this active round.
- Pending dependencies: none.

### Follow-Up Notes
`review.md` explicitly approved the round, and `review-record.json` records `decision: approved`.

Inventory completion is evidence only. It does not approve deprecation, migration, removal, publication, upload, release, Cabal exposure changes, production import rewrites, or schema, filename, event, write-timing, planner-turn, projection, healthcheck, repair, replay, restart-script, or operator behavior changes.

Remaining cleanup and removal decisions stay gated behind milestone 008 and require explicit reviewer/operator evidence. Local absence of external repositories, live archives, operator scripts, hosted CI, uploads, tags, releases, release announcements, or unsupported-user decisions must remain classified as unavailable, blocked, or undecided evidence rather than approval.
