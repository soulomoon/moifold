{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Domain.IssueImplement.Types
  ( IssueConfig (..)
  ) where

import CodexWatcher.Core.Ids (BranchName, IssueNumber, RepoName)

data IssueConfig = IssueConfig
  { issueRepo :: RepoName
  , issueNumber :: IssueNumber
  , issueBranch :: BranchName
  }
  deriving stock (Eq, Show)
