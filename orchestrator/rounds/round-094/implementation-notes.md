### Changes Made
- `golden/runtime-compatibility/runtime-owner/current-lease/runtime-owner.json`: added the checked-in current runtime-owner lease fixture with top-level `lease` and nested `runtime`, `pid`, `hostname`, `claimedAt`, `expiresAt`, and `eventLogHeadHash` fields.
- `test/RuntimeCompatibilityFixtureSpec.hs`: extended the runtime compatibility fixture suite with runtime-owner fixture decoding, exact `runtimeLeaseJson fixtureRuntimeLease` equality, top-level legacy-field rejection, nested lease-field assertions, `readRuntimeOwnerMarker` / `readRuntimeOwner` fixture-reader coverage, and source-boundary checks for healthcheck and `scripts/restart-watcher`.
- `orchestrator/rounds/round-094/implementation-notes.md`: recorded this implementation and verification evidence.

### Tests
- `test/RuntimeCompatibilityFixtureSpec.hs`: verifies the runtime-owner fixture is the current lease shape, keeps legacy fields out of the top level, preserves the nested lease field paths and values, is accepted by runtime-owner readers, and preserves the current healthcheck/restart-script source contracts.

Verification commands and results:
- `git status --short --untracked-files=all`: exited 0 before edits; showed pre-existing `M orchestrator/state.json` and untracked `orchestrator/rounds/round-094/plan.md` / `selection.md`.
- `python3 -m json.tool orchestrator/state.json`: exited 0; state selected `round-094-runtime-owner-compatibility-fixtures` on branch `orchestrator/round-094-highest-value-cleanup-slice`.
- `sed -n '1,220p' orchestrator/rounds/round-094/selection.md`: exited 0; confirmed runtime-owner compatibility fixture scope and controller/roadmap exclusions.
- `sed -n '1,280p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`: exited 0; confirmed baseline `cabal build all`, `cabal test watcher-core-test`, and diff checks.
- `sed -n '1,240p' orchestrator/project-contract.md`: exited 0; confirmed compatibility-file names and meanings remain stable until explicit migration/removal gates.
- `sed -n '1,170p' orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`: exited 0; confirmed `runtime-owner.json` fixture gap and current healthcheck/script blockers.
- `sed -n '1,140p' orchestrator/rounds/round-089/plan.md`: exited 0; confirmed current healthcheck field-path contract from the previous slice.
- `rg -n "runtime-owner\\.json|runtimeOwner|runtimeLeaseJson|readRuntimeOwner|readRuntimeOwnerMarker|writeRuntimeLease|read_runtime_owner_pid|stateFileSpecs" src app test docs scripts golden -g '!dist-newstyle/**'`: exited 0; confirmed current producer, reader, healthcheck, and restart-script surfaces before editing.
- `find golden/runtime-compatibility/runtime-owner -type f | sort`: exited 0; printed `golden/runtime-compatibility/runtime-owner/current-lease/runtime-owner.json`.
- `python3 -m json.tool golden/runtime-compatibility/runtime-owner/current-lease/runtime-owner.json`: exited 0; fixture is valid JSON with top-level `lease`.
- `rg -n "runtime-owner\\.json|runtimeOwner|runtimeLeaseJson|readRuntimeOwnerMarker|readRuntimeOwner|read_runtime_owner_pid|RuntimeCompatibilityFixtureSpec|runtimeCompatibilityFixtureTests|stateFileSpecs" golden test src app scripts docs -g '!dist-newstyle/**'`: exited 0; confirmed the fixture/test/source-boundary references.
- `cabal test watcher-core-test`: exited 0; test suite passed, including the new runtime-owner fixture and source-boundary assertions.
- `git diff --check`: exited 0; no whitespace errors.
- `cabal build all`: exited 0; built the `moifold` executable successfully after the test build.
- `git status --short --untracked-files=all`: exited 0 during verification; showed the pre-existing controller files plus this round's fixture/test changes. A final status should also include this implementation-notes file.

### Notes
No production runtime-owner producer, parser internals, healthcheck behavior, restart-script behavior, repair behavior, schema, filename, Cabal wiring, roadmap file, or controller state was changed. No staging occurred, so `git diff --cached --check` was not applicable.
