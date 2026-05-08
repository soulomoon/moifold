{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Workflow.GitHub.Ids
  ( BranchName (..)
  , CommitSha (..)
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName (..)
  , ReviewThreadId (..)
  ) where

import Data.Text (Text)

newtype RepoName = RepoName { unRepoName :: Text }
  deriving stock (Eq, Ord, Show)

newtype IssueNumber = IssueNumber { unIssueNumber :: Int }
  deriving stock (Eq, Ord, Show)

newtype PrNumber = PrNumber { unPrNumber :: Int }
  deriving stock (Eq, Ord, Show)

newtype BranchName = BranchName { unBranchName :: Text }
  deriving stock (Eq, Ord, Show)

newtype ReviewThreadId = ReviewThreadId { unReviewThreadId :: Text }
  deriving stock (Eq, Ord, Show)

newtype CommitSha = CommitSha { unCommitSha :: Text }
  deriving stock (Eq, Ord, Show)
