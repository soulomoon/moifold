### Changes Made
- `test/IssueFanoutAppServerSpec.hs`: Replaced the `CodexWatcher.Core.Ids` compatibility-facade import for `IssueNumber`, `RepoName`, and `unIssueNumber` with the direct owner import from `CodexWatcher.Workflow.GitHub.Ids`.

### Tests
- `test/IssueFanoutAppServerSpec.hs`: Existing issue-fanout app-server coverage is unchanged; no test bodies, helpers, expected command rendering, retry classification, child-start classification, JSON-RPC failure, or decode-failure assertions were changed.

### Notes
This round is import-only. Package descriptors, public facade exposure, production files, docs, policy strings, roadmap files, runtime compatibility files, broader `Core.Ids` migration, facade deprecation/removal, Cabal exposure cleanup, milestone completion, terminal completion, release approval, and public compatibility removal remain out of scope.
