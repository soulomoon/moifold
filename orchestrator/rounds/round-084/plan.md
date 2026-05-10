### Goal

Retry the rejected same-round
`round-084-boundary-policy-test-module-split` by preserving the existing
extracted package-boundary scanner and boundary-policy assertion work, then
authorizing only the minimal `watcher-core-test` Cabal metadata needed to make
the extracted modules compile and remain reachable.

This retry must only add `BoundaryPolicySpec` and `TestSupport.SourceScan` to
the `watcher-core-test` `other-modules` list in `moifold.cabal`. It must not
add a package dependency, exposed module, production edit, docs edit, fixture
edit, runtime compatibility edit, roadmap/state edit, public facade exposure
change, runtime compatibility-file policy change, source import convergence,
public deprecation/removal claim, or broader Cabal/package-descriptor change.
Reference `orchestrator/project-contract.md` for the stable package-boundary
and compatibility-surface invariants.

### Approach

Keep the retry sequential and preserve the extracted work already present from
the first implementation pass:

- `test/BoundaryPolicySpec.hs`, with the package-boundary runner
  `workflowBoundaryPolicyTests`.
- `test/TestSupport/SourceScan.hs`, with reusable source-scan and Cabal parsing
  helpers used by the extracted runner and remaining tests.
- `test/Main.hs`, wired so `workflowFacadeExtractionTests` still reaches
  `workflowBoundaryPolicyTests` and the final `main` aggregation still fails
  when any extracted assertion fails.

The reviewer rejected the first implementation only because
`cabal test watcher-core-test` failed with `-Wmissing-home-modules` for
`BoundaryPolicySpec` and `TestSupport.SourceScan`. The retry therefore
authorizes a single package-descriptor metadata edit: add exactly those two
modules to the existing `watcher-core-test` `other-modules` list in
`moifold.cabal`. Do not otherwise reshape the test extraction, weaken
assertions, add dependencies, expose modules, or touch unrelated Cabal
sections.

### Steps

1. Re-read the active inputs before editing:
   `orchestrator/state.json`, `orchestrator/project-contract.md`,
   `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`,
   `orchestrator/rounds/round-084/selection.md`,
   `orchestrator/rounds/round-084/current plan.md` if present,
   `orchestrator/rounds/round-084/implementation-notes.md`, and
   `orchestrator/rounds/round-084/review.md`.
2. Preserve the existing extracted files and wiring:
   `test/BoundaryPolicySpec.hs`, `test/TestSupport/SourceScan.hs`, and the
   `workflowBoundaryPolicyTests` reachability path in `test/Main.hs`. Do not
   rewrite the extraction unless the minimal Cabal metadata edit exposes a
   direct compile error that must be fixed inside the already extracted test
   modules.
3. Edit only the `watcher-core-test` stanza in `moifold.cabal` and add exactly
   `BoundaryPolicySpec` and `TestSupport.SourceScan` to `other-modules`.
   Keep ordering consistent with nearby entries. Do not add package
   dependencies, exposed modules, library modules, build-tool changes,
   language extensions, warnings changes, source-dirs changes, or any other
   Cabal metadata.
4. Preserve the existing assertion text and failure diagnostics. In
   particular, do not collapse negative scan assertions into weaker smoke
   tests, remove printed violation details from `assertNoTextMatches`, narrow
   forbidden module/token lists, or remove the runtime-render facade parity
   check.
5. Keep the retry from becoming direction-003 or any removal/deprecation
   round. Do not split the broader facade import-policy suite, change
   production imports, remove compatibility facades, rename/delete runtime
   compatibility files, change fixtures, or update docs.
6. Update `orchestrator/rounds/round-084/implementation-notes.md` only as
   needed to record the retry metadata edit, commands run, changed-path
   evidence, and confirmation that no package dependency, exposed-module,
   production, docs, fixture, runtime compatibility, roadmap/state, public
   deprecation/removal, or broader Cabal change was made.

### Verification

Run the exact test gate for this retry:

```sh
cabal test watcher-core-test
```

Also run the baseline build and hygiene checks:

```sh
cabal build all
```

```sh
git diff --check
git status --short --untracked-files=all
```

If staging occurs, also run:

```sh
git diff --cached --check
```

The reviewer should confirm:

- `test/Main.hs` still reaches the extracted runner from the existing
  aggregate test path.
- The same package-boundary assertions still fail on import, dependency,
  exposed-module, forbidden-token, and adapter-reexport violations.
- Failure messages and violation detail output are preserved where practical.
- The only newly authorized package-descriptor change is adding
  `BoundaryPolicySpec` and `TestSupport.SourceScan` to `watcher-core-test`
  `other-modules` in `moifold.cabal`.
- There is no package dependency, exposed-module, production, docs, fixture,
  runtime compatibility, roadmap/state, public exposure, deprecation/removal,
  or broader Cabal change.
- `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and
  `git status --short --untracked-files=all` were run and recorded. If staging
  occurs, `git diff --cached --check` was also run and recorded.

### Worker Fan-Out

No worker fan-out is used. The active controller state has
`max_parallel_rounds: 1`, and this extraction has a single shared ownership
point in `test/Main.hs` plus tightly coupled helper wiring. Splitting it across
workers would create unnecessary integration risk.
