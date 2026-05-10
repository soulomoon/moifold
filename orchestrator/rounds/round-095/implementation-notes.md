### Changes Made

- `golden/runtime-compatibility/issue-snapshot/scoped-open-with-closed-subissue/issue-snapshot.json`: added the checked-in live issue-planning snapshot fixture for scoped open root issue `#12` with closed child sub-issue `#26`.
- `test/RuntimeCompatibilityFixtureSpec.hs`: added issue-snapshot fixture assertions, `planningIssueFactsFromSnapshot` fixture-backed parser coverage, execute-mode write-before-planner-turn coverage, and source-boundary checks for prompt consumption plus healthcheck/repair/replay/restart non-reader behavior.
- `orchestrator/rounds/round-095/implementation-notes.md`: recorded implementation and verification evidence for this round.

### Tests

- `test/RuntimeCompatibilityFixtureSpec.hs`: verifies the fixture decodes as JSON and exactly matches the current `buildIssuePlanningSnapshot` shape: top-level `repoFullName`, `scopeIssueNumbers`, and `issues`; writer-added `parentIssueNumber` and `subIssues`; scoped root issue GitHub fields; closed child sub-issue fields; absence of runtime-state fields.
- `test/RuntimeCompatibilityFixtureSpec.hs`: verifies `planningIssueFactsFromSnapshot` derives open root issue `12` with child `26`, and closed child issue `26` with parent `12`.
- `test/RuntimeCompatibilityFixtureSpec.hs`: verifies execute-mode issue planning writes exactly one `issue-snapshot.json` value equal to the fixture before the planner `turn/start`, and still starts one planner thread plus one planner turn for the open scoped issue case.
- `test/RuntimeCompatibilityFixtureSpec.hs`: verifies source boundaries: `runPlanningReady` still ensures the issue snapshot before planner turn start; `issuePlanningSnapshotPath` still uses `runtimeStateDirFile ... "issue-snapshot.json"`; the prompt still renders/tells the planner to read the snapshot path; healthcheck, repair, replay snapshot loading, and `scripts/restart-watcher` remain live `issue-snapshot.json` non-readers.

### Notes

- Scope inputs read:
  - `git status --short --untracked-files=all`: exit 0; pre-existing dirty state included `M orchestrator/state.json` and untracked round-095 artifacts before implementation edits.
  - `python3 -m json.tool orchestrator/state.json`: exit 0.
  - `sed -n '1,220p' orchestrator/rounds/round-095/selection.md`: exit 0.
  - `sed -n '1,280p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`: exit 0.
  - `sed -n '1,240p' orchestrator/project-contract.md`: exit 0.
  - `sed -n '1,170p' orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`: exit 0.
  - `sed -n '1,220p' orchestrator/rounds/round-094/plan.md`: exit 0.
- Source scan before editing:
  - `rg -n "issue-snapshot\\.json|issuePlanningSnapshotPath|issueSnapshotPath|buildIssuePlanningSnapshot|ensureIssuePlanningSnapshot|planningIssueFactsFromSnapshot|stateFileSpecs|repairInvalidState|read_runtime_owner_pid" src app test docs scripts golden -g '!dist-newstyle/**'`: exit 0; confirmed current writer, prompt path, existing tests, and non-reader scan targets.
- Focused verification:
  - `find golden/runtime-compatibility/issue-snapshot -type f | sort`: exit 0; listed `golden/runtime-compatibility/issue-snapshot/scoped-open-with-closed-subissue/issue-snapshot.json`.
  - `python3 -m json.tool golden/runtime-compatibility/issue-snapshot/scoped-open-with-closed-subissue/issue-snapshot.json`: exit 0.
  - `rg -n "issue-snapshot\\.json|issuePlanningSnapshotPath|issueSnapshotPath|buildIssuePlanningSnapshot|ensureIssuePlanningSnapshot|planningIssueFactsFromSnapshot|RuntimeCompatibilityFixtureSpec|runtimeCompatibilityFixtureTests|runAutomaticDaemonLoopOnceWithEvents" golden test src app docs scripts -g '!dist-newstyle/**'`: exit 0.
  - `cabal test watcher-core-test`: first run exit 1 due missing `LambdaCase` in the edited test module; fixed by adding the extension.
  - `cabal test watcher-core-test`: second run exit 1 due hidden `vector` package import in the edited test helper; fixed by using Aeson `fromJSON` instead of importing `Data.Vector`.
  - `cabal test watcher-core-test`: exit 0; `Test suite watcher-core-test: PASS`.
  - `git diff --check`: exit 0.
  - `cabal build all`: exit 0.
- No staging was performed, so `git diff --cached --check` was not applicable.
- I did not edit `orchestrator/state.json`, roadmap files, production behavior, prompt templates, healthcheck, replay, restart, Cabal wiring, or unrelated compatibility fixtures.
