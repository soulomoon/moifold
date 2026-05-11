### Changes Made

- `orchestrator/rounds/round-110/runner-guard-appserverclient-gate-evidence.md`: added artifact-only readiness evidence for the remaining `src/CodexWatcher/RunnerGuard.hs` `CodexWatcher.AppServerClient` importer, including direct-owner mapping, existing coverage inventory, gate matrix, and recommendation.
- `orchestrator/rounds/round-110/implementation-notes.md`: recorded this summary and final validation/changing-path evidence for reviewer reproduction.

### Tests

- No production code or tests were changed. Package build/test was skipped under the roadmap artifact-only rule because final changed-path evidence shows no production, test, package descriptor, runtime compatibility file, public API, fixture, docs, or behavior surface changed by this implementation.

### Notes

Recommendation: no, a later `RunnerGuard.hs` import-only split is not safe yet. The direct owner modules are clear, but focused RunnerGuard behavior coverage is missing for active app-server turn inspection and repair-launch request sequencing. The single first blocker is a focused `RunnerGuard active app-server turn inspection` test slice covering `thread/read`, materialization-pending, `threadSystemError`, latest-turn lookup, turn-completion classification, stale-threshold decisions, and formatted app-server failure details.

Final validation commands run:

```sh
git diff --check
git diff --cached --check
jq -e '.active_round_id == "round-110" and .stage == "implement" and .active_rounds[0].round_id == "round-110" and .active_rounds[0].worker_mode == "none"' orchestrator/state.json
test ! -e orchestrator/rounds/round-110/worker-plan.json
git diff --name-status
git diff -- orchestrator/rounds/round-110/plan.md orchestrator/rounds/round-110/runner-guard-appserverclient-gate-evidence.md orchestrator/rounds/round-110/implementation-notes.md
git diff -- src app test docs moifold.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github
git ls-files --others --exclude-standard orchestrator/rounds/round-110
git diff --no-index --check /dev/null orchestrator/rounds/round-110/runner-guard-appserverclient-gate-evidence.md; rc=$?; test $rc -eq 0 -o $rc -eq 1
git diff --no-index --check /dev/null orchestrator/rounds/round-110/implementation-notes.md; rc=$?; test $rc -eq 0 -o $rc -eq 1
```

Final changed-path evidence:

```text
M	orchestrator/state.json
??	orchestrator/rounds/round-110/
```

`orchestrator/state.json` was pre-existing controller-owned movement and was not edited by this implementation. Under `orchestrator/rounds/round-110/`, the untracked files are `selection.md`, `plan.md`, `runner-guard-appserverclient-gate-evidence.md`, and `implementation-notes.md`; the implementer-added files are the evidence artifact and these notes. The production/docs/package diff command produced no output.

Because the implementer-added files are untracked, `git diff --no-index --check` was also run against both new files. Both commands produced no whitespace warnings.
