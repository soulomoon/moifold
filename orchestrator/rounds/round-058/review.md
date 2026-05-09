### Checks Run
- Command: `sed -n '1,260p' orchestrator/rounds/round-058/follow-up-discovery.md`
  Result: pass. The artifact is evidence-only, lists inputs and scans, records twelve compact candidates, preserves `keep`/`defer` classifications, and frames recommended placement as a handoff for later roadmap expansion only.

- Command: `sed -n '261,560p' orchestrator/rounds/round-058/follow-up-discovery.md`
  Result: pass. The remaining candidate list, rejected/deferred non-candidates, blockers, milestone placement, and handoff notes do not approve deprecation, migration, removal, publication, upload, release gates, exposed-module removal, or roadmap revision publication.

- Command: `git diff --check`
  Result: pass. No tracked-diff whitespace errors.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors; no staged changes were present.

- Command: `git diff --name-status -- && git status --short`
  Result: pass. `git diff --name-status --` was empty. `git status --short` showed only the untracked round-local directory `orchestrator/rounds/round-058/`.

- Command: `find orchestrator/rounds/round-058 -maxdepth 1 -type f -print | sort`
  Result: pass. The round directory contains only `follow-up-discovery.md`, `implementation-notes.md`, `plan.md`, and `selection.md` before review artifacts were written.

- Command: `git diff --no-index --check /dev/null orchestrator/rounds/round-058/follow-up-discovery.md`
  Result: pass for whitespace. The command exited `1` only because the untracked file differs from `/dev/null`; it emitted no whitespace-error output.

- Command: `git diff --no-index --check /dev/null orchestrator/rounds/round-058/implementation-notes.md`
  Result: pass for whitespace. The command exited `1` only because the untracked file differs from `/dev/null`; it emitted no whitespace-error output.

- Command: `git diff --no-index --check /dev/null orchestrator/rounds/round-058/plan.md`
  Result: pass for whitespace. The command exited `1` only because the untracked file differs from `/dev/null`; it emitted no whitespace-error output.

- Command: `git diff --no-index --check /dev/null orchestrator/rounds/round-058/selection.md`
  Result: pass for whitespace. The command exited `1` only because the untracked file differs from `/dev/null`; it emitted no whitespace-error output.

- Command: `rg --no-filename -o --replace '$2' '^ *import +(qualified +)?(CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)))($| +|\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github | sort | uniq -c`
  Result: pass. Counts match the discovery report: `CodexWatcher.AppServerClient` 28, `CodexWatcher.Core.Ids` 65, `CodexWatcher.Workflow.EventLog` 3, `CodexWatcher.Workflow.Execution` 4, `CodexWatcher.Workflow.Permission` 1, and `CodexWatcher.Workflow.Types` 10.

