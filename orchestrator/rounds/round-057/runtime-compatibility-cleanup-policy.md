# Runtime Compatibility Cleanup Policy

Round: `round-057`

Scope: docs/policy/artifact-only cleanup policy for runtime compatibility
files and snapshots selected by
`round-057-runtime-compatibility-cleanup-policy`. This round does not rename
files, change schemas, migrate state, alter write timing, change event JSON
`type` fields, change repair or healthcheck behavior, change runtime behavior,
expand the roadmap, change import-facade policy, or approve removal.

## Evidence Inputs

- `orchestrator/rounds/round-053/runtime-compatibility-file-inventory.md`
  provides the source-backed inventory of producers, readers, write timing,
  healthcheck, repair, fixtures, snapshots, protecting tests, and unknowns.
- `orchestrator/rounds/round-055/runtime-file-behavior-gates.md` provides the
  readiness labels and behavior gates. It found no selected runtime surface as
  `remove-later`.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md` is the
  framework-facing policy surface updated by this round.
- `orchestrator/project-contract.md` already records the durable invariant
  that compatibility files keep current names and field meanings unless
  explicitly migrated, and that runtime compatibility-file removal requires
  old-log, golden, repair, healthcheck, and write-timing evidence.

## Refreshed Scan Results

Commands run from the round worktree before editing:

```sh
find . -name 'issue-state.json' -o -name 'daemon-state.json' -o -name 'planning-state.json' -o -name '*pr-url*' -o -name '*pr-state*' -o -name '*block*state*' -o -name '*repair*state*' -o -name '*owner*' -o -name '*snapshot*'
rg -n "issue-state\\.json|daemon-state\\.json|planning-state\\.json|pr-url|pr state|PR URL|pr_url|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|runtime owner|compatibility snapshot|issue-snapshot\\.json|snapshot" src app test scripts docs examples golden orchestrator
rg -n "compatibilityStateWrites|CompatibilityWrite|writeCompatibility|RecordBlocked|RecordPlanningGraph|repair-invalid-state|repair-state\\.json|Healthcheck|healthcheck|runtime-owner\\.json|RuntimeOwner|issue-snapshot\\.json|goldenReplayCases|goldenBootstrapCases" src test scripts docs golden
rg -n "writeFile|atomicWrite|encodeFile|decodeFile|eitherDecode|readFile|doesFileExist|renameFile|copyFile|removeFile" src test scripts
```

Policy-relevant results:

- `find` found the same five checked-in selected runtime fixture files as
  rounds 053 and 055:
  `golden/issue-implement/mlf2-issue42-blocked/issue-state.json`,
  `golden/issue-implement/mlf2-issue42-plan-ready/issue-state.json`,
  `golden/issue-implement/mlf2-issue42-incomplete/issue-state.json`,
  `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json`, and
  `golden/pr-review/mlf2-pr6-blocked/block-state.json`.
- The broad filename and docs scan returned 751 lines after existing round
  artifacts and docs; true source/test clusters remain the round 053/055
  clusters: `Runtime.Compatibility`, `EffectInterpreter`, `Cli.Command.Replay`,
  `Healthcheck`, `Snapshot`, runtime owner store/CLI, automatic-loop fanout and
  reconciliation paths, `scripts/restart-watcher`, and `test/Main.hs`.
- The focused compatibility, repair, healthcheck, runtime-owner, snapshot, and
  golden scan returned 427 lines and did not reveal a new selected surface or a
  stronger removal classification.
- The file-IO scan returned 92 lines. Selected compatibility JSON writes still
  route through whole-file JSON helpers such as `Runtime.File.writeJsonValue`
  using a temporary file and `renameFile`, while event logs remain line-based.
- No checked-in file named `planning-state.json`, `repair-state.json`,
  `runtime-owner.json`, dedicated `*pr-url*`, dedicated `*pr-state*`, or live
  `issue-snapshot.json` was found.

No refreshed scan proved a source-backed delta from round 055, so round 055
remains the controlling classification evidence.

## Classification Table

| Surface | Classification | Policy basis |
| --- | --- | --- |
| `issue-state.json` | `keep` | Current producer/reader contract with healthcheck, repair rewrite, golden issue snapshots, PR URL projection tests, daemon write-order tests, and external-operator unknowns. |
| `daemon-state.json` | `keep` | Current daemon summary contract with healthcheck, repair rewrite, golden incomplete issue fixture, daemon write-order tests, and missing active/stopped fixture coverage. |
| `planning-state.json` | `defer` | Direct `RecordPlanningGraph` planned write and compatibility projection are protected, but there is no healthcheck reader and no checked-in old `planning-state.json` fixture. |
| PR review state files | `keep` | `watcher-state.json`, `checker-state.json`, optional `agent-state.json`, and `reviewer-state.json` remain current PR-review operator state with golden and healthcheck coverage. |
| PR URL fields / absent dedicated PR URL file | `defer` | Current source uses `issue-state.json` `pr_url` and PR-review config `prUrl`; no dedicated file exists, but external path expectations have not been inventoried. |
| `block-state.json` | `keep` | Direct blocked writes, compatibility projection, repair-failure block state, healthcheck reads, stale-block removal after repair, and golden blocked fixture evidence make it current operator state. |
| `repair-state.json` | `defer` | Repair execute writes it with tested ordering, but there is no production reader, healthcheck reader, or checked-in fixture. |
| `runtime-owner.json` | `keep` | Runtime lease state is live daemon ownership state used by runtime owner CLI, automatic loop, healthcheck, and `scripts/restart-watcher`; tests protect lease parsing and cleanup behavior. |
| Checked-in compatibility snapshots | `defer` | Golden snapshot directories and event-log fixtures are active compatibility evidence; no snapshot removal is approved without fixture-by-fixture proof. |
| Live `issue-snapshot.json` | `defer` | Write timing before planner turn start is tested, but there is no checked-in live snapshot fixture and no healthcheck reader. |

No selected surface is classified as `remove-later`.

## Gates For Future Work

Before any later deprecation, migration, or removal round may select one of
these surfaces, it must prove the exact selected file, field, or snapshot
against all applicable gates:

- old-log and golden replay/bootstrap compatibility;
- repair behavior and source order;
- healthcheck behavior, including read-only reporting or an explicit reviewed
  non-healthcheck ownership decision;
- write timing across event append, launch/fanout, startup/reconciliation,
  runtime-owner renewal/clear, and live snapshot-before-turn-start paths;
- fixture coverage for old and current JSON shapes;
- external operator, runbook, script, and downstream direct-reader inventory;
- focused behavior tests plus baseline validation;
- reviewer approval that names the surface and states every required gate is
  satisfied.

This policy is not removal approval. Missing evidence keeps the surface
available.

## Project Contract Alignment

`orchestrator/project-contract.md` was re-read before and after the policy
update. It already records the durable repo-wide invariant for compatibility
file names and field meanings, plus the sequencing rule that runtime
compatibility-file removal requires old-log, golden, repair, healthcheck, and
write-timing evidence. No durable invariant was missing, so this round leaves
the project contract unchanged.
