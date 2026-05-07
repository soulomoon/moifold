{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Runtime.Command.Render
  ( commandText
  , renderRuntimeCommand
  ) where

import CodexWatcher.Runtime.Command.Types
import CodexWatcher.Core.Ids
  ( BranchName (..)
  , CommitSha (..)
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName (..)
  )
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.IssuePlanning.Types (IssueCreationRequest (..))
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), PrConfig (..), ReviewEvidence (..), reviewEvidenceSummaries, reviewEvidenceThreadCommentRefs, reviewEvidenceThreadRefs)
import CodexWatcher.Workflow.GitHub.Command qualified as GitHubCommand
import Data.Text (Text)
import Data.Text qualified as Text

renderRuntimeCommand :: RuntimeCommand -> RuntimeCommandSpec
renderRuntimeCommand (CommandVersion command') =
  RuntimeCommandSpec command' ["--version"] Nothing ""
renderRuntimeCommand GhAuthStatus =
  fromGitHubCommandSpec GitHubCommand.ghAuthStatusCommand
renderRuntimeCommand GhApiUser =
  fromGitHubCommandSpec GitHubCommand.ghApiUserCommand
renderRuntimeCommand (GhIssueListOpen repo) =
  fromGitHubCommandSpec (GitHubCommand.ghIssueListOpenCommand repo)
renderRuntimeCommand (GhIssueView repo issueNumber fields) =
  fromGitHubCommandSpec (GitHubCommand.ghIssueViewCommand repo issueNumber fields)
renderRuntimeCommand (GhIssueCreate repo request) =
  renderGhIssueCreate repo request
renderRuntimeCommand (GhIssueClose config prNumber') =
  RuntimeCommandSpec
    "bash"
    [ "-lc"
    , Text.unpack closeIssueScript
    , "codex-watcher-gh-issue-close"
    , Text.unpack (unRepoName (issueRepo config))
    , show (unIssueNumber (issueNumber config))
    , show (unPrNumber prNumber')
    ]
    Nothing
    ""
renderRuntimeCommand (GhPrListOpen repo) =
  fromGitHubCommandSpec (GitHubCommand.ghPrListOpenCommand repo)
renderRuntimeCommand (GhPrListByHead repo branch state) =
  fromGitHubCommandSpec (GitHubCommand.ghPrListByHeadCommand repo branch state)
renderRuntimeCommand (GhPrView repo prNumber fields) =
  fromGitHubCommandSpec (GitHubCommand.ghPrViewCommand repo prNumber fields)
renderRuntimeCommand (GhPrChecks repo prNumber) =
  fromGitHubCommandSpec (GitHubCommand.ghPrChecksCommand repo prNumber)
renderRuntimeCommand (GhReviewThreads config) =
  fromGitHubCommandSpec (GitHubCommand.ghReviewThreadsCommand (prRepo config) (prNumber config))
renderRuntimeCommand (GhCreatePullRequest workdir config) =
  RuntimeCommandSpec
    "bash"
    [ "-lc"
    , Text.unpack createPullRequestScript
    , "codex-watcher-gh-pr-create"
    , Text.unpack (unRepoName (issueRepo config))
    , Text.unpack (unBranchName (issueBranch config))
    , show (unIssueNumber (issueNumber config))
    ]
    (Just workdir)
    ""
renderRuntimeCommand (GhUpdatePullRequestBody workdir config prNumber planPath) =
  RuntimeCommandSpec
    "bash"
    [ "-lc"
    , Text.unpack updatePullRequestBodyScript
    , "codex-watcher-gh-pr-body-update"
    , Text.unpack (unRepoName (issueRepo config))
    , show (unPrNumber prNumber)
    , show (unIssueNumber (issueNumber config))
    , planPath
    ]
    (Just workdir)
    ""
renderRuntimeCommand (GhIssueFollowUp config evidence) =
  RuntimeCommandSpec
    "bash"
    [ "-lc"
    , Text.unpack issueFollowUpScript
    , "codex-watcher-gh-issue-follow-up"
    , Text.unpack (unRepoName (issueRepo config))
    , show (unIssueNumber (issueNumber config))
    ]
    Nothing
    (issueFollowUpBody config evidence)
renderRuntimeCommand (GhResolveReviewThread reviewThreadId) =
  fromGitHubCommandSpec (GitHubCommand.ghResolveReviewThreadCommand reviewThreadId)
renderRuntimeCommand (GhReplyReviewThread reviewThreadId comment) =
  fromGitHubCommandSpec (GitHubCommand.ghReplyReviewThreadCommand reviewThreadId comment)
renderRuntimeCommand (GhPrCommentReviewFindings config evidence) =
  RuntimeCommandSpec
    "gh"
    [ "pr"
    , "comment"
    , show (unPrNumber (prNumber config))
    , "--repo"
    , Text.unpack (unRepoName (prRepo config))
    , "--body-file"
    , "-"
    ]
    Nothing
    (reviewFindingsCommentBody evidence)
renderRuntimeCommand (GhPrMerge repo prNumber mergeMethod) =
  fromGitHubCommandSpec (GitHubCommand.ghPrMergeCommand repo prNumber mergeMethod)
renderRuntimeCommand (GhPrCleanReviewAndMerge repo prNumber evidence mergeMethod) =
  RuntimeCommandSpec
    "bash"
    [ "-lc"
    , Text.unpack cleanReviewAndMergeScript
    , "codex-watcher-gh-pr-clean-review-and-merge"
    , show (unPrNumber prNumber)
    , Text.unpack (unRepoName repo)
    , GitHubCommand.mergeFlag mergeMethod
    ]
    Nothing
    (cleanReviewBody evidence)
renderRuntimeCommand (CheckNonEmptyFile path) =
  RuntimeCommandSpec
    "bash"
    [ "-lc"
    , "set -euo pipefail; test -s \"$1\" || { printf 'file missing or empty: %s\\n' \"$1\" >&2; exit 1; }"
    , "codex-watcher-check-non-empty-file"
    , path
    ]
    Nothing
    ""
renderRuntimeCommand (GitBranchCurrent workdir) =
  fromGitHubCommandSpec (GitHubCommand.gitBranchCurrentCommand workdir)
renderRuntimeCommand (GitRevParseHead workdir) =
  fromGitHubCommandSpec (GitHubCommand.gitRevParseHeadCommand workdir)
renderRuntimeCommand (GitStatusPorcelain workdir) =
  fromGitHubCommandSpec (GitHubCommand.gitStatusPorcelainCommand workdir)
renderRuntimeCommand (GitLsRemoteBranch workdir branch) =
  fromGitHubCommandSpec (GitHubCommand.gitLsRemoteBranchCommand workdir branch)
renderRuntimeCommand (GitPushDryRun workdir branch) =
  fromGitHubCommandSpec (GitHubCommand.gitPushDryRunCommand workdir branch)
renderRuntimeCommand (GitPush workdir branch) =
  fromGitHubCommandSpec (GitHubCommand.gitPushCommand workdir branch)
renderRuntimeCommand (KillZero pid) =
  RuntimeCommandSpec "kill" ["-0", Text.unpack pid] Nothing ""
renderRuntimeCommand (KillTerm pid) =
  RuntimeCommandSpec "kill" ["-TERM", Text.unpack pid] Nothing ""
renderRuntimeCommand (RawCommand command' args' cwd') =
  RuntimeCommandSpec command' args' cwd' ""

fromGitHubCommandSpec :: GitHubCommand.GitHubCommandSpec -> RuntimeCommandSpec
fromGitHubCommandSpec spec =
  RuntimeCommandSpec
    { command = spec.githubCommand
    , args = spec.githubCommandArgs
    , cwd = spec.githubCommandCwd
    , stdin = spec.githubCommandStdin
    }

renderGhIssueCreate :: RepoName -> IssueCreationRequest -> RuntimeCommandSpec
renderGhIssueCreate repo request =
  case request.issueCreationParent of
    Nothing ->
      RuntimeCommandSpec
        "gh"
        [ "issue"
        , "create"
        , "--repo"
        , Text.unpack (unRepoName repo)
        , "--title"
        , Text.unpack (issueCreationTitle request)
        , "--body"
        , Text.unpack (issueCreationBody request)
        ]
        Nothing
        ""
    Just parentIssue ->
      RuntimeCommandSpec
        "bash"
        [ "-lc"
        , Text.unpack createAndLinkSubIssueScript
        , "codex-watcher-gh-sub-issue-create"
        , Text.unpack (unRepoName repo)
        , Text.unpack (issueCreationTitle request)
        , Text.unpack (issueCreationBody request)
        , show (unIssueNumber parentIssue)
        ]
        Nothing
        ""

createAndLinkSubIssueScript :: Text
createAndLinkSubIssueScript =
  Text.unlines
    [ "set -euo pipefail"
    , "repo=\"$1\""
    , "title=\"$2\""
    , "body=\"$3\""
    , "parent=\"$4\""
    , "url=$(gh issue create --repo \"$repo\" --title \"$title\" --body \"$body\")"
    , "number=\"${url##*/}\""
    , "sub_issue_id=$(gh api \"repos/$repo/issues/$number\" --jq '.id')"
    , "gh api --method POST -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2026-03-10' \"repos/$repo/issues/$parent/sub_issues\" -F \"sub_issue_id=$sub_issue_id\" >/dev/null"
    , "printf '%s\\n' \"$url\""
    ]

createPullRequestScript :: Text
createPullRequestScript =
  Text.unlines
    [ "set -euo pipefail"
    , "repo=\"$1\""
    , "branch=\"$2\""
    , "issue=\"$3\""
    , "default_branch=$(gh repo view \"$repo\" --json defaultBranchRef --jq '.defaultBranchRef.name // empty' 2>/dev/null || true)"
    , "if [ -z \"$default_branch\" ]; then"
    , "  default_branch=$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p' | head -n1 || true)"
    , "fi"
    , "if [ -z \"$default_branch\" ]; then default_branch=\"master\"; fi"
    , "existing=$(gh pr list --repo \"$repo\" --head \"$branch\" --state open --json number --jq '.[0].number // empty')"
    , "if [ -n \"$existing\" ]; then"
    , "  linked=$(gh pr view \"$existing\" --repo \"$repo\" --json body,closingIssuesReferences --jq \"(([.closingIssuesReferences[]?.number] | index($issue)) != null) or ((.body // \\\"\\\") | test(\\\"(?i)(close[sd]?|fix(e[sd])?|resolve[sd]?) +#$issue(\\\\\\\\b|[^0-9])\\\"))\")"
    , "  if [ \"$linked\" != \"true\" ]; then"
    , "    printf 'open PR #%s already uses branch %s but is not linked to issue #%s\\n' \"$existing\" \"$branch\" \"$issue\" >&2"
    , "    exit 1"
    , "  fi"
    , "  printf '{\"status\":\"reused\",\"prNumber\":%s}\\n' \"$existing\""
    , "  exit 0"
    , "fi"
    , "dirty_before_checkout=$(git status --porcelain)"
    , "current_branch=$(git branch --show-current || true)"
    , "if [ -n \"$dirty_before_checkout\" ] && [ \"$current_branch\" != \"$branch\" ]; then"
    , "  printf 'worktree has uncommitted changes on branch %s; expected %s\\n' \"$current_branch\" \"$branch\" >&2"
    , "  exit 1"
    , "fi"
    , "git fetch origin --prune >/dev/null"
    , "base=\"origin/$default_branch\""
    , "if ! git rev-parse --verify \"$base\" >/dev/null 2>&1; then"
    , "  git fetch origin \"$default_branch\" >/dev/null"
    , "fi"
    , "if git show-ref --verify --quiet \"refs/heads/$branch\"; then"
    , "  git checkout \"$branch\" >/dev/null"
    , "elif git show-ref --verify --quiet \"refs/remotes/origin/$branch\"; then"
    , "  git checkout -B \"$branch\" \"origin/$branch\" >/dev/null"
    , "else"
    , "  git checkout -B \"$branch\" \"$base\" >/dev/null"
    , "fi"
    , "git config user.email >/dev/null || git config user.email codex-watcher@users.noreply.github.com"
    , "git config user.name >/dev/null || git config user.name codex-watcher"
    , "if [ -n \"$(git status --porcelain)\" ]; then"
    , "  git add -A"
    , "  if ! git diff --cached --quiet; then"
    , "    git commit -m \"Implement issue #$issue\" >/dev/null"
    , "  fi"
    , "fi"
    , "if [ -z \"$(git log --oneline \"$base\"..HEAD)\" ]; then"
    , "  git commit --allow-empty -m \"Start issue #$issue implementation\" >/dev/null"
    , "fi"
    , "git push -u origin \"$branch\" >/dev/null"
    , "body=$(printf 'Closes #%s.\\n\\nImplementation plan pending. The issue implementer will sync issue-plan.md into this PR before implementation starts.' \"$issue\")"
    , "url=$(gh pr create --repo \"$repo\" --head \"$branch\" --base \"$default_branch\" --title \"Implement #$issue\" --body \"$body\")"
    , "number=\"${url##*/}\""
    , "printf '{\"status\":\"created\",\"prNumber\":%s}\\n' \"$number\""
    ]

updatePullRequestBodyScript :: Text
updatePullRequestBodyScript =
  Text.unlines
    [ "set -euo pipefail"
    , "repo=\"$1\""
    , "pr=\"$2\""
    , "issue=\"$3\""
    , "plan_path=\"$4\""
    , "body_file=$(mktemp)"
    , "trap 'rm -f \"$body_file\"' EXIT"
    , "{"
    , "  printf 'Closes #%s.\\n\\n' \"$issue\""
    , "  printf '## Implementation Plan\\n\\n'"
    , "  cat \"$plan_path\""
    , "  printf '\\n\\n---\\nImplementation plan synced by codex-watcher before implementation starts. Implementation commits will be pushed to this PR.\\n'"
    , "} > \"$body_file\""
    , "gh api --method PATCH \"repos/$repo/pulls/$pr\" -f body=\"$(cat \"$body_file\")\" >/dev/null"
    , "printf '{\"status\":\"updated\",\"prNumber\":%s}\\n' \"$pr\""
    ]

closeIssueScript :: Text
closeIssueScript =
  Text.unlines
    [ "set -euo pipefail"
    , "repo=\"$1\""
    , "issue=\"$2\""
    , "pr=\"$3\""
    , "state=$(gh issue view \"$issue\" --repo \"$repo\" --json state --jq '.state')"
    , "if [ \"$state\" != \"CLOSED\" ]; then"
    , "  gh issue comment \"$issue\" --repo \"$repo\" --body \"Implemented by merged PR #$pr.\" >/dev/null"
    , "  gh issue close \"$issue\" --repo \"$repo\" --reason completed >/dev/null"
    , "fi"
    , "printf '{\"status\":\"closed\",\"issueNumber\":%s,\"prNumber\":%s}\\n' \"$issue\" \"$pr\""
    ]

issueFollowUpScript :: Text
issueFollowUpScript =
  Text.unlines
    [ "set -euo pipefail"
    , "repo=\"$1\""
    , "issue=\"$2\""
    , "state=$(gh issue view \"$issue\" --repo \"$repo\" --json state --jq '.state')"
    , "if [ \"$state\" = \"CLOSED\" ]; then"
    , "  gh issue reopen \"$issue\" --repo \"$repo\" >/dev/null"
    , "fi"
    , "gh issue comment \"$issue\" --repo \"$repo\" --body-file - >/dev/null"
    , "printf '{\"status\":\"follow_up_recorded\",\"issueNumber\":%s}\\n' \"$issue\""
    ]

issueFollowUpBody :: IssueConfig -> ReviewEvidence -> Text
issueFollowUpBody config evidence =
  Text.unlines
    [ "Post-merge verification found rework is required for #" <> Text.pack (show (unIssueNumber config.issueNumber)) <> "."
    , ""
    , "Reviewed commit: `" <> unCommitSha evidence.reviewedCommit <> "`"
    , "Next branch: `" <> unBranchName config.issueBranch <> "`"
    , ""
    , "Findings:"
    , reviewFindingBullets evidence
    , ""
    , "The watcher will re-enter implementation on this branch instead of marking the issue complete."
    ]

cleanReviewAndMergeScript :: Text
cleanReviewAndMergeScript =
  Text.unlines
    [ "set -euo pipefail"
    , "pr_number=\"$1\""
    , "repo=\"$2\""
    , "merge_flag=\"$3\""
    , "gh pr review \"$pr_number\" --repo \"$repo\" --comment --body-file -"
    , "gh pr merge \"$pr_number\" --repo \"$repo\" \"$merge_flag\""
    ]

reviewFindingsCommentBody :: ReviewEvidence -> Text
reviewFindingsCommentBody evidence =
  Text.unlines
    [ "Review findings require rework at commit `" <> unCommitSha evidence.reviewedCommit <> "`."
    , ""
    , "Findings to address:"
    , reviewFindingBullets evidence
    ]

reviewFindingBullets :: ReviewEvidence -> Text
reviewFindingBullets evidence =
  Text.unlines
    ( summaryBullets <> threadCommentBullets <> threadBullets )
 where
  threadCommentRefs =
    reviewEvidenceThreadCommentRefs evidence
  threadCommentIds =
    [threadId | (threadId, _threadUrl, _comment) <- threadCommentRefs]
  summaryBullets =
    ["- " <> summary | summary <- reviewEvidenceSummaries evidence]
  threadCommentBullets =
    ["- " <> reviewThreadLink threadUrl <> ": " <> Text.strip comment | (_threadId, threadUrl, comment) <- threadCommentRefs]
  threadBullets =
    [ "- " <> reviewThreadLink threadUrl <> " requires follow-up."
    | (threadId, threadUrl) <- reviewEvidenceThreadRefs evidence
    , threadId `notElem` threadCommentIds
    ]

reviewThreadLink :: Maybe Text -> Text
reviewThreadLink (Just url)
  | not (Text.null (Text.strip url)) = "[Unresolved review thread](" <> Text.strip url <> ")"
reviewThreadLink _ =
  "Unresolved review thread"

cleanReviewBody :: CleanReviewEvidence -> Text
cleanReviewBody evidence =
  Text.unlines
    [ cleanReviewComment evidence
    , ""
    , "Reviewed commit: `" <> unCommitSha (cleanReviewCommit evidence) <> "`"
    , ""
    , "Submitted by Haskell PR review watcher as a clean review comment before merge."
    ]

commandText :: CommandReport -> Text
commandText report =
  Text.intercalate " " (filter (not . Text.null) [report.stderr, report.stdout, maybe "" id report.errorMessage])