- Command: `rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))($| +|\()' examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass. No matches; examples and standalone package candidates have no selected-facade import regressions.

- Command: `rg -n 'exposed-modules|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Spec|Workflow\.EventLog\.Core|Workflow\.EventLog\.File\.Core|Workflow\.EventLog\.Commit\.Core|Workflow\.Execution\.Core|Workflow\.Permission\.Core)' *.cabal */*.cabal`
  Result: pass. `moifold.cabal` still exposes the six selected facades, and the three package candidates expose the preferred replacement modules cited by the report. No Cabal file was edited.

- Command: `find . -name 'issue-state.json' -o -name 'daemon-state.json' -o -name 'planning-state.json' -o -name '*pr-url*' -o -name '*pr-state*' -o -name '*block*state*' -o -name '*repair*state*' -o -name '*owner*' -o -name '*snapshot*' | sort`
  Result: pass. The checked-in selected compatibility fixtures are exactly three `issue-state.json` fixtures, one `daemon-state.json` fixture, and one PR-review `block-state.json` fixture. No checked-in `planning-state.json`, `repair-state.json`, `runtime-owner.json`, dedicated `*pr-url*`, dedicated `*pr-state*`, or live `issue-snapshot.json` fixture was found.

- Command: `rg -n "compatibilityStateWrites|CompatibilityWrite|writeCompatibility|RecordBlocked|RecordPlanningGraph|repair-invalid-state|repair-state\.json|Healthcheck|healthcheck|runtime-owner\.json|RuntimeOwner|issue-snapshot\.json|goldenReplayCases|goldenBootstrapCases" src test scripts docs golden`
  Result: pass. The scan confirms the report's evidence: compatibility projection, direct planning/block writes, repair ordering, healthcheck reads, runtime-owner behavior, live snapshot timing, and golden replay/bootstrap tests remain the relevant gates.

- Command: `sed -n '1,180p' src/CodexWatcher/Runtime/Compatibility.hs && sed -n '240,290p' src/CodexWatcher/Healthcheck.hs`
  Result: pass. `Runtime.Compatibility` writes the selected compatibility files, while `Healthcheck.stateFileSpecs` reads planner/issue/PR state, shared daemon/block/runtime-owner files, and does not list `planning-state.json`, `repair-state.json`, or live `issue-snapshot.json`.

- Command: `sed -n '50,110p' src/CodexWatcher/Cli/Command/Replay.hs && sed -n '35,85p' src/CodexWatcher/Runtime/Owner/Store.hs && sed -n '140,230p' scripts/restart-watcher`
  Result: pass. Repair writes `repair-state.json`, rewrites compatibility files, then removes stale `block-state.json`; runtime-owner store writes/reads `runtime-owner.json` with a top-level `lease`; `scripts/restart-watcher` parses and removes `runtime-owner.json`.

- Command: `sed -n '230,255p' src/CodexWatcher/Domain/IssuePlanning/Loop.hs && sed -n '4800,5005p' test/Main.hs`
  Result: pass. Issue planning writes live `issue-snapshot.json` before planner turn start in execute mode, and tests assert snapshot write timing plus closed-scope snapshot behavior.

- Command: `rg -n 'approve|approval|approved|DEPRECATED|deprecated pragma|remove-later|removal approved|publish|upload|roadmap revision|Cabal|exposed-modules' orchestrator/rounds/round-058/follow-up-discovery.md`
  Result: pass. Matches are negative/non-goal wording, future-gated wording, scan text, or explicit "not approval" wording. No banned overclaim was found.

- Command: `cabal build all`
  Result: not run. Reviewer judgment: this round is artifact-only and boundary checks show no source, test, docs policy, Cabal, runtime, fixture, project-contract, or roadmap changes. The full baseline remains required for later source/docs policy/Cabal/runtime/removal work, but rerunning it would not increase confidence in this discovery-only artifact.

- Command: `cabal test watcher-core-test`
  Result: not run. Same artifact-only rationale as above; focused scans and readbacks verified the evidence used by the candidate list.

- Command: `scripts/validate-workflow-packages.sh`
  Result: not run. Same artifact-only rationale as above; no package descriptors or package source files changed.

### Plan Compliance
- Re-read controlling inputs: met. Reviewed `selection.md`, `plan.md`, `implementation-notes.md`, `verification.md`, `project-contract.md`, and reviewer guidance.
- Read prior evidence artifacts from rounds 052-057: met as needed. The review checked the round 056 and 057 policy/review artifacts and refreshed the source evidence behind the round 058 candidate list.
- Refresh focused import-facade evidence: met. Counts, standalone-package/example absence, and Cabal exposure are current and match the report.
- Refresh focused runtime compatibility-file evidence: met. Filename, behavior, source, healthcheck, repair, runtime-owner, and live snapshot scans support the reported gaps.
- Keep the round artifact-only: met. No implementation files, roadmap files, docs policy files, project contract, Cabal descriptors, source, tests, scripts, fixtures, runtime compatibility files, or import surfaces were changed.
- Candidate list quality: met. The twelve candidates are compact enough for roadmap expansion, each names a surface, current classification, blocker, evidence source, proposed later direction type, and why it is not current migration/removal approval.
- Classification accuracy: met. Current classifications remain `keep` or `defer`; no selected runtime compatibility surface is upgraded to `remove-later`.
- Banned-claim/readback checks: met. The artifact does not imply deprecation, migration, removal, package publication, upload, release gate satisfaction, exposed-module removal, roadmap revision publication, or current roadmap update approval.
- Handoff boundary: met. Recommended milestone placement is explicitly a proposal for the next roadmap-update role; `direction-008-roadmap-expansion-update` remains responsible for publishing any roadmap update.

### Decision
**APPROVED**

### Evidence
The integrated result is a round-local discovery artifact only. Boundary checks show only `orchestrator/rounds/round-058/` as untracked before review; there are no tracked diffs and no staged changes.

The import evidence supports the four import-facade candidates: `CodexWatcher.Core.Ids` remains high-volume at 65 imports, `CodexWatcher.AppServerClient` remains at 28 imports, `CodexWatcher.Workflow.EventLog` has 3 imports with concrete helper concerns, and `CodexWatcher.Workflow.Permission` remains public despite only one repo-local import. No selected-facade imports appear in examples or standalone package candidates.

The runtime evidence supports the seven runtime-file candidates and the cross-cutting external inventory candidate: the checked-in fixture set lacks `planning-state.json`, `repair-state.json`, `runtime-owner.json`, active/stopped daemon fixtures, repair-failure block-state fixtures, dedicated PR URL/state paths, and live `issue-snapshot.json`; source scans confirm current producers/readers and the healthcheck/non-healthcheck boundaries.

The report is conservative. It preserves current `keep`/`defer` classifications, identifies missing evidence, and hands off candidate placement without approving or performing any cleanup.
