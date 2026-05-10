### Source Round
- Round id: round-073
- Merged commit: 37cde0a
- Evidence: `orchestrator/rounds/round-073/final-compatibility-surface-report.md`, `orchestrator/rounds/round-073/review.md`, `orchestrator/rounds/round-073/review-record.json`, and `orchestrator/rounds/round-073/merge.md`

### Roadmap Change
- Roadmap id: 2026-05-09-01-compatibility-surface-cleanup
- Prior revision: rev-003
- Proposed revision: rev-003
- Files changed: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/roadmap.md`

### Rationale
Round 073 was approved as the artifact-only final compatibility-surface report
for the rev-003 hold path and merged as commit `37cde0a`. The roadmap now
marks `direction-023-final-compatibility-surface-report` complete through that
round and records that milestone 009 has report evidence on the approved hold
path. Milestone 009 remains pending because
`direction-024-terminal-cleanup-gate` still needs to be selected, reviewed, and
accepted before the family can be marked terminal.

This is a status-only same-revision update. It preserves milestone 008 as held,
not removal-complete, and keeps `direction-024-terminal-cleanup-gate` pending
as the next lawful dispatch after the final report. It does not imply package
publication, public release, upload, deprecation, migration, removal, Cabal
exposure changes, production import rewrites, compatibility behavior changes,
or terminal cleanup completion.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
