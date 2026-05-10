# Terminal Cleanup Gate

Round: `round-074`
Roadmap: `2026-05-09-01-compatibility-surface-cleanup` `rev-003`
Milestone: `milestone-009-close-cleanup-family`
Direction: `direction-024-terminal-cleanup-gate`

## Scope And Non-Goals

This terminal gate records the closeout decision for the current rev-003
compatibility-surface cleanup hold path. It reads the approved round 073 final
compatibility surface report, its review and merge evidence, the rev-003
roadmap bundle, and the project contract, then decides whether the current
family can close as a reviewed hold or must remain blocked.

This gate does not approve package publication, public release, release
approval, upload, deprecation, migration, removal, Cabal exposure changes,
production import rewrites, compatibility behavior changes, schema changes,
filename changes, event-type changes, write-timing changes, planner-turn
changes, projection changes, healthcheck changes, repair changes, replay
changes, restart-script changes, operator behavior changes, or any
direction-024 action beyond this reviewed terminal hold decision.

## Required Evidence Readback

The selected lineage remains:

- Milestone: `milestone-009-close-cleanup-family`
- Direction: `direction-024-terminal-cleanup-gate`
- Extracted item: `round-074-terminal-cleanup-gate`
- Roadmap revision: `rev-003`

The rev-003 roadmap records that milestones 001 through 007 are complete,
`milestone-008-gated-compatibility-removals` is held after round 072, and
`milestone-009-close-cleanup-family` remains pending until this terminal gate
is selected, reviewed, and accepted. The roadmap also records round 073 as the
completed `direction-023-final-compatibility-surface-report` via commit
`37cde0a`.

Round 073's approved final report, review, review record, merge notes, roadmap
update, and roadmap-update review all preserve the current hold path:
`direction-023` is complete, `direction-024` is the only current terminal gate
scope, the removed-surface set is empty, no surfaces were removed, and all
kept and deferred public import facades and runtime compatibility surfaces
remain available and behaviorally unchanged.

## Terminal Gate Decision

The current rev-003 hold path closes as a reviewed terminal hold.

This is a closeout hold, not removal completion. It marks the current roadmap
family terminal only for the reviewed hold path whose blockers are recorded
below. It does not approve package publication, public release, release
approval, upload, deprecation, migration, removal, Cabal exposure changes,
production import rewrites, compatibility behavior changes, or any public or
runtime compatibility surface cleanup beyond recording this hold decision.

No missing final-report evidence, forbidden changed path, new unrepresented
cleanup item, or approval record was observed that would convert this terminal
gate into removal work. No evidence was observed that would make
`direction-021` or `direction-022` currently lawful.

## Preserved Hold State

`milestone-008-gated-compatibility-removals` remains held and not
removal-complete. Round 072 made milestone 008 dependency-reached after
milestone 007, but blocked because no exact public import facade or runtime
compatibility surface currently satisfies every removal gate and exact
reviewer approval requirement. That hold is only a lawful predecessor for
this final hold path.

`direction-021-remove-approved-import-facades` remains held and not currently
lawful. No exact import facade has recorded every required policy,
milestone-005 follow-up evidence, milestone-007 external inventory,
unsupported-user, behavior/package-boundary, and exact reviewer-approval gate.
No import facade is marked complete by removal.

`direction-022-remove-approved-runtime-compatibility-surfaces` remains held
and not currently lawful. No exact runtime compatibility file or snapshot has
recorded every required old-log/golden, repair, healthcheck or
non-healthcheck, runtime-owner, fixture, operator, write-timing,
unsupported-user, and exact reviewer-approval gate. No runtime compatibility
surface is marked complete by removal.

`direction-023-final-compatibility-surface-report` is complete via round 073
and commit `37cde0a`. Its removed-surface set is empty, no surfaces were
removed, and all kept or deferred compatibility surfaces remain available and
behaviorally unchanged.

## Remaining Blockers After Closeout

Round 073's carried-forward blockers remain blockers after this closeout:

- External downstream repositories are unavailable.
- Live state archives are unavailable.
- External operator scripts are unavailable.
- Hosted CI, package upload, tag, GitHub release, and release announcement
  evidence are unavailable.
- Operator, reviewer, and release-gate approval evidence is blocked.
- No unsupported-user decisions are recorded for remaining import users,
  runtime compatibility-file readers, script consumers, runbook consumers, or
  downstream users.
- Every kept or deferred public import facade and runtime compatibility
  surface retains at least one per-surface blocker.

The kept or deferred public import facades remain blocked as follows:

| Surface | Blockers carried forward |
| --- | --- |
| `CodexWatcher.Core.Ids` | Current importer files, mixed agent/GitHub ownership, facade tests, public docs, unavailable external downstream evidence, no unsupported-user decision, and no exact reviewer approval. |
| `CodexWatcher.AppServerClient` | Current importer files, app-server request/session/failure behavior contracts, public exposure, unavailable external downstream evidence, no unsupported-user decision, and no exact reviewer approval. |
| `CodexWatcher.Workflow.EventLog` | Current facade users, concrete moifold helpers, event JSON `type` and schema contracts, old-log/golden replay obligations, unavailable external downstream/operator evidence, no unsupported-user decision, and no exact reviewer approval. |
| `CodexWatcher.Workflow.Permission` | Public exposure, concrete moifold bridge API, test facade import, public API and behavior parity obligations, unavailable external downstream/operator evidence, no unsupported-user decision, and no exact reviewer approval. |

