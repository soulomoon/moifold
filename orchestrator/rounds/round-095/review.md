### Checks Run

- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`
  Result: pass; reviewer duties, boundaries, and output format loaded.
- Command: `python3 -m json.tool orchestrator/state.json`
  Result: pass; state JSON is valid and records `round-095`, `stage: review`, roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`.
- Command: `sed -n '1,320p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass; baseline and compatibility-fixture checks loaded from the active roadmap bundle.
- Command: `find golden/runtime-compatibility/issue-snapshot -type f | sort`
  Result: pass; listed `golden/runtime-compatibility/issue-snapshot/scoped-open-with-closed-subissue/issue-snapshot.json`.
- Command: `python3 -m json.tool golden/runtime-compatibility/issue-snapshot/scoped-open-with-closed-subissue/issue-snapshot.json`
  Result: pass; fixture parses as JSON and has the expected scoped root issue plus closed child sub-issue shape.
- Command: `rg -n "issue-snapshot\\.json|issuePlanningSnapshotPath|issueSnapshotPath|buildIssuePlanningSnapshot|ensureIssuePlanningSnapshot|planningIssueFactsFromSnapshot|RuntimeCompatibilityFixtureSpec|runtimeCompatibilityFixtureTests|runAutomaticDaemonLoopOnceWithEvents" golden test src app docs scripts -g '!dist-newstyle/**'`
  Result: pass; found the live writer/path/parser/prompt references, new fixture-test coverage, and no unexpected app/script reader expansion.
- Command: `git diff --check`
  Result: pass; no whitespace errors in tracked diffs.
- Command: `git diff --cached --check`
  Result: pass; no staged diff was present.
- Command: `git status --short --untracked-files=all`
  Result: pass; changed paths are `orchestrator/state.json`, `test/RuntimeCompatibilityFixtureSpec.hs`, the new issue-snapshot fixture, and round-095 artifacts.
- Command: `git diff --name-status`
  Result: pass; tracked implementation diff is limited to `orchestrator/state.json` and `test/RuntimeCompatibilityFixtureSpec.hs`; untracked expected fixture and round artifacts are visible in status.
- Command: `git diff --stat`
  Result: pass; tracked diff is 51 lines in active-round state metadata and 298 lines in `test/RuntimeCompatibilityFixtureSpec.hs`.
- Command: `git diff -- orchestrator/state.json`
  Result: pass; diff is controller active-round metadata for `round-095` at review stage. I did not edit it.
- Command: `git diff -- test/RuntimeCompatibilityFixtureSpec.hs`
  Result: pass; test changes add issue-snapshot fixture, parser, execute-writer, and source-boundary assertions without weakening existing fixture checks.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`. New issue-snapshot assertions passed, including fixture shape, `planningIssueFactsFromSnapshot`, write-before-turn, prompt path, and non-reader boundaries.
- Command: `cabal build all`
  Result: pass; build was up to date.

### Plan Compliance

- Step 1, reconfirm current scope and inputs: met. State, selection, plan, project contract, and active verification bundle were read; state lineage matches roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`.
- Step 2, reconfirm writer, prompt path, prompt text, and non-reader boundaries: met. The `rg` scan and source-boundary tests cover `issue-snapshot.json`, `issuePlanningSnapshotPath`, `ensureIssuePlanningSnapshot`, `buildIssuePlanningSnapshot`, `planningIssueFactsFromSnapshot`, prompt rendering, and healthcheck/replay/snapshot/restart non-readers.
- Step 3, add fixture at the expected path: met. The fixture exists at `golden/runtime-compatibility/issue-snapshot/scoped-open-with-closed-subissue/issue-snapshot.json` and parses with `python3 -m json.tool`.
- Step 4, extend `runtimeCompatibilityFixtureTests`: met. `issueSnapshotFixtureTests` and `issueSnapshotSourceBoundaryTest` are included in `runtimeCompatibilityFixtureTests`.
- Step 5, assert current fixture shape directly: met. `watcher-core-test` passed assertions for top-level `repoFullName`, `scopeIssueNumbers`, `issues`, scoped root issue fields, child issue fields, and absence of runtime-state fields.
- Step 6, add fixture-backed parser assertion: met. `planningIssueFactsFromSnapshot` accepts the fixture and derives open root issue `12` with child `26`, plus closed child issue `26` with parent `12`.
- Step 7, add execute-writer assertion: met. The focused test verifies exactly one `issue-snapshot.json` write equal to the fixture, before planner `turn/start`, while starting one planner thread and one planner turn.
- Step 8, add source-boundary assertions: met. Tests verify execute write ordering, path construction, top-level writer keys, `parentIssueNumber`/`subIssues`, prompt path rendering, prompt instruction text, and non-reader status for healthcheck, repair/replay source, snapshot loading, and restart script.
- Step 9, inspect final diff and keep scope narrow: met. No production behavior, prompt template, healthcheck, repair, replay, restart, Cabal, docs/policy, roadmap, facade, migration, deprecation, rename, deletion, or removal change is present. The only controller-state diff is active-round review metadata already required for this orchestrator run and was not edited during review.

### Decision

**APPROVED**

### Evidence

The implementation adds focused fixture evidence for the live `issue-snapshot.json` compatibility surface without changing the surface itself. The checked-in fixture locks the current writer shape, the parser test proves canonical planning still consumes it, and the execute-mode test proves the snapshot is written before planner turn start.

Roadmap baseline checks passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`. The compatibility-fixture task-specific checks also passed: fixture path discovery, JSON parsing, source/reference scan, fixture shape assertions, parser assertions, write-timing assertions, prompt assertions, and non-reader boundary assertions.

Alignment checks are satisfied for this round: no compatibility file was renamed or removed, no deprecation/removal approval is implied, public facades and package boundaries are untouched, `planner-state.json` and `planning-state.json` remain distinct, and no older roadmap family was modified.
