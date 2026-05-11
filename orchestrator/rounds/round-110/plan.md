### Goal

Produce artifact-only readiness and gate evidence for the remaining
`src/CodexWatcher/RunnerGuard.hs` `CodexWatcher.AppServerClient` importer
under `round-110-runner-guard-appserverclient-gate-evidence`.

The implementation should write
`orchestrator/rounds/round-110/runner-guard-appserverclient-gate-evidence.md`.
It may also write `orchestrator/rounds/round-110/implementation-notes.md` only
if useful for bulky command output or changed-path evidence. This round must
not change production code, tests, package descriptors, fixtures, docs,
roadmap files, `orchestrator/state.json`, `selection.md`, public APIs,
app-server protocol, endpoint parsing, session behavior, timeout/fallback
behavior, command rendering, failure formatting, Cabal exposure, or any import
list.

The artifact must give a final yes/no recommendation on whether a later
`RunnerGuard.hs` import-only split from `CodexWatcher.AppServerClient` to
direct owner modules is safe now. If the answer is no, it must name the single
focused RunnerGuard behavior test slice that must land first.

### Approach

Use the active selection, roadmap, and project contract as coordination inputs,
then generate fresh evidence from the live worktree. The evidence is narrowly
about `RunnerGuard.hs`: map every currently imported AppServerClient symbol to
its direct owner module, inspect existing RunnerGuard behavior/test coverage,
and decide whether each selected behavior gate is already protected.

The direct-owner mapping should distinguish symbols owned by
`CodexWatcher.Workflow.Agent.Codex.Client` from symbols owned by
`CodexWatcher.Workflow.Agent.Codex.Transport`. The artifact must cover these
RunnerGuard gates explicitly:

- repair-thread launch;
- `thread-name/set`;
- `turn/start`;
- request id progression;
- active-thread read;
- thread-read materialization pending;
- `threadSystemError`;
- latest-turn lookup;
- turn-completion classification;
- stale-turn decisions;
- `formatAppServerClientFailure` text.

Do not create `worker-plan.json`. This is one serial evidence artifact with no
non-overlapping implementation ownership. Worker fan-out is not justified.

### Steps

1. Re-read coordination inputs:
   ```sh
   sed -n '1,220p' orchestrator/rounds/round-110/selection.md
   sed -n '1,220p' orchestrator/project-contract.md
   sed -n '1,140p' orchestrator/state.json
   sed -n '760,930p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md
   sed -n '1,220p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md
   sed -n '1,260p' orchestrator/rounds/round-105/appserverclient-import-convergence-readiness.md
   ```
   Record that this round is artifact-only and that
   `CodexWatcher.AppServerClient` remains a public compatibility facade.

2. Record starting worktree scope:
   ```sh
   git status --short
   git diff --name-status
   git ls-files --others --exclude-standard orchestrator/rounds/round-110
   ```
   Treat pre-existing controller-owned `orchestrator/state.json` movement as
   outside implementer ownership and leave it untouched.

3. Confirm the compatibility facade and direct owner exports:
   ```sh
   sed -n '1,120p' src/CodexWatcher/AppServerClient.hs
   sed -n '1,260p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs
   sed -n '1,260p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs
   rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport)|exposed-modules:' \
     moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal
   ```
   In the artifact, list the direct owner for every `RunnerGuard.hs`
   AppServerClient symbol currently in use.

4. Run the current import and symbol-use mapping for `RunnerGuard.hs`:
   ```sh
   rg -n '^import[[:space:]]+CodexWatcher\.AppServerClient|AppServerEndpoint|AppServerTurn|defaultAppServerClientOptions|formatAppServerClientFailure|latestTurnById|parseThreadReadTurns|parseTurnStartTurnId|sendOneAppServerRequest|startThreadWithEndpoint|threadReadMaterializationPending|threadSystemError' \
     src/CodexWatcher/RunnerGuard.hs
   ```
   Then read the relevant source ranges:
   ```sh
   sed -n '1,260p' src/CodexWatcher/RunnerGuard.hs
   sed -n '260,620p' src/CodexWatcher/RunnerGuard.hs
   ```
   The evidence must map each imported symbol to concrete use sites and to the
   behavior gates it participates in.

