### Goal

Refresh the highest-value cleanup inventory for
`round-083-cleanup-inventory-refresh` as a round-local evidence artifact only.
The round should give later test-topology, fixture, import-convergence, and
module-split slices a current map of compatibility facades, runtime
compatibility files, oversized test/helper clusters, large behavior modules,
policy references, and downstream/operator inventory scope.

### Approach

Keep the work sequential and artifact-only. The implementer should inspect the
active roadmap and current source tree, run focused read-only scans, and write
one implementation evidence artifact:
`orchestrator/rounds/round-083/cleanup-inventory.md`. The usual
`orchestrator/rounds/round-083/implementation-notes.md` should record commands,
results, changed-path evidence, and the artifact-only baseline rationale.

Do not edit production code, test code, Cabal files, docs, fixtures, roadmap
files, `orchestrator/state.json`, review artifacts, merge artifacts, or runtime
compatibility files. Do not classify any surface as deprecated, removable, or
migrated; record current evidence, blockers, and follow-up gates only.

### Steps

1. Re-read the control-plane inputs and record their identities in the
   implementation notes: `orchestrator/state.json`,
   `orchestrator/project-contract.md`,
   `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`,
   `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`,
   and `orchestrator/rounds/round-083/selection.md`.
2. Create `orchestrator/rounds/round-083/cleanup-inventory.md` with sections
   for scope, roadmap lineage, non-goals, compatibility facade inventory,
   runtime compatibility-file inventory, test topology and helper clusters,
   large behavior-module inventory, fixture coverage, policy references,
   downstream/operator scope, follow-up gates, and artifact-only validation.
3. Inventory compatibility facades named by the project contract and active
   verification bundle: `CodexWatcher.AppServerClient`,
   `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and
   `CodexWatcher.Workflow.Permission`. For each facade, record the facade file,
   replacement owner modules where visible from source, Cabal exposure status,
   current import count, import locations grouped by `src`, `app`, `test`,
   package candidates, docs, and orchestrator evidence, and whether the surface
   is pure reexport or mixed moifold bridge. Use read-only scans such as:
   `rg -n "import CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)" src app test agent-workflow-* *.cabal docs orchestrator`.
4. Inventory runtime compatibility files named by the roadmap and contract:
   `planner-state.json`, `planning-state.json`, `daemon-state.json`,
   `block-state.json`, `repair-state.json`, `runtime-owner.json`, checked-in
   compatibility snapshots, and live `issue-snapshot.json`. For each path,
   separate production producers, production readers, healthcheck readers,
   repair/replay readers, tests, fixtures, docs, scripts, and prior round
   evidence. Use focused scans over `src`, `app`, `test`, `scripts`, `docs`,
   `golden`, `examples`, and `orchestrator/rounds`.
5. Count oversized test and helper clusters without editing them. Record the
   current line count for `test/Main.hs`, nearby focused test modules, and any
   obvious reusable package-boundary or facade-policy helper clusters that
   later rounds could extract. Use commands such as `wc -l test/Main.hs
   test/*.hs` and line-numbered `rg` scans for boundary-policy, facade,
   import-policy, package-boundary, workflow behavior, fixture, and
   compatibility-state test groups.
6. Count large behavior modules named by the active roadmap:
   `src/CodexWatcher/Daemon.hs`,
   `src/CodexWatcher/Workflow/DocsMigration.hs`,
   `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`,
   `src/CodexWatcher/EventLog/Types.hs`, and
   `src/CodexWatcher/TurnOutput.hs`. Record line counts, broad ownership,
   obvious test anchors, and any import-cycle or behavior-risk notes visible
   from read-only scans. Do not propose concrete module splits beyond
   inventory follow-up gates.
7. Record fixture coverage and gaps for the runtime compatibility-file
   surfaces. Distinguish checked-in golden or fixture files from tests that
   only assert generated writes in memory. Include old/current JSON shape,
   replay, healthcheck, repair, write-timing, and operator evidence as
   present, missing, or out of scope for this round.
8. Record policy and prior-hold references without changing them. Include the
   active project-contract invariants, active roadmap verification checks, the
   prior terminal-hold context as non-removal evidence, and any current policy
   rows or prior round artifacts that later implementers must respect.
9. Record downstream/operator inventory scope from available local evidence
   only: repo-local scripts, runbooks, docs, Cabal descriptors, public package
   candidates, golden configs, and prior round evidence. If external
   downstream repositories, live state archives, hosted CI, release/upload
   evidence, or operator approvals are not inspected, state that explicitly as
   a blocker or unknown rather than treating local absence as approval.
10. Summarize follow-up gates for later roadmap slices. Keep them phrased as
    evidence needed for test splits, fixture additions, import convergence,
    large-module decomposition, policy decisions, or exact deprecation/removal
    gates. Do not select or implement those later slices.
11. Write `orchestrator/rounds/round-083/implementation-notes.md` with the
    exact commands run, their pass/fail results, the artifacts written, and a
    reviewer-recorded artifact-only rationale explaining why package build/test
    baselines may be skipped if changed paths remain limited to
    `orchestrator/rounds/round-083/cleanup-inventory.md` and
    `orchestrator/rounds/round-083/implementation-notes.md`.

### Verification

Run artifact-only validation after writing the implementation artifacts:

```sh
git status --short
git diff --name-only
git diff --check
rg -n "deprecat|remov|migrat|delete|rename|approval|Cabal exposure" orchestrator/rounds/round-083/cleanup-inventory.md orchestrator/rounds/round-083/implementation-notes.md
```

The reviewer should require changed-path evidence showing only round-083
orchestrator artifacts changed. If any production code, test code, package
descriptor, docs, fixture, roadmap, state, runtime compatibility file, public
API, or behavior surface changes, the artifact-only skip no longer applies and
the implementation must either revert those out-of-scope changes or run the
baseline package checks from the active verification bundle:

```sh
cabal build all
cabal test watcher-core-test
```

If staging occurs, also run:

```sh
git diff --cached --check
```

Baseline package build/test may be skipped only when
`implementation-notes.md` records the artifact-only rationale and the reviewer
confirms the changed paths are limited to the round-local inventory artifacts.

### Worker Fan-Out

No worker fan-out is used. This is a serial artifact-only inventory round, and
the active state has `max_parallel_rounds: 1`; splitting the inventory before it
defines disjoint ownership would add coordination risk without implementation
benefit.