The kept or deferred runtime compatibility surfaces remain blocked as follows:

| Surface | Blockers carried forward |
| --- | --- |
| `planning-state.json` | Active compatibility writes, explicit non-healthcheck status, missing checked-in fixture, missing external direct-reader inventory, no unsupported-user decision, and no behavior-change or removal approval. |
| `repair-state.json` | Protected repair execute ordering, compatibility rewrite ordering, explicit non-healthcheck status, missing checked-in fixture, no production-reader decision, missing external direct-reader evidence, and no behavior-change or removal approval. |
| `runtime-owner.json` | Live daemon ownership state, runtime owner store/CLI/automatic-loop/healthcheck/PR-review launch reuse/restart-script consumers, missing fixture coverage, missing external operator script inventory, and no behavior-change or removal approval. |
| `daemon-state.json` | Current projection and healthcheck contract, snapshot/repair/restart cleanup behavior, old-shape fixture tolerance, missing active/stopped fixture coverage, missing external direct-reader evidence, and no behavior-change or removal approval. |
| PR review compatibility state files: `watcher-state.json`, `checker-state.json`, `agent-state.json`, `reviewer-state.json` | Current snapshot and healthcheck consumers, golden fixtures, PR-review state-dir conventions, optional legacy `agent-state.json` readback, missing external path expectations, and no behavior-change or removal approval. |
| PR URL/state paths: `issue-state.json` `pr_url`, event/prompt `prUrl`, absent dedicated `pr-url` or `pr-state` paths | Observed `issue-state.json` and `prUrl` compatibility surfaces, local-only evidence for absent dedicated paths, missing old live-state archive evidence, missing external operator/downstream evidence, and no behavior-change or removal approval. |
| `block-state.json` | Healthcheck, snapshot, restart, repair, compatibility projection, stale-block cleanup, and blocked-tail behavior remain protected; repair-failure fixture and external direct-reader evidence are missing, and no behavior-change or removal approval exists. |
| `issue-snapshot.json` | Planner prompt contract and tested write timing before planner turn remain protected; checked-in live fixture coverage and external direct-reader inventory are missing, and no migration, timing, behavior-change, or removal approval exists. |

Local absence remains unavailable or blocked evidence, not removal approval.

## Validation Evidence And Skipped Baseline Rationale

This gate was prepared from the required control and evidence readbacks named
in the round 074 plan:

```sh
git status --short --branch --untracked-files=all
sed -n '1,260p' orchestrator/rounds/round-074/selection.md
sed -n '1,320p' orchestrator/rounds/round-074/plan.md
test ! -e orchestrator/rounds/round-074/worker-plan.json
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,760p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/roadmap.md
sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/verification.md
sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/retry-subloop.md
sed -n '1,260p' orchestrator/rounds/round-073/final-compatibility-surface-report.md
sed -n '1,260p' orchestrator/rounds/round-073/review.md
jq . orchestrator/rounds/round-073/review-record.json
sed -n '1,260p' orchestrator/rounds/round-073/merge.md
sed -n '1,260p' orchestrator/roadmap-updates/round-073-roadmap-update.md
sed -n '1,320p' orchestrator/roadmap-updates/round-073-roadmap-update-review.md
```

The focused artifact checks after writing this gate must confirm both
round-074 artifacts exist, required terminal hold and non-approval content is
present, `worker-plan.json` is absent, changed paths are limited to
round-local orchestrator artifacts under `orchestrator/rounds/round-074/`,
and diff/whitespace checks pass.

If changed paths remain limited to round-local artifacts under
`orchestrator/rounds/round-074/`, `cabal build all`,
`cabal test watcher-core-test`, and
`scripts/validate-workflow-packages.sh` are skipped under the rev-003
artifact-only allowance because no production source, tests, fixtures,
scripts, package descriptors, roadmap files, `orchestrator/project-contract.md`,
`orchestrator/state.json`, runtime compatibility files, import surfaces, or
compatibility behavior changed.

## Further-Cleanup Requirement

Further cleanup, removal, migration, deprecation, package publication, public
release, release approval, upload, Cabal exposure changes, production import
rewrites, or compatibility behavior changes require a later selected roadmap
family or an exact approved removal round.

That later selected roadmap family or exact approved removal round must name
the surface, list every satisfied gate, record unsupported-user decisions
where needed, and receive reviewer approval for the exact evidence.

This terminal gate does not select that future work and does not approve it.

## Conservative Conclusion

The conservative closeout decision is a reviewed terminal hold. The current
compatibility-surface cleanup family can close only as that hold: milestone
008 remains held and not removal-complete, directions 021 and 022 remain
held/not currently lawful, direction 023 is complete via round 073 and
`37cde0a`, the removed-surface set is empty, no surfaces were removed, and all
kept or deferred compatibility surfaces remain available and behaviorally
unchanged.

All blockers recorded above survive the closeout. Further cleanup requires a
new selected and reviewed path.
