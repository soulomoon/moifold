{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Domain.PrReview.Types
  ( PrConfig (..)
  , ReviewEvidence (..)
  , CleanReviewEvidence (..)
  , MergeCommit (..)
  ) where

import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId)
import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)

data PrConfig = PrConfig
  { prRepo :: RepoName
  , prNumber :: PrNumber
  , prBranch :: BranchName
  }
  deriving stock (Eq, Show)

data ReviewEvidence = ReviewEvidence
  { unresolvedThreads :: NonEmpty ReviewThreadId
  , reviewedCommit :: CommitSha
  }
  deriving stock (Eq, Show)

data CleanReviewEvidence = CleanReviewEvidence
  { cleanReviewCommit :: CommitSha
  , cleanReviewComment :: Text
  }
  deriving stock (Eq, Show)

newtype MergeCommit = MergeCommit { unMergeCommit :: CommitSha }
  deriving stock (Eq, Show)
