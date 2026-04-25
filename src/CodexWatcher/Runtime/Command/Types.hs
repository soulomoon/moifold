{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Runtime.Command.Types
  ( CommandReport (..)
  , RuntimeCommand (..)
  , RuntimeCommandSpec (..)
  ) where

import CodexWatcher.Core.Ids
  ( BranchName
  , IssueNumber
  , PrNumber
  , RepoName
  , ReviewThreadId
  )
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig)
import CodexWatcher.Domain.IssuePlanning.Types (IssueCreationRequest)
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence, PrConfig, ReviewEvidence)
import Data.Aeson (ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)

data RuntimeCommand
  = CommandVersion String
  | GhAuthStatus
  | GhApiUser
  | GhIssueListOpen RepoName
  | GhIssueView RepoName IssueNumber [Text]
  | GhIssueCreate RepoName IssueCreationRequest
  | GhIssueClose IssueConfig PrNumber
  | GhPrListOpen RepoName
  | GhPrView RepoName PrNumber [Text]
  | GhPrChecks RepoName PrNumber
  | GhReviewThreads PrConfig
  | GhCreatePullRequest FilePath IssueConfig
  | GhUpdatePullRequestBody FilePath IssueConfig PrNumber FilePath
  | GhResolveReviewThread ReviewThreadId
  | GhPrRequestChanges PrConfig ReviewEvidence
  | GhPrMerge RepoName PrNumber Text
  | GhPrApproveReviewAndMerge RepoName PrNumber CleanReviewEvidence Text
  | CheckNonEmptyFile FilePath
  | GitBranchCurrent FilePath
  | GitRevParseHead FilePath
  | GitStatusPorcelain FilePath
  | GitLsRemoteBranch FilePath BranchName
  | GitPushDryRun FilePath BranchName
  | GitPush FilePath BranchName
  | KillZero Text
  | KillTerm Text
  | RawCommand String [String] (Maybe FilePath)
  deriving stock (Eq, Show, Generic)

data RuntimeCommandSpec = RuntimeCommandSpec
  { command :: String
  , args :: [String]
  , cwd :: Maybe FilePath
  , stdin :: Text
  }
  deriving stock (Eq, Show, Generic)

data CommandReport = CommandReport
  { ok :: Bool
  , status :: Maybe Int
  , stdout :: Text
  , stderr :: Text
  , errorMessage :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)
