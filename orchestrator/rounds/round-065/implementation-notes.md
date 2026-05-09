### Changes Made

- `orchestrator/rounds/round-065/repair-state-fixture-reader-policy.md`: added source-backed evidence for `repair-state.json` repair execute write order, compatibility rewrite ordering, repair summary fields, production-reader inventory, explicit current non-healthcheck policy, fixture gap, existing source-order test coverage, and blockers.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`: added a minimal round-065 pointer to the existing `repair-state.json` policy row while preserving `defer` and the remaining missing gates.

### Tests

- No production source, tests, fixtures, schemas, package files, scripts, roadmap files, or controller state were changed. Cabal/package baselines were skipped under the plan and verification contract because the diff is limited to round-local artifacts plus the allowed minimal policy-doc pointer.

### Commands Run

- `sed -n '1,260p' orchestrator/rounds/round-065/selection.md`
  - Result: pass. Confirmed selected direction `direction-014-repair-state-fixture-reader-policy`, evidence-only scope, and out-of-scope behavior changes.
- `sed -n '1,260p' orchestrator/project-contract.md`
  - Result: pass. Confirmed compatibility files keep current names and field meanings unless explicitly migrated, and cleanup proceeds from inventory to readiness evidence to policy before removal.
- `sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`
  - Result: pass. Confirmed runtime compatibility evidence must preserve repair behavior, healthcheck behavior or explicit non-healthcheck policy, write timing, fixture behavior, and operator recovery unless explicitly authorized.
- `sed -n '1,130p' src/CodexWatcher/Cli/Command/Replay.hs`
  - Result: pass. Confirmed execute order: archive invalid log, write repaired `events.jsonl`, write `repair-state.json`, rewrite compatibility files, then remove stale `block-state.json`; confirmed `writeRepairSummary` fields.
- `sed -n '1,220p' src/CodexWatcher/EventLogRepair.hs`
  - Result: pass. Confirmed `EventLogRepairPlan` data feeding summary fields: strategy, replay failure, inserted/dropped events, repaired events, and final replay state.
- `sed -n '220,320p' src/CodexWatcher/EventLogRepair.hs`
  - Result: pass. Confirmed repair reason includes failed event index, event name, and reason; confirmed repair-failure block-state helper is separate from `repair-state.json`.
- `sed -n '244,282p' src/CodexWatcher/Healthcheck.hs`
  - Result: pass. Confirmed `stateFileSpecs` does not include `repair-state.json` for issue planning, issue implementation, or PR review.
- `sed -n '1970,2010p' test/Main.hs`
  - Result: pass. Confirmed existing source-order test coverage for dry-run reporting and execute ordering; not fixture round-trip coverage.
- `rg -n "repair-state\\.json|repair state|repair-state|repairInvalidState|repair-invalid-state|writeRepairSummary|writeCompatibilityFiles|removeFileIfExists|issueImplementEventLogRepairCliPreservesDryRunAndExecuteContract" orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-064`
  - Result: pass. Refreshed prior evidence. Rounds 053, 055, and 057 recorded no checked-in `repair-state.json` fixture, no healthcheck/production reader, and `defer`; round 064 was planning-state-specific context.
- `find orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-064 -maxdepth 1 -type f -print`
  - Result: pass. Confirmed prior round artifact filenames for targeted evidence review.
- `sed -n '1,220p' docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  - Result: pass. Confirmed existing policy classified `repair-state.json` as `defer` and still listed explicit non-healthcheck policy as missing before this round.
- `find . -path './.git' -prune -o -name 'repair-state.json' -print`
  - Result: pass with no output. No checked-in `repair-state.json` fixture exists.
- `rg -n "repair-state\\.json|repair state|repair-state|repairInvalidState|repair-invalid-state|writeRepairSummary|writeCompatibilityFiles|removeFileIfExists|issueImplementEventLogRepairCliPreservesDryRunAndExecuteContract" src app test scripts docs golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-064`
  - Result: pass. Found writer in `src/CodexWatcher/Cli/Command/Replay.hs`, CLI dispatch in `app/Main.hs`, parser/command mentions, tests, docs/runbook policy context, and prior evidence. No production Haskell reader of `repair-state.json` was found.
- `rg -n "stateFileSpecs|sharedStateFiles|readStateFiles|blockedState|runtimeOwner|daemonState|issueState|watcherState|checkerState|agentState|reviewerState" src/CodexWatcher/Healthcheck.hs test/Main.hs docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-065`
  - Result: pass. Confirmed current healthcheck lists include daemon/block/runtime owner shared files, issue/planner state, and PR review state files, but not `repair-state.json`.
- `rg -n "repair-state\\.json|defer|non-healthcheck|healthcheck|fixture|external operator|downstream|removal|migration" docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-065`
  - Result before edit: pass. Confirmed policy row still classified `repair-state.json` as `defer` and listed missing healthcheck or explicit non-healthcheck policy.
- `git status --short`
  - Result: pass. Diff is limited to the allowed policy doc plus untracked round-065 artifacts. Existing untracked `selection.md` and `plan.md` were not modified.
- `git diff --name-only`
  - Result: pass. Tracked diff lists only `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`; new round-local artifacts are untracked.
- `git ls-files --others --exclude-standard orchestrator/rounds/round-065`
  - Result: pass. Untracked round-local files are `implementation-notes.md`, `plan.md`, `repair-state-fixture-reader-policy.md`, and `selection.md`; this implementation added only `implementation-notes.md` and `repair-state-fixture-reader-policy.md`.
- `git diff --check`
  - Result: pass with no output.
- `rg -n "[ \t]+$" orchestrator/rounds/round-065`
  - Result: pass with no output.
- `rg -n "repair-state\\.json|defer|non-healthcheck|healthcheck|fixture|external operator|downstream|removal|migration" docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-065`
  - Result after edit: pass. Confirmed policy still classifies `repair-state.json` as `defer`, includes the round-065 non-healthcheck pointer, and keeps fixture, production-reader, and external operator/downstream blockers.
- `git diff -- docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  - Result: pass. Confirmed the policy diff only updates the `repair-state.json` row.
- `sed -n '1,240p' orchestrator/rounds/round-065/repair-state-fixture-reader-policy.md`
  - Result: pass. Read back the round evidence artifact.
- `sed -n '1,220p' orchestrator/rounds/round-065/implementation-notes.md`
  - Result: pass. Read back these implementation notes.

### Notes

The diff intentionally does not change production behavior. `repair-state.json` remains `defer`; round 065 supplies explicit current non-healthcheck evidence only. It does not authorize cleanup, removal, migration, schema changes, timing changes, healthcheck surfacing, projection changes, repair behavior changes, fixture creation, or test changes.
