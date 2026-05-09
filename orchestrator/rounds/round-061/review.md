### Checks Run
- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`
  Result: pass; reviewer contract requires integrated round review, baseline/task checks, `review.md`, and `review-record.json`.
- Command: `sed -n '1,240p' orchestrator/state.json`
  Result: pass; active round is `round-061`, stage `review`, roadmap `2026-05-09-01-compatibility-surface-cleanup` revision `rev-002`, selected item `round-061-app-server-client-migration-readiness`.
- Command: `sed -n '1,240p' orchestrator/rounds/round-061/selection.md`
  Result: pass; selection matches milestone `milestone-005-import-facade-follow-up-evidence`, direction `direction-010-app-server-client-migration-readiness`, and extracted item `round-061-app-server-client-migration-readiness`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-061/plan.md`
  Result: pass; plan requires evidence-only AppServerClient migration-readiness artifact, refreshed import count, grouping, package exposure readback, behavior coverage readback, no worker fan-out, and diff limited to round-local artifacts.
- Command: `sed -n '1,280p' orchestrator/rounds/round-061/app-server-client-migration-readiness.md`
  Result: pass; artifact records evidence-only scope, refreshed import inventory, broader reference classification, replacement implementation shape, and ownership grouping.
- Command: `sed -n '240,520p' orchestrator/rounds/round-061/app-server-client-migration-readiness.md`
  Result: pass; artifact records behavior coverage readback, readiness, and blockers without approving migration, deprecation, Cabal exposure changes, or removal.
- Command: `sed -n '1,260p' orchestrator/rounds/round-061/implementation-notes.md`
  Result: pass; implementation notes record the evidence artifact, exact scans, count `28`, artifact-only diff scope, and skipped Cabal/package baselines under the artifact-only allowance.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass; relevant contracts are package/module boundaries, public compatibility facade availability, dry-run request rendering, action ordering, request-id progression, and baseline anchors.
- Command: `sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`
  Result: pass; verification bundle allows Cabal/package baselines to be skipped only when diff is limited to roadmap and round-local orchestrator artifacts, and requires import-facade evidence checks for `CodexWatcher.AppServerClient`.
- Command: `git diff --name-only`
  Result: pass; no tracked-file diff output before review artifacts were written.
- Command: `git status --short`
  Result: pass; visible change was `?? orchestrator/rounds/round-061/` before review artifacts were written.
- Command: `git diff --check`
  Result: pass; no tracked whitespace errors.
- Command: `git ls-files --others --exclude-standard orchestrator/rounds/round-061`
  Result: pass; untracked files before review were limited to `orchestrator/rounds/round-061/app-server-client-migration-readiness.md`, `orchestrator/rounds/round-061/implementation-notes.md`, `orchestrator/rounds/round-061/plan.md`, and `orchestrator/rounds/round-061/selection.md`.
- Command: `test ! -e orchestrator/rounds/round-061/worker-plan.json && printf 'no worker-plan.json\n'`
  Result: pass; no worker fan-out artifact exists.
- Command: `rg -n '^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal`
  Result: pass; scan found the selected-facade imports listed in the evidence artifact across source and tests.
- Command: `rg -l '^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | wc -l`
  Result: pass; output was `28`.
- Command: `rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Protocol)' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src test app`
  Result: pass; broader scan found facade imports, replacement-module references, documentation/policy references, exposure assertions, and no selected-facade imports in standalone package candidates or examples.
- Command: `rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Protocol)' moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal`
  Result: pass; `moifold.cabal:33` exposes `CodexWatcher.AppServerClient`; `agent-workflow-codex/agent-workflow-codex.cabal:50`, `:52`, and `:53` expose `Client`, `Protocol`, and `Transport`.
- Command: `rg -n "workflowMoifoldCabalLibraryDoesNotReexportAdapters|workflowAgentCodexStartRequestsMatchCompiledEffects|workflowAgentCodexStartsThreadsThroughTypedAdapter|workflowAgentCodexParsesTurnLifecycle|request-id|RequestId|appServerRequestSession|startThreadWithInterpreter|materialization|mismatched|JsonRpcError|unsupported" test/AppServerSpec.hs test/Main.hs`
  Result: pass; behavior coverage names and request-id/session/parser/fallback/error evidence are present in the current tests.
