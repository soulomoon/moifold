### Source Round
- Round id: round-078
- Merged commit: d5b4892
- Evidence: `orchestrator/rounds/round-078/selection.md`, `orchestrator/rounds/round-078/implementation-notes.md`, `orchestrator/rounds/round-078/review.md`, `orchestrator/rounds/round-078/review-record.json`, and `orchestrator/rounds/round-078/merge.md`

### Roadmap Change
- Roadmap id: 2026-05-10-00-facade-removal-readiness
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/roadmap.md`

### Rationale
Round 078 was approved and merged as the behavior-neutral internal import
migration slice for `milestone-002-internal-import-migration` and
`direction-004-core-ids-split-import-migration`. The roadmap now marks
direction 004 complete via commit `d5b4892`.

The accepted evidence shows that selected single-owner `CodexWatcher.Core.Ids`
callers moved to direct owner imports: agent-id-only callers now use
`CodexWatcher.Workflow.Agent.Ids`, and GitHub-id-only callers now use
`CodexWatcher.Workflow.GitHub.Ids`. The round records a starting inventory of
65 `CodexWatcher.Core.Ids` imports and 12 direct owner imports, with the final
inventory at 35 `CodexWatcher.Core.Ids` imports and 42 direct owner imports.
Remaining facade users are explicitly recorded as mixed, deferred, executable
dependency, event-log, repair, runtime compatibility, healthcheck, guard, or
test users rather than treated as removal evidence.

The milestone remains open because
`direction-005-eventlog-permission-readiness` remains pending. Round 078 does
not approve or perform facade removal, deprecation, Cabal exposure changes,
docs or release wording, runtime compatibility-file cleanup, event-schema
changes, healthcheck or repair behavior changes, publication, release, or
package upload. It also does not imply public API approval, facade removal
approval, or any change to the prior terminal-hold boundary.

### State Activation
- Requires state.json roadmap metadata update: no
- Proposed revision remains: rev-001
- New roadmap_dir when applicable: n/a
