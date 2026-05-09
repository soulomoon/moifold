### Squash Commit
- Title: Record PR state compatibility evidence
- Summary: Adds round-local evidence for `direction-017-pr-state-external-path-inventory`, documenting current PR review compatibility state files, issue PR URL field usage, absence of checked-in dedicated PR URL/state paths, snapshot and healthcheck readback, runbook/script/operator expectations, test and golden fixture coverage, current keep/defer classifications, and conservative blockers before later cleanup decisions.

### Merge Readiness
- Base branch freshness: confirmed. `HEAD`, `codex/workflow-facade-extraction`, and their merge base are all `f643b52ab476325287defd3db7cdd54b4811088c`; `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reports `0 0`.
- Merge ordering satisfied: yes. `selection.md` declares no `depends_on_round_ids`, no `merge_after_item_ids`, no parallel group, and `orchestrator/state.json` has `pending_merge_rounds: []` with `round-068` in merge stage.
- Pending dependencies: none.

### Follow-Up Notes
This round is evidence-only. It does not approve filename changes, schema changes, event `type` changes, PR review projection changes, PR URL storage migration, healthcheck or repair redesign, cleanup, deprecation, removal, publication, upload, or release.

Later rounds should preserve the current `keep` classification for PR review state files and issue `pr_url`, and keep dedicated PR URL/state path conclusions deferred until external operator/downstream expectations or old live-state evidence are inventoried.
