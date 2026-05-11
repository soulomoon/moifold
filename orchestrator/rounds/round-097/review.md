### Checks Run

- Command: `sed -n '1,220p' orchestrator/roles/reviewer.md`; `sed -n '1,220p' orchestrator/state.json`; `sed -n '1,220p' orchestrator/rounds/round-097/selection.md`; `sed -n '1,280p' orchestrator/rounds/round-097/plan.md`
  Result: pass. Reviewer role, active state, selection, and plan still point at `round-097-facade-import-scan-refresh` under roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`.

- Command: `rg -n "Core\\.Ids|GitHub-only|agent-only|combined|BoundaryPolicySpec|ReviewThreadId|substring|stale|retry|Review" orchestrator/rounds/round-097/facade-import-scan-refresh.md orchestrator/rounds/round-097/implementation-notes.md`; `sed -n '190,285p' orchestrator/rounds/round-097/facade-import-scan-refresh.md`; `sed -n '1,180p' orchestrator/rounds/round-097/implementation-notes.md`
  Result: pass. The corrected artifact records `3 GitHub-only`, `2 agent-only`, and `39 combined` `Core.Ids` users, lists `test/BoundaryPolicySpec.hs` under GitHub-only safe direct-owner candidates, and records the `ReviewThreadId` substring pitfall in retry notes.

- Command: `rg -n "^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)([[:space:]]|$|\\()" src app test agent-workflow-core agent-workflow-codex agent-workflow-github | sed -E 's#^([^:]+):[0-9]+:import (qualified )?(CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)).*#\\1 \\3#' | awk '{dir=$1; sub("/.*","",dir); mod=$2; total[mod]++; by[mod,dir]++} END {for (mod in total) {line=mod " " total[mod]; for (key in by) {split(key,a,SUBSEP); if (a[1]==mod) line=line " " a[2] "=" by[key]} print line}}' | sort`
  Result: pass. Current selected-facade import counts match the artifact: `AppServerClient 19 src=12 test=7`, `Core.Ids 44 src=31 app=1 test=12`, `Workflow.EventLog 10 src=2 test=8`, and `Workflow.Permission 7 test=7`.

- Command: `github_only=0; agent_only=0; both=0; none=0; while IFS= read -r f; do agent=$(rg -o "\\b(RequestId|ThreadId|TurnId|nextRequestId|unThreadId|unTurnId)\\b" "$f" | wc -l | tr -d ' '); github=$(rg -o "\\b(RepoName|IssueNumber|PrNumber|BranchName|ReviewThreadId|CommitSha)\\b" "$f" | wc -l | tr -d ' '); if [ "$agent" -gt 0 ] && [ "$github" -gt 0 ]; then cls=both; both=$((both+1)); elif [ "$agent" -gt 0 ]; then cls=agent-only; agent_only=$((agent_only+1)); elif [ "$github" -gt 0 ]; then cls=github-only; github_only=$((github_only+1)); else cls=none; none=$((none+1)); fi; printf "%s agent=%s github=%s %s\\n" "$f" "$agent" "$github" "$cls"; done < <(rg -l "^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\\.Core\\.Ids([[:space:]]|$|\\()" src app test | sort); printf "TOTAL github-only=%s agent-only=%s both=%s none=%s\\n" "$github_only" "$agent_only" "$both" "$none"`
  Result: pass. Exact-token scan reports `TOTAL github-only=3 agent-only=2 both=39 none=0`. `test/BoundaryPolicySpec.hs agent=0 github=6 github-only`.

- Command: `rg -n "\\b(RequestId|ThreadId|TurnId|nextRequestId|unThreadId|unTurnId)\\b|\\b(RepoName|IssueNumber|PrNumber|BranchName|ReviewThreadId|CommitSha)\\b" test/BoundaryPolicySpec.hs`
  Result: pass. Targeted scan found only GitHub-domain tokens in `test/BoundaryPolicySpec.hs`: `RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, and `ReviewThreadId`.

- Command: `rg -n "40 combined|2 GitHub-only|BoundaryPolicySpec.*(combined|blocked)|combined.*BoundaryPolicySpec|blocked.*BoundaryPolicySpec" orchestrator/rounds/round-097/facade-import-scan-refresh.md orchestrator/rounds/round-097/implementation-notes.md`
  Result: pass. Exit code 1 with no output; no stale incorrect `BoundaryPolicySpec` combined/blocker classification or stale totals remain.

- Command: `rg -n "3 GitHub-only|2 agent-only|39 combined|BoundaryPolicySpec" orchestrator/rounds/round-097/facade-import-scan-refresh.md orchestrator/rounds/round-097/implementation-notes.md`
  Result: pass. Corrected totals and `BoundaryPolicySpec` retry evidence are present in the inventory and implementation notes.

