### Goal
Publish the roadmap expansion decision from round 058 and, because the
discovery found concrete follow-up evidence gaps, create a new active roadmap
revision at
`orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/`.

This round is an artifact-only roadmap update. It must not edit production
source, tests, Cabal descriptors, docs policy, fixtures, scripts, runtime
compatibility files, import surfaces, compatibility schemas, event JSON
`type` fields, healthcheck behavior, repair behavior, publication metadata, or
release gates.

### Approach
Keep the work sequential and single-owner. The selected item is the serial
roadmap expansion decision for future coordination, so do not write
`worker-plan.json`.

Round 058 justifies expansion. It found source-backed follow-up candidates for
high-volume import facades, concrete event-log and permission boundaries,
missing runtime compatibility fixtures, runtime-owner, daemon-state, PR
state/path, block-state, live issue-snapshot evidence, and external
operator/downstream inventory. These are not removal approvals; they are
additional evidence gates that must be represented before terminal cleanup.

Create `rev-002` as a new immutable active revision by carrying forward the
`rev-001` contracts and adding compact follow-up milestones before gated
removals. Leave `rev-001` intact as used history. If any completed detail must
move out of the active roadmap for readability, record that preserved history
in `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/roadmap-history.md`
instead of rewriting away the evidence. The expected post-merge activation
metadata is:

- `roadmap_id`: `2026-05-09-01-compatibility-surface-cleanup`
- `roadmap_revision`: `rev-002`
- `roadmap_dir`:
  `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Steps
1. Re-read the controlling inputs before editing artifacts:
   `orchestrator/rounds/round-059/selection.md`,
   `rev-001/roadmap.md`, `rev-001/verification.md`,
   `rev-001/retry-subloop.md`, `roadmap-history.md`,
   `orchestrator/project-contract.md`,
   `orchestrator/rounds/round-058/follow-up-discovery.md`,
   `orchestrator/rounds/round-058/review.md`, and
   `orchestrator/rounds/round-058/review-record.json`.
2. Create
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`
   from `rev-001/roadmap.md`.
   - Keep the roadmap id exactly
     `2026-05-09-01-compatibility-surface-cleanup`.
   - Set roadmap revision to `rev-002`.
   - Preserve the same strategy-backlog style and evidence-first thesis.
   - Carry forward completed milestones 001-004 with compact progress
     pointers to rounds 052-059.
   - Mark `direction-008-roadmap-expansion-update` complete via this round
     and state that expansion is justified by round 058, without approving any
     deprecation, migration, removal, package publication, upload, or release.
3. In `rev-002/roadmap.md`, insert follow-up evidence milestones before the
   gated-removal milestone. Suggested structure:
   - Complete milestones 001-004 with progress pointers only.
   - New import-facade evidence milestone covering:
     `CodexWatcher.Core.Ids` split-import ownership evidence,
     `CodexWatcher.AppServerClient` migration-readiness grouping,
     `CodexWatcher.Workflow.EventLog` concrete-helper boundary evidence, and
     `CodexWatcher.Workflow.Permission` public API/downstream review.
   - New runtime compatibility evidence milestone covering:
     `planning-state.json`, `repair-state.json`, `runtime-owner.json`,
     active/stopped `daemon-state.json`, PR URL/state external paths,
     repair-failure `block-state.json`, and live `issue-snapshot.json`.
   - One cross-cutting external operator/downstream inventory direction
     before final selected removal work.
   - Gated compatibility removals only after those evidence milestones and the
     external inventory are complete.
   - Closeout after removals or an explicit hold decision.
4. Keep removal/deprecation boundaries conservative:
   - no selected surface from rounds 056-058 becomes `remove-later` merely
     because it appears in `rev-002`;
   - milestone 005/removal work must not be marked ready unless the new
     evidence gates and dependency ordering are represented clearly;
   - final removal directions must still name exact surfaces, satisfied gates,
     reviewer approval, and required old-log/golden/repair/healthcheck/import
     evidence as applicable.
5. Create
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`
   by carrying forward the `rev-001` verification contract and adding
   `rev-002` checks:
   - artifact checks for the three new revision files;
   - grep/readback checks for roadmap id, revision, and activation metadata;
   - readback that milestones 001-004 remain complete and later removals are
     dependency-gated after the new evidence milestones;
   - checks that no production/source/test/Cabal/docs policy/runtime/script
     files changed in this artifact-only round;
   - `git diff --check`;
   - `git diff --cached --check` if staging occurs;
   - reviewer baseline judgment that build/test/package validation is not
     required for artifact-only roadmap files unless the diff escapes the
     allowed artifact set.
6. Create
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md`
   by carrying forward `rev-001/retry-subloop.md`.
   - Update the active roadmap revision path to `rev-002`.
   - Keep same-round retry for missing evidence, overclaimed readiness, and
     accidental removal approval.
   - Keep worker-slice retry disabled by default.
   - Preserve the immutable revision rule: future coordination or activation
     changes require a new revision rather than rewriting used `rev-002`.
7. Update
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/roadmap-history.md`
   only if the implementation needs to record `rev-002` activation or move
   completed detail out of the active revision. If `rev-001` remains intact
   and `rev-002` carries enough progress history, this file may be left
   unchanged.
8. Record implementation evidence in
   `orchestrator/rounds/round-059/implementation-notes.md` if the implementer
   normally writes round-local implementation notes. This planner authorizes
   only artifact files needed for the roadmap update, not production or policy
   changes.

### Verification
Because this round plans an artifact-only roadmap revision, verification is
artifact inspection rather than production behavior testing:

- Confirm `orchestrator/rounds/round-059/plan.md` exists and no
  `orchestrator/rounds/round-059/worker-plan.json` exists.
- Confirm `rev-002/roadmap.md`, `rev-002/verification.md`, and
  `rev-002/retry-subloop.md` exist.
- Confirm `rev-002/roadmap.md` keeps roadmap id
  `2026-05-09-01-compatibility-surface-cleanup`, sets revision `rev-002`, and
  records post-merge activation metadata for `roadmap_revision=rev-002` and
  the `rev-002` roadmap directory.
- Confirm milestones 001-004 are complete with progress pointers and the new
  follow-up evidence milestones are ordered before gated removals and closeout.
- Confirm removal/deprecation/publication boundaries are preserved: no
  surface is approved for removal or migration by the revision itself, and
  milestone 005 remains gated behind follow-up evidence and reviewer approval.
- Confirm used `rev-001` history is preserved: either `rev-001` remains intact
  or any moved completed detail is represented in `roadmap-history.md`.
- Confirm no production source, tests, Cabal descriptors, docs policy files,
  fixtures, scripts, runtime compatibility files, `orchestrator/state.json`, or
  controller/review/merge artifacts were edited by this round.
- Run `git diff --check`.
- If files are staged later, run `git diff --cached --check`.

Do not run `cabal build all`, `cabal test watcher-core-test`, or
`scripts/validate-workflow-packages.sh` as required evidence unless the diff
escapes the artifact-only roadmap scope. A reviewer may still request them as
extra baseline confidence.

### Worker Fan-Out
Worker fan-out is not used. The update is a single roadmap revision decision
with shared sequencing and activation metadata, and splitting it would add
coordination risk without disjoint implementation ownership.
