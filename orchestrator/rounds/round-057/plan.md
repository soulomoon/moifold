### Goal

Write the evidence-backed runtime compatibility cleanup policy for
`round-057-runtime-compatibility-cleanup-policy`, using the round 053 runtime
compatibility-file inventory and round 055 runtime file behavior-gate evidence.

The round must stay docs/policy/artifact only. It must not migrate, rename,
remove, reformat, or rewrite runtime compatibility files; change schemas,
field meanings, event JSON `type` fields, write timing, repair behavior,
healthcheck behavior, runtime behavior, import-facade policy, package
boundaries, roadmap scope, or removal approval.

### Approach

Keep the work sequential. The selected surfaces share one runtime/operator
contract and should be classified in one integrated policy update, not split
across workers.

Use the existing policy document
`docs/agentic-workflow-framework/compatibility-deprecation-policy.md` as the
primary framework-facing policy surface unless the implementation pass finds a
more specific existing docs file that already owns runtime compatibility-file
policy. Add a round-local artifact under
`orchestrator/rounds/round-057/` that records the refreshed evidence,
surface-by-surface classifications, and gates. Read back
`orchestrator/project-contract.md`; update it only if the durable repo-wide
runtime compatibility invariant is incomplete after the policy wording lands.
If it is already aligned, state that explicitly in the round artifact and
implementation notes instead of churning the contract.

The policy should classify every selected surface conservatively:

- `keep`: current runtime/operator contract with no plausible removal path
  from current evidence.
- `defer`: a replacement or weaker usage may exist, but required old-log,
  golden, repair, healthcheck, write-timing, fixture, or external-operator
  evidence is missing.
- `remove-later`: only if all named gates are already protected by current
  tests or fixtures and the policy still makes clear that this is not removal
  approval. Round 055 found no selected runtime surface in this state, so any
  new `remove-later` classification needs fresh, cited evidence.

### Steps

1. Re-read the selected scope and invariants from
   `orchestrator/rounds/round-057/selection.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/verification.md`,
   and `orchestrator/project-contract.md`.
2. Re-read the evidence inputs:
   `orchestrator/rounds/round-053/runtime-compatibility-file-inventory.md`,
   `orchestrator/rounds/round-055/runtime-file-behavior-gates.md`, and the
   current `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
3. Refresh the current source/docs evidence with focused read-only scans before
   editing policy text:

   ```sh
   find . -name 'issue-state.json' -o -name 'daemon-state.json' -o -name 'planning-state.json' -o -name '*pr-url*' -o -name '*pr-state*' -o -name '*block*state*' -o -name '*repair*state*' -o -name '*owner*' -o -name '*snapshot*'
   rg -n "issue-state\\.json|daemon-state\\.json|planning-state\\.json|pr-url|pr state|PR URL|pr_url|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|runtime owner|compatibility snapshot|issue-snapshot\\.json|snapshot" src app test scripts docs examples golden orchestrator
   rg -n "compatibilityStateWrites|CompatibilityWrite|writeCompatibility|RecordBlocked|RecordPlanningGraph|repair-invalid-state|repair-state\\.json|Healthcheck|healthcheck|runtime-owner\\.json|RuntimeOwner|issue-snapshot\\.json|goldenReplayCases|goldenBootstrapCases" src test scripts docs golden
   rg -n "writeFile|atomicWrite|encodeFile|decodeFile|eitherDecode|readFile|doesFileExist|renameFile|copyFile|removeFile" src test scripts
   ```

   Record only policy-relevant deltas from rounds 053 and 055. If there are no
   deltas, cite those rounds as the controlling evidence.
4. Update the framework compatibility/deprecation policy, or the more specific
   docs file chosen in step 2, with a runtime compatibility-file cleanup policy
   section. It must cite rounds 053 and 055, state that the event log remains
   workflow truth, and state that runtime compatibility files are
   moifold-owned operator/runtime contracts.
5. In that policy update, cover all selected surfaces:
   `issue-state.json`, `daemon-state.json`, `planning-state.json`, PR review
   state files and PR URL fields, `block-state.json`, `repair-state.json`,
   `runtime-owner.json`, checked-in compatibility snapshots, and live
   `issue-snapshot.json`.
6. For each surface, record the current classification and the evidence basis:
   producers/readers, old-log or golden evidence, repair behavior, healthcheck
   behavior, write timing, fixture coverage, protecting tests, and missing
   external-operator evidence where applicable. Preserve the round 055
   classifications unless the refreshed scans prove a source-backed change.
7. Explicitly forbid future implementers from treating this round as approval
   for file migration/removal, schema/name/write-timing changes, runtime
   behavior changes, repair or healthcheck redesign, roadmap expansion, removal
   approval, or import-facade policy changes.
8. Add a round-local policy artifact, expected path
   `orchestrator/rounds/round-057/runtime-compatibility-cleanup-policy.md`,
   summarizing the refreshed scans, final classification table, required gates
   before any later deprecation/migration/removal selection, and any project
   contract alignment decision.
9. Read back `orchestrator/project-contract.md` after the docs update. If its
   current runtime compatibility-file invariant still covers the policy, leave
   it unchanged and record that justification in the round-local artifact. If a
   durable invariant is missing, update only the contract sentence needed to
   align it with the new policy.
10. Do not write `worker-plan.json`. This round has one docs-policy ownership
    surface and no disjoint implementation fan-out.

### Verification

Run the baseline checks from the roadmap verification contract:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
git diff --check
git diff --cached --check
```

Also run focused policy/readback checks:

```sh
rg -n "runtime compatibility|compatibility-file|issue-state\\.json|daemon-state\\.json|planning-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|issue-snapshot\\.json|pr_url|watcher-state\\.json|checker-state\\.json|reviewer-state\\.json|keep|defer|remove-later" docs/agentic-workflow-framework orchestrator/rounds/round-057 orchestrator/project-contract.md
git diff -- docs/agentic-workflow-framework orchestrator/project-contract.md orchestrator/rounds/round-057
git diff --name-only
```

The diff must show docs/policy/artifact changes only. It must not include
production source, tests, golden fixtures, checked-in runtime state files,
schemas, Cabal descriptors, scripts, roadmap expansion, or worker-plan changes.
The readback must confirm that wording does not imply package publication,
deprecation pragma readiness, migration readiness, removal approval, or any
runtime behavior/file/schema/write-timing change.

### Worker Fan-Out

Worker fan-out is not used. The runtime compatibility cleanup policy is a
single integrated docs-policy artifact, and splitting it would create avoidable
classification and wording drift across shared runtime/operator contracts.
