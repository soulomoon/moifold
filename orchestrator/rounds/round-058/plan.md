### Goal

Produce a round-local follow-up discovery artifact for
`round-058-follow-up-discovery` that identifies candidate cleanup or evidence
items revealed by rounds 052-057, current compatibility policy docs, TODO/test
references, and relevant source references. The result must be evidence-only:
candidate items, source evidence, blockers, and recommended milestone placement
for a later roadmap expansion decision.

### Approach

Keep the round sequential and artifact-only. The implementer should write one
discovery report at
`orchestrator/rounds/round-058/follow-up-discovery.md` and should not edit the
roadmap, project contract, policy docs, source, tests, Cabal descriptors,
fixtures, runtime compatibility files, import surfaces, or removal state.

The discovery report should treat the merged artifacts from rounds 052-057 as
the primary evidence base, then refresh only focused scans needed to confirm
whether the earlier blockers or reviewer notes still point to concrete
follow-up candidates. Each candidate must be labeled as a proposal for later
roadmap expansion, not as deprecation, migration, removal, package-publication,
or release approval.

### Steps

1. Re-read the controlling inputs:
   `orchestrator/rounds/round-058/selection.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/roadmap.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/verification.md`,
   `orchestrator/project-contract.md`, and
   `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
   Record in the discovery report that this is `milestone-004`,
   `direction-007-follow-up-discovery`, and that it is evidence-only.

2. Read the merged inventory, readiness, policy, and review artifacts from
   rounds 052-057:
   `round-052/import-facade-inventory.md`, `round-052/review.md`,
   `round-053/runtime-compatibility-file-inventory.md`, `round-053/review.md`,
   `round-054/import-replacement-readiness.md`, `round-054/review.md`,
   `round-055/runtime-file-behavior-gates.md`, `round-055/review.md`,
   `round-056/import-facade-cleanup-policy.md`, `round-056/review.md`,
   `round-057/runtime-compatibility-cleanup-policy.md`, and
   `round-057/review.md`. Extract only follow-up-relevant facts: missing
   evidence, `keep`/`defer` classifications, reviewer notes, source clusters,
   and verification constraints.

3. Refresh focused import-facade evidence without changing imports:
   rerun the exact selected-facade import scan used by rounds 054 and 056,
   rerun the standalone-package/examples regression scan, and rerun the Cabal
   exposure scan for selected facades and preferred replacements. Use the
   refreshed counts only to confirm candidate shape, such as high-volume
   `CodexWatcher.Core.Ids` split-import follow-up, high-volume
   `CodexWatcher.AppServerClient` migration-readiness follow-up, public API
   review for `CodexWatcher.Workflow.Permission`, or old-log/concrete-helper
   evidence for `CodexWatcher.Workflow.EventLog`.

4. Refresh focused runtime compatibility-file evidence without changing
   runtime behavior:
   run the selected filename `find`, focused runtime/healthcheck/repair/golden
   `rg` scans, and a targeted TODO/reference scan for
   `planning-state.json`, `repair-state.json`, `runtime-owner.json`,
   `issue-snapshot.json`, PR URL/state wording, `block-state.json`, and
   compatibility snapshots. Use this only to confirm candidate blockers such as
   missing fixtures, external operator inventory, healthcheck ownership gaps,
   repair-failure fixture evidence, active/stopped daemon fixtures, or runtime
   owner healthcheck field-path evidence.

5. Inspect current tests and source references only as needed to support or
   reject candidate items. Prefer focused reads around the cited tests/source
   from prior artifacts, including `test/Main.hs`,
   `test/HealthcheckSpec.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`,
   `src/CodexWatcher/Healthcheck.hs`,
   `src/CodexWatcher/Cli/Command/Replay.hs`,
   `src/CodexWatcher/Snapshot.hs`,
   `src/CodexWatcher/Runtime/Owner/{Store,Cli}.hs`,
   `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, and
   `scripts/restart-watcher`. Do not add, delete, or rewrite tests.

6. Write `orchestrator/rounds/round-058/follow-up-discovery.md` with these
   sections:
   `Scope And Non-Goals`, `Inputs Read`, `Scan Evidence`, `Candidate Cleanup
   Items`, `Rejected Or Deferred Non-Candidates`, `Blockers And Required
   Evidence`, `Recommended Milestone Placement`, and `Roadmap Expansion
   Handoff Notes`.
   For every candidate, include:
   exact surface name, evidence source path, current classification, blocker,
   recommended later milestone/direction type, and the reason it is not
   approval to deprecate/remove/migrate now.

7. Explicitly forbid and avoid all out-of-scope work in the artifact:
   no roadmap edits, no roadmap revision publication, no source/test/docs
   policy edits, no compatibility-file migration, no runtime/import surface
   changes, no Cabal changes, no deprecation pragma, no removal approval, no
   package publication or upload claim, and no claim that local validation
   satisfies a future release gate.

8. Before handing to review, read back the discovery report and grep for banned
   overclaims. The report should say candidates are for later roadmap expansion
   only, and should distinguish `keep`, `defer`, missing evidence, and
   `remove-later` accurately. No selected surface from rounds 056-057 should be
   upgraded to deprecation or removal readiness in this round.

### Verification

- Focused readback:
  `sed -n '1,260p' orchestrator/rounds/round-058/follow-up-discovery.md`.
- Banned-claim check:
  `rg -n 'approve|approval|approved|DEPRECATED|deprecated pragma|remove-later|removal approved|publish|upload|roadmap revision|Cabal|exposed-modules' orchestrator/rounds/round-058/follow-up-discovery.md`.
  Any matches must be negative/non-goal wording or future-gate wording only.
- Boundary diff check:
  `git diff --name-status --` should show only round-local artifacts for this
  round, with no source, test, docs policy, Cabal, roadmap, fixture, runtime,
  or project-contract changes.
- Whitespace checks:
  `git diff --check`; if files are staged by a later role, also run
  `git diff --cached --check`.
- Baseline validation:
  because this is artifact-only discovery, full `cabal build all`,
  `cabal test watcher-core-test`, and
  `scripts/validate-workflow-packages.sh` are not required by this plan before
  review. However, the reviewer must decide against the roadmap verification
  contract whether to run the full baseline anyway; this plan does not weaken
  the baseline contract for any later source, docs policy, Cabal, runtime, or
  removal work.

### Worker Fan-Out

Worker fan-out is not used. The round is serial, evidence-only, and produces a
single integrated discovery artifact whose candidate ordering and roadmap
placement recommendations should be reviewed as one coherent handoff.
