### Checks Run
- Command: `sed -n '1,240p' orchestrator/rounds/round-059/selection.md`
  Result: pass. Selection identifies the serial roadmap expansion update for
  `milestone-004-expand-follow-up-backlog` and keeps production, tests, Cabal,
  docs policy, fixtures, scripts, runtime compatibility files, import
  surfaces, package publication, release gates, and removal work out of scope.

- Command: `sed -n '1,260p' orchestrator/rounds/round-059/plan.md`
  Result: pass. The plan requires an artifact-only immutable `rev-002`
  roadmap revision, no `worker-plan.json`, follow-up evidence milestones
  before removals, conservative removal boundaries, and artifact inspection in
  place of Cabal/package baselines unless the diff escapes the allowed scope.

- Command: `sed -n '1,260p' orchestrator/rounds/round-059/implementation-notes.md`
  Result: pass. Notes report `rev-002` creation, milestones 001-004 completed,
  follow-up evidence milestones added before gated removals, and no forbidden
  production, policy, runtime, import, project-contract, state, or rev-001
  edits.

- Command: `sed -n '1,620p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`
  Result: pass. The roadmap keeps id
  `2026-05-09-01-compatibility-surface-cleanup`, sets revision `rev-002`, keeps
  style `strategy-backlog`, records activation metadata for `rev-002`, marks
  milestones 001-004 complete, adds evidence milestones 005-007, keeps gated
  removals at milestone 008, and closeout at milestone 009.

- Command: `sed -n '1,280p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`
  Result: pass. Verification carries forward baseline commands, explicitly
  allows Cabal/package baseline skips for artifact-only roadmap updates, and
  adds `rev-002` artifact, forbidden-diff, sequencing, and overclaim checks.

- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md`
  Result: pass. Retry contract points at the `rev-002` active roadmap path,
  keeps same-round retry for missing evidence or overclaimed readiness, keeps
  worker-slice retry disabled by default, and preserves immutable revision
  rules.

- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. The project contract still requires source-backed inventory,
  readiness evidence, policy before removal, and additional runtime gates for
  compatibility-file removal.

- Command: `sed -n '1,260p' orchestrator/rounds/round-058/follow-up-discovery.md`
  Result: pass. Prior discovery justifies the `rev-002` expansion with
  import-facade, runtime compatibility, and external operator/downstream
  follow-up candidates while explicitly avoiding migration, deprecation,
  removal, publication, upload, and release approval.

- Command: `sed -n '1,240p' orchestrator/rounds/round-058/review.md`
  Result: pass. The prior review approved round 058 as evidence-only discovery
  and confirmed the candidate list as conservative handoff material for later
  roadmap expansion.

- Command: `sed -n '1,200p' orchestrator/rounds/round-058/review-record.json`
  Result: pass. Prior review record approved `direction-007-follow-up-discovery`
  under `rev-001`, providing lineage for this expansion update.

- Command: `git diff --check`
  Result: pass. No tracked-diff whitespace errors.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors; no staged changes were present.

- Command: `git diff --name-only && git diff --cached --name-only && git status --short`
  Result: pass. There are no tracked or staged diffs. Status shows only
  untracked `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/`
  and `orchestrator/rounds/round-059/` artifacts before this review was
  written.

- Command: `test -f orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md && test -f orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md && test -f orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md && test -f orchestrator/rounds/round-059/selection.md && test -f orchestrator/rounds/round-059/plan.md && test -f orchestrator/rounds/round-059/implementation-notes.md && test ! -e orchestrator/rounds/round-059/worker-plan.json`
  Result: pass. All expected `rev-002` and round-059 artifacts exist and no
  `worker-plan.json` exists.

- Command: `find orchestrator/rounds/round-059 orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002 -type f | sort`
  Result: pass. Before review artifacts, the new artifact set contained only
  `rev-002/roadmap.md`, `rev-002/verification.md`,
  `rev-002/retry-subloop.md`, `round-059/selection.md`,
  `round-059/plan.md`, and `round-059/implementation-notes.md`.

- Command: `rg -n 'Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`|Roadmap revision: `rev-002`|Roadmap style: `strategy-backlog`|`roadmap_revision`: `rev-002`|orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`
  Result: pass. Readback found the roadmap id, `rev-002` revision,
  `strategy-backlog` style, `roadmap_revision`: `rev-002`, and the activation
  `rev-002` roadmap directory.

