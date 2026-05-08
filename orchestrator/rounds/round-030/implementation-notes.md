### Changes Made
- test/Main.hs: expanded transaction-law coverage for prepare failures before and after replay, pre-commit action failure, event commit failure, post-commit replay failure, post-commit callback failure, and post-commit action failure using DocsMigrationSpec fake hooks.
- test/Main.hs: added generic dry-run versus execute parity coverage proving dry-run does not mutate, execute orders pre actions before commit, commit before after-commit, and after-commit before post actions.
- test/Main.hs: tightened moifold observed transaction assertions for dry-run pre/post report partitioning and execute append-before-compatibility-write ordering.
- test/Main.hs: tightened DocsMigration dry-run/execute parity assertions for compiled action order, report order, no dry-run interpreter calls, execute interpreter order, and all-post-commit audit partitioning.

### Tests
- test/Main.hs: transaction failure and audit assertions now cover all current detailed WorkflowTransactionFailureStage constructors, audit labels, failure classification, and retry/stop recommendations.
- test/Main.hs: generic dry-run/execute parity test verifies fake pre/post action partitioning and commit-boundary ordering.
- test/Main.hs: moifold and DocsMigration transaction path tests verify existing dry-run and execute surfaces against the tightened transaction laws.

### Validation
- `cabal test watcher-core-test`: PASS.
- `cabal build all`: PASS.
- `git diff --check`: PASS.
- `git diff --cached --check`: not run; no files were staged in this round.

### Notes
No production code changes were required. Moifold post-commit callback failure remains covered by the generic fake transaction hook because the current fake runtime compatibility-write hook is unit-returning and cannot surface a write failure without production-test harness changes outside this round's test-first scope.
