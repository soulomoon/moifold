# Final Compatibility Surface Report

Round: `round-073`
Roadmap: `2026-05-09-01-compatibility-surface-cleanup` `rev-003`
Milestone: `milestone-009-close-cleanup-family`
Direction: `direction-023-final-compatibility-surface-report`

## Scope And Non-Goals

This report closes the approved rev-003 hold path for the current
compatibility-surface cleanup family. It records kept compatibility surfaces,
the removed-surface set, deferred surfaces and blockers, validation evidence,
and the requirement that further cleanup use a later selected roadmap family
or exact approved removal round.

This report does not approve package publication, public release, upload,
deprecation, migration, removal, Cabal exposure changes, production import
rewrites, compatibility behavior changes, schema changes, filename changes,
event-type changes, write-timing changes, planner-turn changes, projection
changes, healthcheck changes, repair changes, replay changes, restart-script
changes, operator behavior changes, terminal cleanup completion, or
`direction-024-terminal-cleanup-gate`.

## Rev-003 Hold-Path Status

The active rev-003 roadmap records milestone 008 as held after round 072, not
removal-complete. Round 072 established that milestone 008 is
dependency-reached but blocked because no exact public import facade or
runtime compatibility surface currently satisfies every active removal gate
and exact reviewer approval requirement.

`direction-021-remove-approved-import-facades` remains held and not currently
lawful. No exact import facade has recorded every required policy,
milestone-005 follow-up evidence, milestone-007 external inventory,
unsupported-user, behavior/package-boundary, and exact reviewer-approval gate.

`direction-022-remove-approved-runtime-compatibility-surfaces` remains held
and not currently lawful. No exact runtime compatibility file or snapshot has
recorded every required old-log/golden, repair, healthcheck or
non-healthcheck, runtime-owner, fixture, operator, write-timing,
unsupported-user, and exact reviewer-approval gate.

The rev-003 hold path makes this final report lawful, but it does not convert
held removal work into completed removal work.

## Kept Compatibility Surfaces

The following public import facades remain kept compatibility surfaces:

| Surface | Current kept status |
| --- | --- |
| `CodexWatcher.Core.Ids` | Kept. Round 071 recorded 65 current importer files, mixed agent/GitHub ownership, tests compiling through the facade, public docs keeping the facade available, unavailable external downstream evidence, no unsupported-user decision, and blocked reviewer/operator approval. |
| `CodexWatcher.AppServerClient` | Kept. Round 071 recorded 28 current importer files, app-server request/session/failure behavior contracts, current public exposure, unavailable external downstream evidence, no unsupported-user decision, and blocked behavior/reviewer approval. |
| `CodexWatcher.Workflow.EventLog` | Kept. Round 071 recorded remaining facade users, concrete moifold helpers, event JSON `type` and schema contracts, old-log/golden replay obligations, public docs with deferred status, unavailable external downstream/operator evidence, and no unsupported-user decision. |
| `CodexWatcher.Workflow.Permission` | Kept. Round 071 recorded public exposure, concrete moifold bridge API, test facade import, public API/behavior parity obligations, unavailable external downstream/operator evidence, and no unsupported-user decision. |

The following runtime compatibility surfaces remain kept or deferred
compatibility surfaces whose current names, fields, write timing, reader
behavior, and operator expectations stay protected:

| Surface | Current kept status |
| --- | --- |
| `planning-state.json` | Kept/deferred. It has active compatibility writes and explicit non-healthcheck status, but no checked-in fixture, missing external direct-reader inventory, no unsupported-user decision, and no approval for healthcheck, write, schema, or removal changes. |
| `repair-state.json` | Kept/deferred. It is tied to protected repair execute ordering and compatibility rewrite ordering, has explicit non-healthcheck status, lacks a checked-in fixture and production-reader decision, and has missing external direct-reader evidence. |
| `runtime-owner.json` | Kept. It is live daemon ownership state used by the runtime owner store, CLI, automatic loop, healthcheck, PR-review launch reuse, and `scripts/restart-watcher`; it lacks checked-in fixture coverage and external operator script inventory. |
| `daemon-state.json` | Kept. It remains part of healthcheck, snapshot, repair rewrite, and restart cleanup behavior, with old-shape fixture tolerance, missing active/stopped fixture coverage, and missing external direct-reader evidence. |
| PR review compatibility state files: `watcher-state.json`, `checker-state.json`, `agent-state.json`, `reviewer-state.json` | Kept. Snapshot and healthcheck readers, golden fixtures, PR-review state-dir conventions, optional legacy `agent-state.json` readback, and external path expectation gaps remain active blockers. |
| PR URL/state paths: `issue-state.json` `pr_url`, event/prompt `prUrl`, absent dedicated `pr-url` or `pr-state` paths | Kept/deferred. `issue-state.json` and `prUrl` are observed compatibility surfaces, while dedicated path absence is local-only evidence and remains blocked on old live-state archive and external operator/downstream evidence. |
| `block-state.json` | Kept. Healthcheck, snapshot, restart, repair, compatibility projection, stale-block cleanup, and blocked-tail behavior remain protected; only normal blocked fixture coverage exists, with repair-failure fixture and external reader evidence still missing. |
| `issue-snapshot.json` | Kept/deferred. The planner prompt contract and tested write timing before planner turn remain protected; checked-in live fixture coverage and external direct-reader inventory are missing. |

## Removed Compatibility Surfaces

The removed-surface set is empty on the approved rev-003 hold path.

No surfaces were removed after milestone 008 was held. No compatibility
surfaces were removed after milestone 008 was held, and this report does not
claim that held milestone 008 is removal-complete.

