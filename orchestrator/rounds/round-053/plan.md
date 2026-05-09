### Goal

Produce a source-backed runtime compatibility-file inventory for the selected
surfaces:

- `issue-state.json`
- `daemon-state.json`
- `planning-state.json`
- PR URL/state files
- block state
- repair state
- runtime owner files
- compatibility snapshots

The round should leave a reviewable evidence report, not production behavior
changes. It should identify current producers, consumers, repair and
healthcheck use, old-log and golden fixture assumptions, write-timing
observations, protecting tests, and unresolved unknowns for each surface.

### Approach

Keep the work sequential and evidence-only. Write the inventory as a
round-local artifact, for example
`orchestrator/rounds/round-053/runtime-compatibility-file-inventory.md`, so it
is reviewable without changing production source, roadmap state, policy docs,
runtime file names, schemas, field meanings, write behavior, deprecation
status, or cleanup candidate approval.

Use recursive scans plus direct inspection of the matched modules, tests,
fixtures, scripts, and docs. Treat `orchestrator/project-contract.md` as the
shared compatibility contract: runtime compatibility files keep their current
names and meanings unless a later selected migration/removal round proves and
authorizes a change. Round 052 is prior context only; do not add
import-facade follow-up work to this round.

### Steps

1. Re-read `orchestrator/rounds/round-053/selection.md`,
   `orchestrator/project-contract.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/roadmap.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/verification.md`,
   and `orchestrator/rounds/round-052/import-facade-inventory.md` before
   writing the report.
2. Run recursive filename and text scans for the selected runtime surfaces
   across source, app code, tests, scripts, docs, examples, fixtures, golden
   logs, snapshots, and orchestrator round evidence. Include at least these
   scan shapes in the report evidence:
   - `find . -name 'issue-state.json' -o -name 'daemon-state.json' -o -name 'planning-state.json' -o -name '*pr-url*' -o -name '*pr-state*' -o -name '*block*state*' -o -name '*repair*state*' -o -name '*owner*' -o -name '*snapshot*'`
   - `rg -n "issue-state\\.json|daemon-state\\.json|planning-state\\.json|pr-url|pr state|PR URL|block state|blocked|repair state|runtime owner|owner file|compatibility snapshot|snapshot" src app test scripts docs examples orchestrator`
   - `rg -n "writeFile|atomicWrite|encodeFile|decodeFile|eitherDecode|readFile|doesFileExist|renameFile|copyFile" src test scripts`
3. For each selected surface, group current producers and consumers by
   location: production source, CLI/app entrypoints, daemon/runtime paths,
   healthcheck, repair, tests, scripts/runbooks, docs, golden fixtures,
   snapshots, and old orchestrator or watcher logs.
4. For each write site, record what triggers the write, the path used, whether
   the write appears primary or compatibility-only, and any observable ordering
   or timing relationship with event logs, daemon startup/shutdown, issue/PR
   lifecycle transitions, repair, or healthcheck.
5. For each read site, record whether it is authoritative runtime input,
   compatibility fallback, diagnostic/healthcheck input, repair input,
   fixture/golden replay input, or docs/runbook reference. Do not infer safe
   removal from a read being diagnostic; record the evidence and any unknowns.
6. Inspect healthcheck and repair paths directly after the scans. Name every
   selected surface that healthcheck or repair reads, writes, rewrites,
   reconstructs, verifies, or reports, and record surfaces with no observed
   healthcheck/repair coverage as unknowns.
7. Inspect golden fixtures, replay tests, old-log fixtures, snapshot fixtures,
   and compatibility fixture docs for assumptions about the selected file
   names, fields, location, and timing. Include the fixture paths or test names
   that make the assumption visible.
8. Identify protecting tests by inspecting the relevant assertions in
   `test/Main.hs` and focused specs such as runtime, healthcheck, repair,
   issue-planning, issue-implementation, PR-review, CLI, and golden/replay
   tests. The report should name the behavior protected, not just the file.
9. Record unknowns explicitly. Unknowns may include ambiguous ownership,
   uncertain external operator dependence, old logs without local fixtures,
   write timing that is only indirectly tested, compatibility snapshots whose
   producer is unclear, or tests that prove file existence but not old-state
   compatibility.
10. Keep the report descriptive. Do not rename files, change fields, migrate
    schemas, alter compatibility writes, delete snapshots, add deprecation
    wording, update policy docs, or classify any selected surface as approved
    for cleanup.

### Verification

- Run the scan commands from Step 2 and include summarized results or exact
  representative excerpts in
  `orchestrator/rounds/round-053/runtime-compatibility-file-inventory.md`.
- Run focused source/test lookups for healthcheck and repair references and
  cite the exact files inspected in the report.
- Run focused source/test lookups for old-log, golden, and snapshot fixtures
  and cite the exact files inspected in the report.
- Run `cabal test watcher-core-test` to preserve current replay, golden,
  healthcheck, repair, runtime-owner, and compatibility-file behavior while
  adding only the inventory artifact.
- Run `git diff --check`.
- If staging happens later, run `git diff --cached --check`.
- The final diff for this round should contain only
  `orchestrator/rounds/round-053/plan.md` and the implementer's eventual
  round-local inventory/evidence artifact. It should not change production
  code, tests, roadmap files, `orchestrator/state.json`, implementation notes,
  reviews, merge notes, policy docs, compatibility files, or snapshots.

### Worker Fan-Out

Worker fan-out is not used. The selected runtime surfaces share healthcheck,
repair, old-log, golden, and write-timing evidence, and a single sequential
inventory avoids splitting coupled compatibility assumptions across workers.
