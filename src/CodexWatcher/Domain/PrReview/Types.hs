{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Domain.PrReview.Types
  ( PrConfig (..)
  , ReviewFinding (..)
  , ReviewEvidence (..)
  , reviewEvidenceFromSummaries
  , reviewEvidenceFromParts
  , reviewEvidenceFromThreads
  , reviewEvidenceSummaries
  , reviewEvidenceThreadIds
  , CleanReviewEvidence (..)
  , MergeCommit (..)
  ) where

import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId)
import Data.List.NonEmpty (NonEmpty)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)

data PrConfig = PrConfig
  { prRepo :: RepoName
  , prNumber :: PrNumber
  , prBranch :: BranchName
  }
  deriving stock (Eq, Show)

data ReviewFinding
  = ReviewThreadFinding ReviewThreadId
  | ReviewSummaryFinding Text
  deriving stock (Eq, Show)

data ReviewEvidence = ReviewEvidence
  { reviewFindings :: NonEmpty ReviewFinding
  , reviewedCommit :: CommitSha
  }
  deriving stock (Eq, Show)

reviewEvidenceFromThreads :: NonEmpty ReviewThreadId -> CommitSha -> ReviewEvidence
reviewEvidenceFromThreads threads commit =
  ReviewEvidence (ReviewThreadFinding <$> threads) commit

reviewEvidenceFromSummaries :: NonEmpty Text -> CommitSha -> ReviewEvidence
reviewEvidenceFromSummaries summaries commit =
  ReviewEvidence (ReviewSummaryFinding <$> summaries) commit

reviewEvidenceFromParts :: [ReviewThreadId] -> [Text] -> CommitSha -> Maybe ReviewEvidence
reviewEvidenceFromParts threadIds summaries commit =
  case (ReviewThreadFinding <$> threadIds) <> (ReviewSummaryFinding <$> summaries) of
    [] -> Nothing
    finding : rest -> Just (ReviewEvidence (finding NonEmpty.:| rest) commit)

reviewEvidenceThreadIds :: ReviewEvidence -> [ReviewThreadId]
reviewEvidenceThreadIds evidence =
  [threadId | ReviewThreadFinding threadId <- NonEmpty.toList (reviewFindings evidence)]

reviewEvidenceSummaries :: ReviewEvidence -> [Text]
reviewEvidenceSummaries evidence =
  [summary | ReviewSummaryFinding summary <- NonEmpty.toList (reviewFindings evidence)]

data CleanReviewEvidence = CleanReviewEvidence
  { cleanReviewCommit :: CommitSha
  , cleanReviewComment :: Text
  }
  deriving stock (Eq, Show)

newtype MergeCommit = MergeCommit { unMergeCommit :: CommitSha }
  deriving stock (Eq, Show)