## Deferred Compatibility Surfaces And Blockers

Round 071 blockers remain carried forward:

- External downstream repositories were unavailable.
- Live state archives were unavailable.
- External operator scripts were unavailable.
- Hosted CI, package upload, tag, GitHub release, and release announcement
  evidence were unavailable.
- Operator, reviewer, and release-gate approval evidence was blocked.
- No unsupported-user decisions were recorded for remaining import users,
  runtime compatibility-file readers, script consumers, runbook consumers, or
  downstream users.
- Every public import facade and runtime compatibility surface retained at
  least one per-surface blocker.

The deferred public import surfaces remain blocked as follows:

| Surface | Deferred blocker |
| --- | --- |
| `CodexWatcher.Core.Ids` | Current importers, mixed ownership, facade tests, public docs, unavailable external downstream evidence, and no unsupported-user decision. |
| `CodexWatcher.AppServerClient` | Current importers, app-server behavior contracts, public exposure, unavailable external downstream evidence, and no unsupported-user decision. |
| `CodexWatcher.Workflow.EventLog` | Current facade users, concrete moifold wrappers, event schema/golden replay contracts, unavailable external downstream/operator evidence, and no unsupported-user decision. |
| `CodexWatcher.Workflow.Permission` | Public exposure, concrete moifold bridge API, test facade import, unavailable external downstream evidence, and no unsupported-user decision. |

The deferred runtime surfaces remain blocked as follows:

| Surface | Deferred blocker |
| --- | --- |
| `planning-state.json` | Missing checked-in fixture, explicit non-healthcheck status, missing external direct-reader inventory, and no behavior-change approval. |
| `repair-state.json` | Missing checked-in fixture, no production-reader decision, protected repair ordering, explicit non-healthcheck status, and missing external direct-reader inventory. |
| `runtime-owner.json` | Live daemon ownership state, CLI/automatic-loop/healthcheck/restart consumers, missing fixture coverage, and missing external operator script inventory. |
| `daemon-state.json` | Current projection and healthcheck contract, old-shape tolerance, restart cleanup behavior, missing active/stopped fixtures, and missing external direct-reader evidence. |
| PR review state files | Current snapshot/healthcheck consumers, golden fixtures, operator state-dir convention, optional legacy `agent-state.json`, and missing external path expectations. |
| PR URL/state paths | Observed `issue-state.json` `pr_url` and `prUrl` fields, but dedicated `pr-url` or `pr-state` absence is local-only and blocked on old live-state/external evidence. |
| `block-state.json` | Healthcheck/snapshot/restart/repair consumers, normal blocked fixture only, missing repair-failure fixture, and missing external direct-reader inventory. |
| `issue-snapshot.json` | Agent prompt contract, tested write timing, missing checked-in live fixture, missing external direct-reader inventory, and no migration/removal approval. |

Local absence remains unavailable or blocked evidence, not removal approval.

## Validation Evidence And Skipped Baseline Rationale

This report was prepared from these required control and hold-path readbacks:

```sh
sed -n '1,260p' orchestrator/rounds/round-073/selection.md
sed -n '1,320p' orchestrator/rounds/round-073/plan.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,760p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/roadmap.md
sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/verification.md
sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/retry-subloop.md
sed -n '1,520p' orchestrator/rounds/round-071/external-operator-downstream-inventory.md
sed -n '1,320p' orchestrator/rounds/round-071/review.md
sed -n '1,320p' orchestrator/rounds/round-071/implementation-notes.md
sed -n '1,320p' orchestrator/rounds/round-072/no-lawful-removal-surface-status.md
sed -n '1,320p' orchestrator/rounds/round-072/review.md
sed -n '1,320p' orchestrator/rounds/round-072/implementation-notes.md
```

The final artifact-only verification for this round must confirm that changed
paths remain limited to round-local artifacts under `orchestrator/rounds/round-073/`.
Under that rev-003 artifact-only allowance, `cabal build all`,
`cabal test watcher-core-test`, and
`scripts/validate-workflow-packages.sh` may be skipped because this round does
not change production source, tests, scripts, fixtures, package descriptors,
roadmap files, `orchestrator/project-contract.md`, `orchestrator/state.json`,
or compatibility behavior. If any changed path escapes the round-local
artifact set, the relevant full baseline is required before review.

## New-Family Requirement For Further Cleanup

Further cleanup, removal, migration, deprecation, package publication, public
release, upload, Cabal exposure changes, production import rewrites, or
compatibility behavior changes require a later selected roadmap family or an
exact approved removal round that names the surface, lists every satisfied
gate, records unsupported-user decisions where needed, and receives reviewer
approval for the exact evidence.

This report does not select that new family and does not approve that future
work.

## Direction-024 Out Of Scope

`direction-024-terminal-cleanup-gate` is out of scope for this round. This
round does not choose, approve, or decide the terminal cleanup gate. It only
prepares the report artifact that a later terminal gate can read.

## Conservative Conclusion

The conservative closeout state is a hold. The compatibility surfaces remain
available and behaviorally unchanged. The removed-surface set is empty on the
approved rev-003 hold path, and no compatibility surfaces were removed after
milestone 008 was held.

Further cleanup is blocked by unavailable external evidence, blocked
operator/reviewer/release-gate approval evidence, missing unsupported-user
decisions, and per-surface blockers. Any future deprecation, migration,
removal, package publication, release, Cabal exposure change, production
import rewrite, or compatibility behavior change needs a new selected and
reviewed path.
