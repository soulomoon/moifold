# No Lawful Removal Surface Status

Round: `round-072`
Roadmap: `2026-05-09-01-compatibility-surface-cleanup` `rev-002`
Milestone: `milestone-008-gated-compatibility-removals`
Direction: `none-selected-no-lawful-removal-surface`

## Scope And Non-Goals

This artifact records that milestone 008 is dependency-reached after
milestone 007, but currently blocked and held for removal. No exact public
import facade or runtime compatibility surface has satisfied every active gate
and received reviewer approval.

This status artifact does not approve or perform deprecation, migration,
removal, package publication, upload, release, Cabal exposure changes,
production import rewrites, schema changes, filename changes, event-type
changes, write-timing changes, planner-turn changes, projection changes,
healthcheck changes, repair changes, replay changes, restart-script changes,
or operator behavior changes.

Local absence is not removal approval. Missing local users, missing checked-in
fixtures, or missing external files remain evidence gaps unless a reviewed
approval record explicitly classifies the affected user or surface as
unsupported or removable.

## Active Roadmap Gate Summary For Milestone 008

The active rev-002 roadmap says compatibility cleanup is evidence-first:
inventory before policy, policy before removal, and rev-002 follow-up evidence
before removal. It also states that gated removals are allowed only after
milestones 005 through 007 complete and only when a selected direction names
exact surfaces, lists satisfied gates, and a reviewer approves the exact
removal evidence.

The rev-002 verification contract requires removal rounds to name the exact
surfaces removed, list every satisfied gate, and receive reviewer approval
before merge. It also requires public import-facade removal to have recursive
import scans, replacement paths, Cabal exposed-module analysis when relevant,
public/downstream-user review, and package-boundary test evidence. Runtime
compatibility-file removal must preserve or explicitly prove old-log, golden
replay, repair, healthcheck or non-healthcheck policy, fixture behavior,
operator recovery, and write timing for the selected surface.

The rev-002 retry-subloop contract says removal is not a retry fallback. If
approval is missing, the round records a hold or deferral; it must not remove
the surface.

## Round 071 Blocker Summary

Round 071 completed the external operator and downstream inventory as
milestone-007 evidence only. Its inventory recorded observed repo-local
evidence for public imports, state-file paths, shell/operator consumers,
runbooks, and local package/downstream references.

Round 071 also preserved blockers:

- external downstream repositories were unavailable;
- live state archives were unavailable;
- external operator scripts were unavailable;
- hosted CI, uploads, tags, releases, and release announcements were
  unavailable;
- operator, reviewer, and release-gate approval evidence was blocked;
- no unsupported-user decisions were recorded;
- every inventoried surface retained at least one per-surface blocker.

Round 071 explicitly did not approve deprecation, migration, removal, package
publication, upload, release, Cabal exposure changes, production import
rewrites, schema or filename changes, event-type changes, write-timing
changes, planner-turn changes, projection changes, healthcheck changes, repair
changes, replay changes, restart-script changes, or operator behavior
changes.

## Direction 021 Classification

`direction-021-remove-approved-import-facades` is not currently lawful for
removal.

No exact import facade has a record showing all of these gates satisfied:

- policy gate;
- follow-up evidence gate from milestone 005;
- external inventory gate from milestone 007;
- no unsupported remaining users or an explicit unsupported-user decision;
- behavior and package-boundary test evidence;
- reviewer approval for the exact removal evidence.

Round 071 keeps the current blockers live for
`CodexWatcher.Core.Ids`, `CodexWatcher.AppServerClient`,
`CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.
Those blockers include current repo-local importers or public exposure,
behavior contracts, tests through compatibility facades, unavailable external
downstream evidence, blocked approval evidence, and no recorded
unsupported-user decisions.

Therefore this round must not deprecate, migrate, narrow, remove, hide from
Cabal exposed modules, rewrite production imports away from, publish around,
upload around, or release around any public import facade.

## Direction 022 Classification

`direction-022-remove-approved-runtime-compatibility-surfaces` is not currently
lawful for removal.

No exact runtime compatibility file or snapshot has a record showing all of
these gates satisfied:

- policy gate;
- follow-up evidence gate from milestone 006;
- external inventory gate from milestone 007;
- old-log or golden replay evidence where applicable;
- repair evidence where applicable;
- healthcheck or explicit non-healthcheck evidence;
- runtime-owner or daemon ownership evidence where applicable;
- checked-in fixture or approved fixture-gap evidence;
- operator script/runbook evidence;
- write-timing evidence where applicable;
- no unsupported remaining users or an explicit unsupported-user decision;
- reviewer approval for the exact removal evidence.

Round 071 keeps the current blockers live for `planning-state.json`,
`repair-state.json`, `runtime-owner.json`, `daemon-state.json`, PR review
state files, PR URL/state paths, `block-state.json`, and
`issue-snapshot.json`. Those blockers include missing fixtures, live daemon
ownership state, healthcheck/snapshot/restart/repair consumers, operator
script/runbook expectations, write-timing or planner-turn contracts,
unavailable live archives, unavailable external operator evidence, blocked
approval evidence, and no recorded unsupported-user decisions.

Therefore this round must not remove, migrate, rename, rewrite, stop writing,
stop reading, change schema for, change event type for, change write timing
for, change planner-turn behavior for, change projection behavior for, change
healthcheck behavior for, change repair behavior for, change replay behavior
for, change restart-script behavior for, or change operator behavior for any
runtime compatibility surface.

## Milestone 009 Sequencing Note

Milestone 009 depends on milestone 008. This artifact records that milestone
008 is blocked and held for removal; it does not mark milestone 008 complete.

Because no milestone-008 removal direction has an exact approved surface, this
round does not select milestone 009, does not select the final compatibility
surface report, does not select the terminal cleanup gate, and does not imply
terminal family completion.

The next controller action should route this no-lawful-removal status through
review or roadmap-update handling. It should not infer approval for any
removal from dependency reachability, local absence, or the existence of this
hold artifact.

## Conservative Conclusion

Milestone 008 is dependency-reached but blocked. The lawful state is a hold:
no exact import facade or runtime compatibility surface currently has all
required gates and exact reviewer approval satisfied.

The compatibility surfaces remain available and behaviorally unchanged until a
later selected round names an exact surface, records every satisfied gate,
records any unsupported-user decision required for remaining users, and obtains
reviewer approval for that exact removal evidence.
