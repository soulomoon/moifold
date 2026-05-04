# 03 Start Specific Issue

Use an issue implementer watcher when the agent should implement one GitHub issue.

## Initialize state

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
cd "$WATCHER_REPO"
ISSUE_STATE_DIR="$(scripts/watcher-init/init-issue-implement-state.sh /workspace/artifacts/<project>-watcher.env)"
printf "%s\n" "$ISSUE_STATE_DIR"
'
```

The conventional issue state directory is:

```text
$IMPLEMENTERS_ROOT/<repo-slug>__issue${ISSUE_NUMBER}
```

The repo slug follows the Haskell watcher rule: every non-alphanumeric character in `REPO_FULL_NAME` becomes `_`.

## Dry run one iteration

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
ISSUE_STATE_DIR="$IMPLEMENTERS_ROOT/${REPO_FULL_NAME//[^[:alnum:]]/_}__issue${ISSUE_NUMBER}"
"$ISSUE_STATE_DIR/dry-run-command.sh"
'
```

## Start continuous execution

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
ISSUE_STATE_DIR="$IMPLEMENTERS_ROOT/${REPO_FULL_NAME//[^[:alnum:]]/_}__issue${ISSUE_NUMBER}"
"$ISSUE_STATE_DIR/restart-command.sh"
'
```

Expected lifecycle:

1. Create or reuse PR for `$ISSUE_BRANCH`.
2. Start an issue plan turn.
3. Write/update the PR body from the issue plan.
4. Start implementation turns until complete.
5. Hand off to PR review.
6. Wait for PR merge.
7. Run post-merge final review.
8. Close the issue or restart implementation for follow-up.
