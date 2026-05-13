### Source Round
- Round id: `round-177`
- Merged commit: `177fa76528d4eddd2fb202821a087a4dbc649de9`
- Evidence: reviewer approved the import-only migration of
  `src/CodexWatcher/EventLog/Replay.hs`; `cabal build all`,
  `cabal test watcher-core-test --test-options='--match "workflow event-log"'`,
  full `cabal test watcher-core-test`, `git diff --check`, selected-file scans,
  direct-owner scans, and the broad remaining-user scan passed; cached diff
  check was skipped because no staged changes existed.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-002`
- Files changed:
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/roadmap.md`;
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/verification.md`;
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/retry-subloop.md`;
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/roadmap-history.md`;
  `orchestrator/roadmap-updates/round-177-roadmap-update.md`

### Rationale
Round 177 landed another real production `Core.Ids` direct-owner import
migration, but the existing rev-001 milestone 003 still mixed production
imports, test imports, EventLog/Permission bridge work, AppServerClient public
surface cleanup, package-boundary checks, Cabal/docs cleanup, and removal gates.
That made the milestone too broad to close even after many concrete migration
rounds.

Rev-002 keeps the same roadmap id and splits the overloaded milestone into
finite queues:
production `Core.Ids` burndown, test/fixture `Core.Ids` burndown,
EventLog/Permission bridge burndown, and AppServerClient public-surface
cleanup. Existing large-module decomposition, runtime compatibility cleanup,
and final deprecation/removal work are preserved and renumbered after those
queues. The new structure keeps concrete migration work moving while ensuring
that public facade removal, Cabal exposure cleanup, runtime compatibility
cleanup, release approval, terminal completion, and final removal remain
unapproved until exact future gates name the surface.

### State Activation
- Requires state.json roadmap metadata update: yes
- New roadmap_dir when applicable:
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`