- Command: `rg -n '^### [1-9]\. \[(complete|pending)\]|explicit reviewer approval|no cleanup approval|does not approve|not approve|no deprecation|no migration|no exposed-module removal|not removal' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`
  Result: pass. Milestones 001-004 are complete; milestones 005-007 are
  follow-up evidence and inventory gates; milestone 008 is the first gated
  removal milestone and requires explicit reviewer approval; milestone 009 is
  closeout.

- Command: `git ls-files orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/roadmap.md orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/verification.md orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/retry-subloop.md orchestrator/project-contract.md orchestrator/state.json orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/roadmap-history.md`
  Result: pass. The protected tracked files exist in the index, and the empty
  tracked diff confirms they were not changed by this artifact-only round.

- Command: `for f in $(find orchestrator/rounds/round-059 orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002 -type f | sort); do git diff --no-index --check /dev/null "$f" >/tmp/round059-noindex.out 2>&1; rc=$?; if [ -s /tmp/round059-noindex.out ]; then printf '%s\n' "$f"; cat /tmp/round059-noindex.out; exit $rc; fi; done`
  Result: pass. No no-index whitespace errors were emitted for the new
  untracked artifacts.

- Command: `cabal build all`
  Result: not run. Reviewer judgment: the integrated result is artifact-only
  roadmap revision work with no tracked production source, tests, Cabal
  descriptors, docs policy, fixtures, scripts, runtime compatibility files,
  import surfaces, package metadata, `project-contract.md`, `state.json`, or
  `rev-001` edits. The active `rev-002` verification contract permits skipping
  this baseline for this scope.

- Command: `cabal test watcher-core-test`
  Result: not run. Same artifact-only rationale as above; the round changes
  coordination artifacts and does not alter behavior protected by the test
  suite.

- Command: `scripts/validate-workflow-packages.sh`
  Result: not run. Same artifact-only rationale as above; no package
  descriptors, public modules, source distributions, or package sources
  changed.

### Plan Compliance
- Re-read controlling inputs: met. Selection, plan, implementation notes,
  `rev-002` roadmap bundle, round 058 discovery/review artifacts, project
  contract, and reviewer role guidance were inspected.
- Keep work sequential and single-owner: met. No `worker-plan.json` exists.
- Create immutable `rev-002` revision: met. The new revision directory contains
  `roadmap.md`, `verification.md`, and `retry-subloop.md`; `rev-001` remains
  intact with no tracked diff.
- Preserve roadmap identity and activation metadata: met. `rev-002/roadmap.md`
  keeps roadmap id `2026-05-09-01-compatibility-surface-cleanup`, sets
  roadmap revision `rev-002`, keeps `strategy-backlog`, and records activation
  metadata for `roadmap_revision`: `rev-002` and the `rev-002` roadmap dir.
- Carry forward completed milestones 001-004: met. The roadmap marks
  milestones 001-004 complete with compact progress pointers through rounds
  052-059.
- Insert follow-up evidence before removals: met. Import-facade evidence,
  runtime compatibility evidence, and external operator/downstream inventory
  are milestones 005-007; gated removals are milestone 008 and closeout is
  milestone 009.
- Preserve removal/deprecation/publication boundaries: met. The roadmap says
  round 058 candidates are evidence gaps, not removal approvals; no listed
  surface is approved for current migration, deprecation, removal, package
  publication, upload, or release merely by appearing in `rev-002`.
- Keep forbidden files unchanged: met. No tracked diff exists, and status
  before review artifacts showed only the new allowed roadmap and round-local
  artifact directories.
- Update verification and retry contracts: met. `verification.md` includes
  `rev-002` artifact and forbidden-diff checks plus artifact-only baseline
  judgment; `retry-subloop.md` points at `rev-002` and preserves the immutable
  revision rule.

### Decision
**APPROVED**

### Evidence
The integrated round result is a conservative artifact-only roadmap expansion.
It publishes `rev-002` with the same roadmap id, `strategy-backlog` style, and
activation metadata for the new revision path, while preserving the used
`rev-001` revision.

Milestones 001-004 remain complete, and the new ordering is evidence-first:
import-facade evidence, runtime compatibility evidence, and external
operator/downstream inventory all precede the gated-removal milestone.
Removal work remains dependent on exact selected surfaces, satisfied gates,
old-log/golden/repair/healthcheck/import evidence where relevant, and explicit
reviewer approval.

No tracked source, test, Cabal, docs policy, fixture, script, runtime
compatibility, import-surface, project-contract, state, roadmap-history, or
rev-001 file changed. Whitespace checks passed for tracked/staged diffs and
for the new untracked artifacts.
