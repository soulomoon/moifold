{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module RuntimeSpec
  ( prop_runtimeCommandSpecsHaveExecutable
  , prop_runtimeDefaultsCentralizeThreadAndTurnOptions
  , prop_runtimeGhIssueCreateUsesRepoTitleAndBody
  , prop_runtimeGhIssueCreateWithParentLinksSubIssue
  , prop_runtimeGhIssueCloseCommentsAndCloses
  , prop_runtimeGhPrCreateKeepsStdoutJsonOnly
  , prop_runtimeGhPrBodyUpdateUsesPlanFile
  , prop_runtimeGhPrCommentReviewAndMergeCommentsBeforeMerge
  , prop_runtimeGhPrChecksUsesRequiredCurrentCli
  , prop_runtimeGhPrViewUsesStructuredFields
  , prop_runtimeGitPushDryRunNeverForces
  , prop_runtimeGitPushNeverForces
  , prop_runtimeKillZeroOnlyChecksPid
  , runtimeProcessSpecCapturesStreamsAndExit
  ) where

import CodexWatcher.Runtime.Command.Render (renderRuntimeCommand)
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (..), RuntimeCommandSpec (..))
import CodexWatcher.Runtime.Process (runProcessSpec)
import CodexWatcher.Runtime.Defaults
import CodexWatcher.AppServerProtocol (ThreadStartOptions (..), TurnStartOptions (..))
import CodexWatcher.Core.Ids
  ( BranchName (..)
  , CommitSha (..)
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName (..)
  , ReviewThreadId (..)
  , ThreadId (..)
  )
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.IssuePlanning.Types (IssueCreationRequest (..))
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), PrConfig (..))
import Data.Text qualified as Text

