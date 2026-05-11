### Checks Run
- Command: `printf 'prop_turnClassifierMapsDomainOutputs\nprop_turnClassifierPrefersStructuredOutputs\nprop_turnClassifierBlocksMissingOutputs\nautomaticPlanningSystemErrorRetriesWatcher\nautomaticPlanningSystemErrorBlocksAfterRetryLimit\n:quit\n' | cabal repl watcher-core-test`
  Result: pass. GHCi loaded `watcher-core-test`; the three classifier properties returned `True`, and both planning systemError retry/blocking examples printed PASS markers and returned `True`.

- Command: `cabal test watcher-core-test`
  Result: pass. Full `watcher-core-test` suite completed with `Test suite watcher-core-test: PASS`; 1 of 1 test suites passed.

- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

- Command: `git diff --check`
  Result: pass. No whitespace errors.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.

- Command: `! rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  Result: pass. The target file no longer imports `CodexWatcher.AppServerClient`.

- Command: `rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.Agent\.Codex\.Client[[:space:]]+\(AppServerTurn\)' src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  Result: pass. The target file directly imports `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)` at line 40.

- Command: `rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' src app test docs '*.cabal' 'package.yaml' 'cabal.project*' agent-workflow-* 2>/dev/null || true`
  Result: pass. The target file is absent from remaining facade users. Remaining hits are out of scope: `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `src/CodexWatcher/AutomaticLoop/Runner.hs`, and test/test-support imports.

- Command: `git diff --name-only -- . ':!src/CodexWatcher/Domain/IssuePlanning/Loop.hs' ':!orchestrator/rounds/round-120/plan.md' ':!orchestrator/rounds/round-120/selection.md' ':!orchestrator/state.json'`
  Result: pass. No paths printed.

- Command: `git diff --name-only -- src/CodexWatcher/AppServerClient.hs src/CodexWatcher/AppServerProtocol.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Interpreter.hs src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs src/CodexWatcher/Domain/PrReview/LaunchCli.hs src/CodexWatcher/AutomaticLoop/Runner.hs src/CodexWatcher/Cli/Command/IssueFanout.hs docs runtime fixtures app test`
  Result: pass. No forbidden production, docs, runtime, fixture, app, or test paths printed.

- Command: `git diff --name-only -- '*.cabal' 'package.yaml' 'cabal.project*'`
  Result: pass. No package descriptor paths printed.

- Command: `git diff -- src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  Result: pass. Diff removes `import CodexWatcher.AppServerClient` and adds `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)` only.

- Command: `git diff -- src/CodexWatcher/Domain/IssuePlanning/Loop.hs | rg --pcre2 -n '^[-+](?!import |$)'`
  Result: pass after manual accounting. The only matches were diff headers (`---` and `+++`); no non-import body lines changed.

- Command: `rg -n 'planningSystemErrorObservation|AppServerTurn|WorkflowAgentCodex' src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  Result: pass. `planningSystemErrorObservation` still has the same `Maybe AppServerTurn` type site and surrounding logic sites; only the type import source changed.

- Command: `test ! -e orchestrator/rounds/round-120/worker-plan.json`
  Result: pass. No worker plan exists.

- Command: `jq -e '.roadmap_id == "2026-05-11-00-highest-value-cleanup" and .roadmap_revision == "rev-001" and .controller_stage == "dispatch-rounds" and .active_round_id == "round-120" and (.active_rounds | length) == 1 and .active_rounds[0].round_id == "round-120" and .active_rounds[0].stage == "review" and .active_rounds[0].worker_mode == "none" and .active_rounds[0].merge_ready == false and (.active_rounds[0].roadmap_item_id == "round-120-issue-planning-loop-appserverclient-import-convergence")' orchestrator/state.json`
  Result: pass. State lineage matches round 120 at the current `review` lifecycle stage.

- Command: `jq -e '(.review_records == null or (.review_records | type == "object")) and (.roadmap_update == null)' orchestrator/state.json`
  Result: pass. No roadmap update is active.

- Command: `jq -e '.roadmap_id == "2026-05-11-00-highest-value-cleanup" and .roadmap_revision == "rev-001" and .roadmap_dir == "orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001" and .milestone_id == "milestone-003-import-convergence-package-boundaries" and .direction_id == "direction-010-appserverclient-import-convergence" and .extracted_item_id == "round-120-issue-planning-loop-appserverclient-import-convergence" and .roadmap_item_id == "round-120-issue-planning-loop-appserverclient-import-convergence" and .decision == "approved" and (.evidence_summary | type == "string" and length > 0)' orchestrator/rounds/round-120/review-record.json`
  Result: pass. Review record contains the requested approved decision and round lineage.

- Command: `python3 -m json.tool orchestrator/rounds/round-120/review-record.json`
  Result: pass. Review record is valid JSON.

- Command: `git diff --check`
  Result: pass after writing review artifacts. No whitespace errors were introduced by the review files.

### Plan Compliance
- Replace only the target facade import: met. `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` no longer imports `CodexWatcher.AppServerClient` and directly imports `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.
- Preserve every non-import line in `IssuePlanning/Loop.hs`: met. The target diff is import-only; the stricter `rg --pcre2` lookahead guard found only diff headers, with no body-line changes.
- Preserve `planningSystemErrorObservation` type/logic: met. The type still uses `Maybe AppServerTurn`, and no logic/body hunks changed.
- Do not touch protocol, facade, direct-owner client/transport/interpreter, turn classifier, package descriptors, docs, fixtures, runtime compatibility files, app code, tests, or other importers: met. Forbidden diff guards printed no paths.
- Do not create worker fan-out: met. `orchestrator/rounds/round-120/worker-plan.json` does not exist.
- Maintain roadmap lineage and review-stage state: met. State jq checks confirm roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, round `round-120`, `worker_mode: none`, and `merge_ready: false`.

### Decision
**APPROVED**

### Evidence
The integrated round result is limited to an import-only migration in `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`. The target file no longer imports the public `CodexWatcher.AppServerClient` compatibility facade and now imports `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)` directly. The `planningSystemErrorObservation` type and logic, planner app-server request/read behavior, and all other non-import code remain unchanged by diff inspection. Focused REPL coverage, full watcher-core tests, full build, whitespace checks, import scans, forbidden-surface guards, no-worker check, and review-stage state lineage checks all passed.
