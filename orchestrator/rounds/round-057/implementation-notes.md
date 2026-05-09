# Implementation Notes

- Updated `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  with a runtime compatibility-file cleanup policy section backed by rounds 053,
  055, and 057.
- Added
  `orchestrator/rounds/round-057/runtime-compatibility-cleanup-policy.md` with
  refreshed scan results, conservative classifications, future gates, and the
  project-contract alignment decision.
- Left `orchestrator/project-contract.md` unchanged because it already contains
  the durable invariant for runtime compatibility-file names, field meanings,
  cleanup sequencing, and old-log/golden/repair/healthcheck/write-timing gates.

## Focused Read-Only Scans

- `find . -name 'issue-state.json' -o -name 'daemon-state.json' -o -name 'planning-state.json' -o -name '*pr-url*' -o -name '*pr-state*' -o -name '*block*state*' -o -name '*repair*state*' -o -name '*owner*' -o -name '*snapshot*'`:
  passed; found the same five selected checked-in fixture files recorded by
  rounds 053 and 055.
- `rg -n "issue-state\\.json|daemon-state\\.json|planning-state\\.json|pr-url|pr state|PR URL|pr_url|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|runtime owner|compatibility snapshot|issue-snapshot\\.json|snapshot" src app test scripts docs examples golden orchestrator`:
  passed; returned 751 lines after existing docs and round artifacts, with no
  policy-relevant delta from round 055.
- `rg -n "compatibilityStateWrites|CompatibilityWrite|writeCompatibility|RecordBlocked|RecordPlanningGraph|repair-invalid-state|repair-state\\.json|Healthcheck|healthcheck|runtime-owner\\.json|RuntimeOwner|issue-snapshot\\.json|goldenReplayCases|goldenBootstrapCases" src test scripts docs golden`:
  passed; returned 427 lines and preserved the round 055 behavior-gate evidence.
- `rg -n "writeFile|atomicWrite|encodeFile|decodeFile|eitherDecode|readFile|doesFileExist|renameFile|copyFile|removeFile" src test scripts`:
  passed; returned 92 lines and confirmed selected compatibility JSON writes
  remain whole-file JSON writes while event logs remain line-based.

## Verification

- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed; 1 of 1 test suites passed.
- `scripts/validate-workflow-packages.sh`: passed; `cabal check` found no
  errors or warnings for `agent-workflow-core`, `agent-workflow-codex`, and
  `agent-workflow-github`, source distributions were validated, and no upload
  or package publication command was run.
- `rg -n "runtime compatibility|compatibility-file|issue-state\\.json|daemon-state\\.json|planning-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|issue-snapshot\\.json|pr_url|watcher-state\\.json|checker-state\\.json|reviewer-state\\.json|keep|defer|remove-later" docs/agentic-workflow-framework orchestrator/rounds/round-057 orchestrator/project-contract.md`:
  passed; readback confirmed the policy/artifact wording covers the selected
  surfaces and does not imply removal approval.
- `git diff -- docs/agentic-workflow-framework orchestrator/project-contract.md orchestrator/rounds/round-057`:
  passed; diff is docs/policy/artifact-only and leaves
  `orchestrator/project-contract.md` unchanged.
- `git diff --name-only`: passed for tracked changes; it lists
  `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`. The
  round-local artifacts are new untracked files and are visible through
  `git status --short`.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.
- `git status --short`: passed; changed files are docs and round-local
  orchestrator artifacts only.