- Command: `sed -n '1,120p' src/CodexWatcher/AppServerClient.hs && sed -n '1,80p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs && sed -n '1,90p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs && sed -n '1,60p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Protocol.hs`
  Result: pass; facade reexports client and transport, while replacement modules own parser/failure, transport/session, and protocol mapping surfaces.
- Command: `jq -e . orchestrator/rounds/round-061/review-record.json`
  Result: pass; review record is valid JSON.
- Command: `git status --porcelain=v1 --untracked-files=all`
  Result: pass; final visible changes are limited to untracked files under `orchestrator/rounds/round-061/`: `app-server-client-migration-readiness.md`, `implementation-notes.md`, `plan.md`, `review-record.json`, `review.md`, and `selection.md`.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors and no staged changes.
- Command: `perl -ne 'if (/[ \t]$/) { print "$ARGV:$.: trailing whitespace\n"; $bad = 1 } END { exit($bad // 0) }' orchestrator/rounds/round-061/*.md orchestrator/rounds/round-061/*.json`
  Result: pass; no trailing whitespace in round-local markdown or JSON artifacts, including untracked review outputs.

### Plan Compliance
- Create `orchestrator/rounds/round-061/app-server-client-migration-readiness.md`: met; artifact exists and is readable.
- Refresh selected-facade import inventory: met; reviewer reran the anchored scan and count, confirming `28`.
- Add broader reference scan: met; reviewer reran the broader scan and found usage, docs/policy, exposure, and replacement-module evidence.
- Group current import callers by ownership: met; artifact groups callers into client/parser, transport/session, protocol/request, and product-policy buckets with symbols or behaviors.
- Read back facade and replacement implementation shape: met; artifact records facade reexports and replacement module ownership, and reviewer read current modules directly.
- Prove replacement module exposure without Cabal edits: met; `moifold.cabal` still exposes `CodexWatcher.AppServerClient`, and `agent-workflow-codex.cabal` exposes `Client`, `Protocol`, and `Transport`.
- Read back current behavior coverage: met; artifact covers AppServerSpec, package-boundary tests, typed adapter tests, request-id progression, and dry-run/action-ordering evidence; reviewer verified the referenced test names and symbols.
- Record dry-run migration readiness and blockers: met; artifact says readiness is partial and explicitly leaves import migration, downstream/operator confirmation, deprecation, Cabal exposure changes, and removal blocked.
- Keep diff limited to round evidence and implementation notes: met under the artifact-only allowance; before review files, visible changes were untracked files only under `orchestrator/rounds/round-061/`. No production source, tests, package descriptors, public docs outside the round, scripts, runtime compatibility files, `orchestrator/project-contract.md`, `orchestrator/state.json`, roadmap files, or worker-plan artifact were changed.
- Worker fan-out: met; no `orchestrator/rounds/round-061/worker-plan.json` exists.

### Decision
**APPROVED**

### Evidence
The integrated round result satisfies the evidence-only plan. The reviewer reran the selected-facade scan and confirmed the refreshed count is `28`. The broader reference and package exposure scans support the artifact's grouping/readiness claims: the compatibility facade remains exposed from `moifold.cabal`, replacement modules are exposed from `agent-workflow-codex`, current callers are grouped by parser/client, transport/session, protocol/request, and product-policy ownership, and downstream/operator sources outside this checkout are correctly recorded as unavailable rather than as removal approval.

The visible diff before review artifacts was limited to round-local orchestrator artifacts under `orchestrator/rounds/round-061/`, so the verification bundle's artifact-only baseline allowance applies. Full Cabal/package baselines were not required for this review because no production source, tests, Cabal descriptors, policy docs outside the round, fixtures, scripts, runtime compatibility files, project contract, state file, roadmap files, or import surfaces changed.

Whitespace checks passed for tracked diffs via `git diff --check`, staged diffs via `git diff --cached --check`, and untracked round-local artifacts via the trailing-whitespace scan.
