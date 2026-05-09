# Implementation Notes

Round: `round-058`
Extracted item: `round-058-follow-up-discovery`

## Files Changed

- `orchestrator/rounds/round-058/follow-up-discovery.md`: added the
  evidence-only follow-up discovery report, candidate cleanup/evidence items,
  blockers, recommended milestone placement, and handoff notes.
- `orchestrator/rounds/round-058/implementation-notes.md`: added this
  implementation summary.

No roadmap, source, test, policy doc, project-contract, Cabal descriptor,
script, fixture, runtime compatibility file, import surface, deprecation state,
migration state, publication state, or removal state was edited.

## Inputs And Scans

Read controlling inputs:

- `orchestrator/rounds/round-058/selection.md`
- `orchestrator/rounds/round-058/plan.md`
- `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/roadmap.md`
- `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/verification.md`
- `orchestrator/project-contract.md`
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`

Read prior artifacts and reviews from rounds 052-057 as named in the plan:

- `orchestrator/rounds/round-052/import-facade-inventory.md`
- `orchestrator/rounds/round-052/review.md`
- `orchestrator/rounds/round-053/runtime-compatibility-file-inventory.md`
- `orchestrator/rounds/round-053/review.md`
- `orchestrator/rounds/round-054/import-replacement-readiness.md`
- `orchestrator/rounds/round-054/review.md`
- `orchestrator/rounds/round-055/runtime-file-behavior-gates.md`
- `orchestrator/rounds/round-055/review.md`
- `orchestrator/rounds/round-056/import-facade-cleanup-policy.md`
- `orchestrator/rounds/round-056/review.md`
- `orchestrator/rounds/round-057/runtime-compatibility-cleanup-policy.md`
- `orchestrator/rounds/round-057/review.md`

Focused scans/readbacks run during implementation:

```text
rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))($| +|\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))($| +|\()' examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg --no-filename -o --replace '$2' '^ *import +(qualified +)?(CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)))($| +|\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github | sort | uniq -c
rg -n 'exposed-modules|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Spec|Workflow\.EventLog\.Core|Workflow\.EventLog\.File\.Core|Workflow\.EventLog\.Commit\.Core|Workflow\.Execution\.Core|Workflow\.Permission\.Core)' *.cabal */*.cabal
find . -name 'issue-state.json' -o -name 'daemon-state.json' -o -name 'planning-state.json' -o -name '*pr-url*' -o -name '*pr-state*' -o -name '*block*state*' -o -name '*repair*state*' -o -name '*owner*' -o -name '*snapshot*'
rg -n "issue-state\.json|daemon-state\.json|planning-state\.json|pr-url|pr state|PR URL|pr_url|watcher-state\.json|checker-state\.json|agent-state\.json|reviewer-state\.json|block-state\.json|repair-state\.json|runtime-owner\.json|runtime owner|compatibility snapshot|issue-snapshot\.json|snapshot" src app test scripts docs examples golden orchestrator
rg -n "compatibilityStateWrites|CompatibilityWrite|writeCompatibility|RecordBlocked|RecordPlanningGraph|repair-invalid-state|repair-state\.json|Healthcheck|healthcheck|runtime-owner\.json|RuntimeOwner|issue-snapshot\.json|goldenReplayCases|goldenBootstrapCases" src test scripts docs golden
rg -n "TODO|FIXME|planning-state\.json|repair-state\.json|runtime-owner\.json|issue-snapshot\.json|PR URL|pr_url|block-state\.json|compatibility snapshot|owner" src test scripts docs orchestrator/rounds/round-05{2,3,4,5,6,7}
```

Focused source readbacks:

- `src/CodexWatcher/Runtime/Compatibility.hs`
- `src/CodexWatcher/Healthcheck.hs`
- `src/CodexWatcher/Cli/Command/Replay.hs`
- `src/CodexWatcher/Runtime/Owner/Store.hs`
- `src/CodexWatcher/Runtime/Owner/Cli.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
- `scripts/restart-watcher`

## Results

- Exact selected-facade import counts remain:
  `CodexWatcher.AppServerClient` 28, `CodexWatcher.Core.Ids` 65,
  `CodexWatcher.Workflow.Types` 10, `CodexWatcher.Workflow.EventLog` 3,
  `CodexWatcher.Workflow.Execution` 4, and
  `CodexWatcher.Workflow.Permission` 1.
- No selected-facade imports were found under `examples`,
  `agent-workflow-core`, `agent-workflow-codex`, or
  `agent-workflow-github`.
- The selected checked-in runtime fixture set is still limited to three
  `issue-state.json` fixtures, one `daemon-state.json` fixture, and one
  PR-review `block-state.json` fixture.
- No checked-in `planning-state.json`, `repair-state.json`,
  `runtime-owner.json`, dedicated `*pr-url*`, dedicated `*pr-state*`, or live
  `issue-snapshot.json` fixture was found.
- The discovery artifact keeps all items as proposals for later roadmap
  expansion only.

## Verification

Minimum verification run for handoff:

```text
sed -n '1,260p' orchestrator/rounds/round-058/follow-up-discovery.md
rg -n 'approve|approval|approved|DEPRECATED|deprecated pragma|remove-later|removal approved|publish|upload|roadmap revision|Cabal|exposed-modules' orchestrator/rounds/round-058/follow-up-discovery.md
git diff --name-status --
git status --short
git diff --check
git diff --no-index --check /dev/null orchestrator/rounds/round-058/follow-up-discovery.md
git diff --no-index --check /dev/null orchestrator/rounds/round-058/implementation-notes.md
```

Results:

- Readback passed.
- Banned-claim check returned only negative/non-goal wording or future-gated
  wording.
- Boundary diff check showed no tracked diff; `git status --short` showed only
  the untracked round-local `orchestrator/rounds/round-058/` directory.
- `git diff --check` passed.
- `git diff --no-index --check` on both new untracked artifacts produced no
  whitespace-error output. The command exits `1` for `/dev/null` comparisons
  because the files differ from `/dev/null`; that exit was expected.

Full `cabal build all`, `cabal test watcher-core-test`, and
`scripts/validate-workflow-packages.sh` were not required by the implementation
plan for this artifact-only discovery round.