- Command: `rg -n "exposed-modules:|CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)|CodexWatcher\\.Workflow\\.(Agent\\.Codex|Agent\\.Ids|GitHub\\.Ids|EventLog\\.|Permission\\.Core)" moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal cabal.project`
  Result: pass. `moifold.cabal` still exposes the four selected compatibility facades; standalone package descriptors expose direct owner modules.

- Command: `rg -n "^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)([[:space:]]|$|\\()" agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass. Exit code 1 with no output; no selected-facade imports are present in standalone package candidates.

- Command: `git status --short --untracked-files=all && git diff --name-only && git ls-files --others --exclude-standard orchestrator/rounds/round-097 | sort`
  Result: pass for scope evidence. The tracked diff remains `orchestrator/state.json`; round-local untracked artifacts are `facade-import-scan-refresh.md`, `implementation-notes.md`, `plan.md`, `selection.md`, `review.md`, and `review-record.json`. No production code, tests, package descriptors, docs, roadmap files, fixtures, public API files, or runtime compatibility files are changed.

- Command: `git diff --check`
  Result: pass. No whitespace errors.

- Command: `git diff --cached --check`
  Result: pass. No staged diff.

- Command: `rg -n "deprecat|remov|migrat|delete|rename|approval|Cabal exposure" orchestrator/rounds/round-097/facade-import-scan-refresh.md orchestrator/rounds/round-097/implementation-notes.md`
  Result: pass. Matches remain confined to required non-goals, blocker language, policy-reference paths, public exposure inventory, and verification text; no overclaim of deprecation, migration, removal, Cabal exposure change, release approval, milestone completion, or runtime compatibility cleanup approval was found.

- Command: `cabal build all`
  Result: pass in the prior review after the tracked `orchestrator/state.json` diff was observed. Reused because the retry correction touched only round-local inventory artifacts and no production, test, package, fixture, docs, roadmap, public API, or runtime compatibility path.

- Command: `cabal test watcher-core-test`
  Result: pass in the prior review after the tracked `orchestrator/state.json` diff was observed. Reused for the same artifact-only retry reason.

### Plan Compliance

- Re-read control-plane inputs: met. State, selection, plan, role, and active roadmap lineage remain consistent with round 097.
- Confirm selected facade source shapes: met in prior review and unchanged by this retry. The retry did not touch source files.
- Create inventory artifact and implementation notes: met. Both artifacts exist and now include retry correction notes.
- Broad selected-facade scan and narrow import-only counts: met. Counts still match the artifact.
- Package exposure and direct-owner scan: met. Public facade exposure remains in `moifold.cabal`; direct owner modules remain exposed in candidate packages.
- Direct-owner import scan: met in prior review and unchanged by this retry. Direct-owner imports are present and the retry did not alter source imports.
- `AppServerClient` classification and blockers: met in prior review and unchanged by this retry.
- `Core.Ids` classification and blockers: met after retry. `test/BoundaryPolicySpec.hs` is now correctly GitHub-only / safe direct-owner candidate, totals are `3 GitHub-only`, `2 agent-only`, `39 combined`, and stale combined/blocker wording is absent.
- `Workflow.EventLog` classification and blockers: met in prior review and unchanged by this retry.
- `Workflow.Permission` classification and blockers: met in prior review and unchanged by this retry.
- Docs and policy references: met. The artifact continues to treat docs as policy references rather than migration, deprecation, or removal approval.
- Standalone package-candidate result: met. Exact selected-facade imports are absent under `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`.
- Prior evidence comparison: met. The artifact uses current scans and treats prior rounds as history.
- Verification and baseline handling: met. Diff hygiene is clean. Package baselines passed in the prior review and are safely reused because the retry changed only round-local evidence artifacts.

### Decision

**APPROVED**

### Evidence

The previous rejection was addressed. The corrected inventory now classifies `test/BoundaryPolicySpec.hs` as a GitHub-only `Core.Ids` safe direct-owner candidate, and the exact-token scan confirms `agent=0 github=6` for that file. The full `Core.Ids` domain totals verify as `3 GitHub-only`, `2 agent-only`, and `39 both`, with no stale `40 combined`, `2 GitHub-only`, or `BoundaryPolicySpec` combined/blocker text remaining.

The rest of the round remains evidence-only. Selected-facade import counts, package exposure, direct-owner package exposure, standalone package-candidate absence, non-goal boundaries, diff hygiene, and prior package baselines all support approving the corrected integrated artifact.
