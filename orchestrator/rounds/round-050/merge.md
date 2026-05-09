### Squash Commit
- Title: Add release candidate evidence bundle
- Summary: Adds the round-050 release-candidate evidence bundle for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, plus a narrow documentation index link and round artifacts. The bundle is evidence-only input for the later publication gate: it records package artifacts, validation, docs, CI configuration, consumer validation, compatibility policy, and remaining blockers without uploading packages, triggering release machinery, or making the final publish/hold decision.

### Merge Readiness
- Base branch freshness: confirmed. `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` returned `0 0` in this worktree.
- Merge ordering satisfied: yes. The round depends on rounds 036-049 and merge-after items 036-049; the controller-observed launch state says those dependency rounds are already merged into the active roadmap/base, and this branch is current with `codex/workflow-facade-extraction`.
- Pending dependencies: none for this squash merge. The reviewed payload is approved for `item-050-release-candidate-bundle`; `direction-016-explicit-publication-gate` remains a later consumer of this evidence, not a prerequisite for merging this round.

### Follow-Up Notes
Hosted GitHub Actions CI was not observed on branch `orchestrator/round-050-external-package-slice`; local CI configuration scans and local validation commands passed, but this should not be reported as a hosted CI pass.

Haddock generation passed for the three workflow packages, but missing per-export documentation and link-destination warnings remain to classify at the terminal publication gate.

Do not treat this merge as a publication approval. The bundle intentionally preserves the later explicit publish/hold decision and does not authorize package upload, tags, release announcements, or workflow-triggering actions.
