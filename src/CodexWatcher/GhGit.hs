{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.GhGit
  ( GhIssue (..)
  , GhPullRequest (..)
  , GhPullRequestCheck (..)
  , GhPullRequestCreateResult (..)
  , GitWorktreeStatus (..)
  , RemoteIssue (..)
  , RemoteIssueState (..)
  , RemotePullRequest (..)
  , RemotePullRequestMergeStateStatus (..)
  , RemotePullRequestState (..)
  , ReviewComment (..)
  , ReviewThread (..)
  , ReviewThreadsReport (..)
  , classifyRemotePullRequestMergeState
  , parseGhIssueList
  , parseGhIssueView
  , parseGhPrList
  , parseGhPrChecks
  , parseGhPrCreateResult
  , parseGhPrView
  , parseGhReviewThreads
  , parseGitBranch
  , parseGitSha
  , parseLsRemoteBranch
  , remoteIssueIsClosed
  , remotePullRequestIsOpen
  , remotePullRequestIsMerged
  , remotePullRequestMergeStateFixMessage
  , renderRemoteIssueState
  , renderRemotePullRequestState
  , runGitWorktreeStatus
  , runGhIssueListOpen
  , runGhIssueView
  , runGhPrListByHead
  , runGhPrListOpen
  , runGhPrChecks
  , runGhPrView
  , runGhReviewThreads
  ) where

import CodexWatcher.Runtime.Command.Render (commandText)
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (..))
import CodexWatcher.Runtime.Interpreter (RuntimeInterpreter (..))
import CodexWatcher.Runtime.Json (parseCommandJson)
import CodexWatcher.Workflow.GitHub.Ids (BranchName, IssueNumber, PrNumber, RepoName)
import CodexWatcher.Domain.PrReview.Types (PrConfig)
import CodexWatcher.Workflow.GitHub.Command qualified as GitHubCommand
import CodexWatcher.Workflow.GitHub.Remote
import Data.Text (Text)
import Data.Text qualified as Text

runGhIssueListOpen :: Monad m => RuntimeInterpreter m -> RepoName -> m (Either Text [GhIssue])
runGhIssueListOpen interpreter repo =
  parseCommandJson parseGhIssueList <$> interpreter.runtimeRunCommand (GhIssueListOpen repo)

runGhIssueView :: Monad m => RuntimeInterpreter m -> RepoName -> IssueNumber -> m (Either Text RemoteIssue)
runGhIssueView interpreter repo issueNumber =
  parseCommandJson parseGhIssueView
    <$> interpreter.runtimeRunCommand (GhIssueView repo issueNumber GitHubCommand.ghIssueViewStateFields)

runGhPrListOpen :: Monad m => RuntimeInterpreter m -> RepoName -> m (Either Text [GhPullRequest])
runGhPrListOpen interpreter repo =
  parseCommandJson parseGhPrList <$> interpreter.runtimeRunCommand (GhPrListOpen repo)

runGhPrListByHead :: Monad m => RuntimeInterpreter m -> RepoName -> BranchName -> Text -> m (Either Text [GhPullRequest])
runGhPrListByHead interpreter repo branch state =
  parseCommandJson parseGhPrList <$> interpreter.runtimeRunCommand (GhPrListByHead repo branch state)

runGhPrChecks :: Monad m => RuntimeInterpreter m -> RepoName -> PrNumber -> m (Either Text [GhPullRequestCheck])
runGhPrChecks interpreter repo prNumber = do
  report <- interpreter.runtimeRunCommand (GhPrChecks repo prNumber)
  case parseGhPrChecks report.stdout of
    Right checks -> pure (Right checks)
    Left parseError
      | report.ok -> pure (Left parseError)
      | otherwise -> pure (Left (commandText report))

runGhPrView :: Monad m => RuntimeInterpreter m -> RepoName -> PrNumber -> m (Either Text RemotePullRequest)
runGhPrView interpreter repo prNumber =
  parseCommandJson parseGhPrView
    <$> interpreter.runtimeRunCommand (GhPrView repo prNumber GitHubCommand.ghPrViewRemoteFields)

runGhReviewThreads :: Monad m => RuntimeInterpreter m -> PrConfig -> m (Either Text ReviewThreadsReport)
runGhReviewThreads interpreter prConfig =
  parseCommandJson parseGhReviewThreads <$> interpreter.runtimeRunCommand (GhReviewThreads prConfig)

runGitWorktreeStatus :: Monad m => RuntimeInterpreter m -> FilePath -> BranchName -> m GitWorktreeStatus
runGitWorktreeStatus interpreter workdir branch = do
  branchReport <- interpreter.runtimeRunCommand (GitBranchCurrent workdir)
  headReport <- interpreter.runtimeRunCommand (GitRevParseHead workdir)
  dirtyReport <- interpreter.runtimeRunCommand (GitStatusPorcelain workdir)
  remoteReport <- interpreter.runtimeRunCommand (GitLsRemoteBranch workdir branch)
  let dirtyStatus = dirtyReport.stdout
  pure
    GitWorktreeStatus
      { gitCurrentBranch = parseGitBranch branchReport.stdout
      , gitHeadSha = parseGitSha headReport.stdout
      , gitDirtyStatus = dirtyStatus
      , gitIsDirty = not (Text.null (Text.strip dirtyStatus))
      , gitRemoteHeadSha = parseLsRemoteBranch remoteReport.stdout
      }