5. Run a repo-wide cross-check that `RunnerGuard.hs` is the only subject of
   this evidence and that the round does not accidentally broaden scope:
   ```sh
   rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' \
     src app test agent-workflow-core agent-workflow-codex agent-workflow-github
   rg -n 'RunnerGuard|runner guard|runner-guard|repair thread|thread-name/set|turn/start|stale|materialization|formatAppServerClientFailure|latestTurnById|threadSystemError' \
     src test docs orchestrator/rounds/round-105
   ```
   Record full context only for `RunnerGuard.hs` and focused tests/evidence
   that protect its behavior; other importers remain out of scope.

6. Discover existing RunnerGuard behavior and test coverage:
   ```sh
   rg -n 'RunnerGuard|runner guard|runner-guard|runRunnerGuard|repair|stale|thread-name/set|turn/start|materialization|threadSystemError|latestTurnById|formatAppServerClientFailure' \
     test src
   rg -n 'describe|it|testCase|assert|shouldBe|shouldContain|shouldSatisfy|golden|fixture|AppServerTurn|parseThreadReadTurns|parseTurnStartTurnId' \
     test
   ```
   If matching tests are in a large file, read only the local ranges needed to
   inventory assertions. The artifact must say which gates have direct
   assertions, which have only incidental coverage, and which are uncovered.

7. Build the gate matrix in the evidence artifact. For each required gate,
   include:
   - `RunnerGuard.hs` function/use-site evidence;
   - AppServerClient symbol(s) involved;
   - direct owner module(s);
   - existing test or artifact coverage, with file names and assertion shape;
   - current status: `covered`, `incidental`, or `missing`;
   - risk if a later import-only split happens before more coverage.

8. Decide the recommendation:
   - Answer `yes` only if every selected gate is covered by focused behavior
     assertions and a later split would be a mechanical import-list change.
   - Answer `no` if any gate is missing or only incidental. Name the focused
     behavior test that must land first, preferably as one small
     `RunnerGuard` test covering the highest-risk uncovered path rather than a
     broad app-server rewrite.
   - State explicitly that this recommendation does not approve migration,
     public deprecation, Cabal exposure removal, facade removal, behavior
     change, release/publication, milestone completion, or terminal completion.

9. Write
   `orchestrator/rounds/round-110/runner-guard-appserverclient-gate-evidence.md`
   with these sections:
   - `Scope`
   - `Inputs Reviewed`
   - `Commands Run`
   - `RunnerGuard Import And Symbol Map`
   - `Direct Owner Map`
   - `Existing Behavior Coverage`
   - `Gate Matrix`
   - `Recommendation`
   - `Changed-Path Evidence`

10. Do not write `orchestrator/rounds/round-110/worker-plan.json`:
    ```sh
    test ! -e orchestrator/rounds/round-110/worker-plan.json
    ```

### Verification

Run artifact-only validation:

```sh
git diff --check
git diff --cached --check
jq -e '.active_round_id == "round-110" and .stage == "plan" and .active_rounds[0].round_id == "round-110" and .active_rounds[0].worker_mode == "none"' orchestrator/state.json
test ! -e orchestrator/rounds/round-110/worker-plan.json
git diff --name-status
git diff -- orchestrator/rounds/round-110/plan.md \
  orchestrator/rounds/round-110/runner-guard-appserverclient-gate-evidence.md \
  orchestrator/rounds/round-110/implementation-notes.md
git diff -- src app test docs moifold.cabal cabal.project \
  agent-workflow-core agent-workflow-codex agent-workflow-github
```

Build and test may be skipped only if the changed-path evidence proves this
round changed no production code, test code, package descriptor, runtime
compatibility file, public API, fixture, docs, or behavior surface. If any
non-artifact path changes, stop and require the relevant gates for the touched
surface, at minimum `cabal test watcher-core-test`, `cabal build all`, and any
focused RunnerGuard/app-server behavior tests covering the changed path.

Changed-path proof expected for a successful artifact-only implementation:
only `orchestrator/rounds/round-110/plan.md`,
`orchestrator/rounds/round-110/runner-guard-appserverclient-gate-evidence.md`,
and optionally `orchestrator/rounds/round-110/implementation-notes.md` are
new or modified by the implementer, apart from pre-existing controller-owned
`orchestrator/state.json`.
