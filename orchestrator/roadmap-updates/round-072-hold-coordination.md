### Source Round
- Round id: `round-072`
- Merged commit: `0821ca8907a49070a4ec4b064427633ef4a6a59e`
- Evidence: `orchestrator/rounds/round-071/external-operator-downstream-inventory.md`, `orchestrator/rounds/round-071/review.md`, `orchestrator/rounds/round-072/selection.md`, `orchestrator/rounds/round-072/no-lawful-removal-surface-status.md`, `orchestrator/rounds/round-072/review.md`, `orchestrator/rounds/round-072/review-record.json`, `orchestrator/rounds/round-072/merge.md`, `orchestrator/roadmap-updates/round-072-roadmap-update.md`, `orchestrator/roadmap-updates/round-072-roadmap-update-review.md`, and recovery diagnosis that rev-002 has a scheduling dead end because milestone 008 is held while milestone 009 depends on milestone 008.

### Roadmap Change
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-003`
- Files changed: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/roadmap.md`, `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/verification.md`, and `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/retry-subloop.md`

### Rationale
Rev-002 correctly records the approved round-072 hold: `milestone-008-gated-compatibility-removals` is dependency-reached after milestone 007, but no exact public import facade or runtime compatibility surface currently satisfies every removal gate and exact reviewer approval. Rev-002 also keeps milestone 009 pending because it depends on milestone 008.

That creates a scheduling dead end for the controller. Selecting a normal milestone-008 removal would invent removal scope, while selecting milestone 009 under rev-002 would violate its dependency. Rev-003 resolves the coordination problem by preserving milestone 008 as held, not complete, and making that explicit hold a lawful predecessor for milestone 009 final hold/report work.

The next lawful dispatch after rev-003 activation is `direction-023-final-compatibility-surface-report`. That report must carry forward the round 071 and round 072 blockers, record kept and deferred compatibility surfaces, state that no surfaces were removed after milestone 008 was held, and avoid implying cleanup removal, package publication, upload, release, deprecation, migration, Cabal exposure changes, production import rewrites, or compatibility behavior changes.

Rev-003 does not approve deprecation, migration, removal, package publication, upload, release, Cabal exposure changes, production import rewrites, schema or filename changes, event-type changes, write-timing changes, planner-turn changes, projection changes, healthcheck changes, repair changes, replay changes, restart-script changes, or operator behavior changes. Local absence remains unavailable or blocked evidence, not removal approval.

### State Activation
- Requires state.json roadmap metadata update: yes
- New roadmap_dir when applicable: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003`