runtimeCommandExamples :: [RuntimeCommand]
runtimeCommandExamples =
  [ CommandVersion "git"
  , GhAuthStatus
  , GhApiUser
  , GhIssueListOpen (RepoName "soulomoon/mlf2")
  , GhIssueView (RepoName "soulomoon/mlf2") (IssueNumber 42) ["state", "closed", "url"]
  , GhIssueCreate (RepoName "soulomoon/mlf2") (IssueCreationRequest "Subissue title" "Subissue body" Nothing)
  , GhIssueClose (IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/example")) (PrNumber 7)
  , GhPrListOpen (RepoName "soulomoon/mlf2")
  , GhPrChecks (RepoName "soulomoon/mlf2") (PrNumber 6)
  , GhPrView (RepoName "soulomoon/mlf2") (PrNumber 6) ["state", "url"]
  , GhReviewThreads (PrConfig (RepoName "soulomoon/mlf2") (PrNumber 6) (BranchName "codex/example"))
  , GhCreatePullRequest "/tmp/work" (IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/example"))
  , GhUpdatePullRequestBody "/tmp/work" (IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/example")) (PrNumber 7) "/tmp/work/.watcher/issue-plan.md"
  , GhResolveReviewThread (ReviewThreadId "PRRT_test")
  , GhPrMerge (RepoName "soulomoon/mlf2") (PrNumber 6) "merge"
  , GhPrCommentReviewAndMerge (RepoName "soulomoon/mlf2") (PrNumber 6) (CleanReviewEvidence (CommitSha "abc123") "LGTM") "merge"
  , CheckNonEmptyFile "/tmp/work/.watcher/issue-plan.md"
  , GitBranchCurrent "/tmp/work"
  , GitRevParseHead "/tmp/work"
  , GitStatusPorcelain "/tmp/work"
  , GitLsRemoteBranch "/tmp/work" (BranchName "codex/example")
  , GitPushDryRun "/tmp/work" (BranchName "codex/example")
  , GitPush "/tmp/work" (BranchName "codex/example")
  , KillZero "123"
  , RawCommand "cabal" ["--version"] Nothing
  ]

prop_runtimeDefaultsCentralizeThreadAndTurnOptions :: ThreadId -> Bool
prop_runtimeDefaultsCentralizeThreadAndTurnOptions threadId =
  let threadOptions = defaultThreadStartOptions "/tmp/repo" "developer"
      turnOptions = defaultTurnStartOptions threadId "/tmp/repo" "input"
   in defaultModel == "gpt-5.5"
        && defaultEffort == "xhigh"
        && threadOptions.threadModel == defaultModel
        && threadOptions.threadApprovalPolicy == defaultApprovalPolicy
        && threadOptions.threadSandbox == defaultSandboxPolicy
        && turnOptions.turnModel == defaultModel
        && turnOptions.turnEffort == defaultEffort
        && turnOptions.turnApprovalPolicy == defaultApprovalPolicy
        && turnOptions.turnSandboxPolicy == defaultSandboxPolicy

prop_runtimeCommandSpecsHaveExecutable :: Bool
prop_runtimeCommandSpecsHaveExecutable =
  all (not . null . (.command) . renderRuntimeCommand) runtimeCommandExamples

prop_runtimeGitPushDryRunNeverForces :: BranchName -> Bool
prop_runtimeGitPushDryRunNeverForces branch =
  let spec = renderRuntimeCommand (GitPushDryRun "/tmp/work" branch)
   in spec.command == "git"
        && spec.cwd == Just "/tmp/work"
        && "--dry-run" `elem` spec.args
        && "--force" `notElem` spec.args
        && "--force-with-lease" `notElem` spec.args

prop_runtimeGitPushNeverForces :: BranchName -> Bool
prop_runtimeGitPushNeverForces branch =
  let spec = renderRuntimeCommand (GitPush "/tmp/work" branch)
   in spec.command == "git"
        && spec.cwd == Just "/tmp/work"
        && spec.args == ["push", "origin", Text.unpack (unBranchName branch)]
        && "--force" `notElem` spec.args
        && "--force-with-lease" `notElem` spec.args

prop_runtimeGhPrViewUsesStructuredFields :: RepoName -> PrNumber -> Bool
prop_runtimeGhPrViewUsesStructuredFields repo prNumber =
  let spec = renderRuntimeCommand (GhPrView repo prNumber ["state", "url", "headRefOid"])
      listSpec = renderRuntimeCommand (GhPrListOpen repo)
   in spec.command == "gh"
        && spec.args
          == [ "pr"
             , "view"
             , show (unPrNumber prNumber)
             , "--repo"
             , Text.unpack (unRepoName repo)
             , "--json"
             , "state,url,headRefOid"
             ]
        && listSpec.args
          == [ "pr"
             , "list"
             , "--repo"
             , Text.unpack (unRepoName repo)
             , "--state"
             , "open"
             , "--json"
             , "number,title,headRefName,headRefOid,body"
             ]

prop_runtimeGhPrChecksUsesRequiredCurrentCli :: RepoName -> PrNumber -> Bool
prop_runtimeGhPrChecksUsesRequiredCurrentCli repo prNumber =
  let spec = renderRuntimeCommand (GhPrChecks repo prNumber)
   in spec.command == "gh"
        && spec.args
          == [ "pr"
             , "checks"
             , show (unPrNumber prNumber)
             , "--repo"
             , Text.unpack (unRepoName repo)
             , "--required"
             ]

prop_runtimeGhIssueCreateUsesRepoTitleAndBody :: RepoName -> IssueCreationRequest -> Bool
prop_runtimeGhIssueCreateUsesRepoTitleAndBody repo requestWithMaybeParent =
  let request = requestWithMaybeParent {issueCreationParent = Nothing}
      spec = renderRuntimeCommand (GhIssueCreate repo request)
   in spec.command == "gh"
        && spec.args
          == [ "issue"
             , "create"
             , "--repo"
             , Text.unpack (unRepoName repo)
             , "--title"
             , Text.unpack (issueCreationTitle request)
             , "--body"
             , Text.unpack (issueCreationBody request)
             ]

prop_runtimeGhIssueCreateWithParentLinksSubIssue :: RepoName -> IssueCreationRequest -> IssueNumber -> Bool
prop_runtimeGhIssueCreateWithParentLinksSubIssue repo requestWithoutParent parentIssue =
  let request = requestWithoutParent {issueCreationParent = Just parentIssue}
      spec = renderRuntimeCommand (GhIssueCreate repo request)
      script = Text.pack (spec.args !! 1)
   in spec.command == "bash"
        && take 2 spec.args == ["-lc", Text.unpack script]
        && "sub_issues" `Text.isInfixOf` script
        && "sub_issue_id" `Text.isInfixOf` script
        && "-F \"sub_issue_id=$sub_issue_id\"" `Text.isInfixOf` script
        && spec.args
          == [ "-lc"
             , Text.unpack script
             , "codex-watcher-gh-sub-issue-create"
             , Text.unpack (unRepoName repo)
             , Text.unpack (issueCreationTitle request)
             , Text.unpack (issueCreationBody request)
             , show (unIssueNumber parentIssue)
             ]

prop_runtimeGhIssueCloseCommentsAndCloses :: IssueConfig -> PrNumber -> Bool
prop_runtimeGhIssueCloseCommentsAndCloses config prNumber =
  let spec = renderRuntimeCommand (GhIssueClose config prNumber)
      script = Text.pack (spec.args !! 1)
   in spec.command == "bash"
        && take 2 spec.args == ["-lc", Text.unpack script]
        && "gh issue comment \"$issue\"" `Text.isInfixOf` script
        && "Implemented by merged PR #$pr." `Text.isInfixOf` script
        && "gh issue close \"$issue\" --repo \"$repo\" --reason completed" `Text.isInfixOf` script
        && "gh issue view \"$issue\" --repo \"$repo\" --json state" `Text.isInfixOf` script
        && spec.args
          == [ "-lc"
             , Text.unpack script
             , "codex-watcher-gh-issue-close"
             , Text.unpack (unRepoName (issueRepo config))
             , show (unIssueNumber (issueNumber config))
             , show (unPrNumber prNumber)
             ]

prop_runtimeGhPrCreateKeepsStdoutJsonOnly :: IssueConfig -> Bool
prop_runtimeGhPrCreateKeepsStdoutJsonOnly config =
  let spec = renderRuntimeCommand (GhCreatePullRequest "/tmp/work" config)
      script = Text.pack (spec.args !! 1)
   in spec.command == "bash"
        && "git checkout -B \"$branch\" >/dev/null" `Text.isInfixOf` script
        && "git commit --allow-empty -m \"Start issue #$issue implementation\" >/dev/null" `Text.isInfixOf` script
        && "git push -u origin \"$branch\" >/dev/null" `Text.isInfixOf` script
        && "gh pr view \"$existing\" --repo \"$repo\" --json body,closingIssuesReferences" `Text.isInfixOf` script
        && "already uses branch" `Text.isInfixOf` script
        && "but is not linked to issue" `Text.isInfixOf` script
        && "printf '{\"status\":\"created\",\"prNumber\":%s}\\n' \"$number\"" `Text.isInfixOf` script
        && "printf '{\"status\":\"reused\",\"prNumber\":%s}\\n' \"$existing\"" `Text.isInfixOf` script

prop_runtimeGhPrBodyUpdateUsesPlanFile :: IssueConfig -> PrNumber -> Bool
prop_runtimeGhPrBodyUpdateUsesPlanFile config prNumber =
  let planPath = "/tmp/work/.watcher/issue-plan.md"
      spec = renderRuntimeCommand (GhUpdatePullRequestBody "/tmp/work" config prNumber planPath)
      script = Text.pack (spec.args !! 1)
   in spec.command == "bash"
        && spec.cwd == Just "/tmp/work"
        && "cat \"$plan_path\"" `Text.isInfixOf` script
        && "gh api --method PATCH \"repos/$repo/pulls/$pr\" -f body=\"$(cat \"$body_file\")\" >/dev/null" `Text.isInfixOf` script
        && "printf '{\"status\":\"updated\",\"prNumber\":%s}\\n' \"$pr\"" `Text.isInfixOf` script
        && spec.args
          == [ "-lc"
             , Text.unpack script
             , "codex-watcher-gh-pr-body-update"
             , Text.unpack (unRepoName (issueRepo config))
             , show (unPrNumber prNumber)
             , show (unIssueNumber (issueNumber config))
             , planPath
             ]

prop_runtimeGhPrCommentReviewAndMergeCommentsBeforeMerge :: PrNumber -> CleanReviewEvidence -> Bool
prop_runtimeGhPrCommentReviewAndMergeCommentsBeforeMerge prNumber evidence =
  let repo = RepoName "soulomoon/mlf2"
      spec = renderRuntimeCommand (GhPrCommentReviewAndMerge repo prNumber evidence "squash")
      script = Text.pack (spec.args !! 1)
      reviewIndex = Text.breakOn "gh pr review" script
      mergeIndex = Text.breakOn "gh pr merge" script
   in spec.command == "bash"
        && take 2 spec.args == ["-lc", Text.unpack script]
        && spec.args
          == [ "-lc"
             , Text.unpack script
             , "codex-watcher-gh-pr-comment-review-and-merge"
             , show (unPrNumber prNumber)
             , Text.unpack (unRepoName repo)
             , "--squash"
             ]
        && "set -euo pipefail" `Text.isInfixOf` script
        && "gh pr review" `Text.isInfixOf` script
        && "--comment --body-file -" `Text.isInfixOf` script
        && "gh pr merge" `Text.isInfixOf` script
        && Text.length (fst reviewIndex) < Text.length (fst mergeIndex)
        && cleanReviewComment evidence `Text.isInfixOf` spec.stdin
        && unCommitSha (cleanReviewCommit evidence) `Text.isInfixOf` spec.stdin
        && "Submitted by Haskell PR review watcher before merge." `Text.isInfixOf` spec.stdin

prop_runtimeKillZeroOnlyChecksPid :: ThreadId -> Bool
prop_runtimeKillZeroOnlyChecksPid threadId =
  let pidText = unThreadId threadId
      spec = renderRuntimeCommand (KillZero pidText)
      termSpec = renderRuntimeCommand (KillTerm pidText)
   in spec.command == "kill"
        && spec.args == ["-0", Text.unpack pidText]
        && spec.cwd == Nothing
        && termSpec.command == "kill"
        && termSpec.args == ["-TERM", Text.unpack pidText]
        && termSpec.cwd == Nothing

runtimeProcessSpecCapturesStreamsAndExit :: IO Bool
runtimeProcessSpecCapturesStreamsAndExit = do
  report <-
    runProcessSpec
      RuntimeCommandSpec
        { command = "bash"
        , args = ["-lc", "cat; printf err >&2; exit 7"]
        , cwd = Nothing
        , stdin = "input"
        }
  results <-
    sequence
      [ assert "typed-process reports nonzero exit as not ok" (not report.ok)
      , assert "typed-process preserves exit code" (report.status == Just 7)
      , assert "typed-process captures stdout" (report.stdout == "input")
      , assert "typed-process captures stderr" (report.stderr == "err")
      , assert "typed-process does not add synthetic error message for process exits" (report.errorMessage == Nothing)
      ]
  pure (and results)

assert :: String -> Bool -> IO Bool
assert label condition = do
  if condition
    then putStrLn ("PASS " <> label)
    else putStrLn ("FAIL " <> label)
  pure condition
