{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Domain.PrReview.Types
  ( PrConfig (..)
  , ReviewFinding (..)
  , ReviewEvidence (..)
  , reviewEvidenceFromThreadComments
  , reviewEvidenceFromThreadCommentRefs
  , reviewEvidenceFromThreadRefs
  , reviewEvidenceFromSummaries
  , reviewEvidenceFromParts
  , reviewEvidenceFromThreads
  , reviewEvidenceHasSummaries
  , reviewEvidenceSummaries
  , reviewEvidenceThreadCommentRefs
  , reviewEvidenceThreadComments
  , reviewEvidenceThreadIds
  , reviewEvidenceThreadRefs
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
  = ReviewThreadFinding ReviewThreadId (Maybe Text)
  | ReviewThreadCommentFinding ReviewThreadId (Maybe Text) Text
  | ReviewSummaryFinding Text
  deriving stock (Eq, Show)

data ReviewEvidence = ReviewEvidence
  { reviewFindings :: NonEmpty ReviewFinding
  , reviewedCommit :: CommitSha
  }
  deriving stock (Eq, Show)

reviewEvidenceFromThreads :: NonEmpty ReviewThreadId -> CommitSha -> ReviewEvidence
reviewEvidenceFromThreads threads commit =
  ReviewEvidence ((`ReviewThreadFinding` Nothing) <$> threads) commit

reviewEvidenceFromThreadRefs :: NonEmpty (ReviewThreadId, Maybe Text) -> CommitSha -> ReviewEvidence
reviewEvidenceFromThreadRefs threads commit =
  ReviewEvidence (uncurry ReviewThreadFinding <$> threads) commit

reviewEvidenceFromSummaries :: NonEmpty Text -> CommitSha -> ReviewEvidence
reviewEvidenceFromSummaries summaries commit =
  ReviewEvidence (ReviewSummaryFinding <$> summaries) commit

reviewEvidenceFromThreadComments :: NonEmpty (ReviewThreadId, Text) -> CommitSha -> ReviewEvidence
reviewEvidenceFromThreadComments comments commit =
  ReviewEvidence (fmap (\(threadId, comment) -> ReviewThreadCommentFinding threadId Nothing comment) comments) commit

reviewEvidenceFromThreadCommentRefs :: NonEmpty (ReviewThreadId, Maybe Text, Text) -> CommitSha -> ReviewEvidence
reviewEvidenceFromThreadCommentRefs comments commit =
  ReviewEvidence (fmap (\(threadId, threadUrl, comment) -> ReviewThreadCommentFinding threadId threadUrl comment) comments) commit

reviewEvidenceFromParts :: [ReviewThreadId] -> [Text] -> CommitSha -> Maybe ReviewEvidence
reviewEvidenceFromParts threadIds summaries commit =
  case ((`ReviewThreadFinding` Nothing) <$> threadIds) <> (ReviewSummaryFinding <$> summaries) of
    [] -> Nothing
    finding : rest -> Just (ReviewEvidence (finding NonEmpty.:| rest) commit)

reviewEvidenceThreadIds :: ReviewEvidence -> [ReviewThreadId]
reviewEvidenceThreadIds evidence =
  [threadId | finding <- NonEmpty.toList (reviewFindings evidence), threadId <- threadIdForFinding finding]
 where
  threadIdForFinding (ReviewThreadFinding threadId _threadUrl) = [threadId]
  threadIdForFinding (ReviewThreadCommentFinding threadId _threadUrl _comment) = [threadId]
  threadIdForFinding ReviewSummaryFinding {} = []

reviewEvidenceThreadComments :: ReviewEvidence -> [(ReviewThreadId, Text)]
reviewEvidenceThreadComments evidence =
  [(threadId, comment) | ReviewThreadCommentFinding threadId _threadUrl comment <- NonEmpty.toList (reviewFindings evidence)]

reviewEvidenceThreadRefs :: ReviewEvidence -> [(ReviewThreadId, Maybe Text)]
reviewEvidenceThreadRefs evidence =
  [(threadId, threadUrl) | ReviewThreadFinding threadId threadUrl <- NonEmpty.toList (reviewFindings evidence)]

reviewEvidenceThreadCommentRefs :: ReviewEvidence -> [(ReviewThreadId, Maybe Text, Text)]
reviewEvidenceThreadCommentRefs evidence =
  [(threadId, threadUrl, comment) | ReviewThreadCommentFinding threadId threadUrl comment <- NonEmpty.toList (reviewFindings evidence)]

reviewEvidenceSummaries :: ReviewEvidence -> [Text]
reviewEvidenceSummaries evidence =
  [summary | ReviewSummaryFinding summary <- NonEmpty.toList (reviewFindings evidence)]

reviewEvidenceHasSummaries :: ReviewEvidence -> Bool
reviewEvidenceHasSummaries =
  not . null . reviewEvidenceSummaries

data CleanReviewEvidence = CleanReviewEvidence
  { cleanReviewCommit :: CommitSha
  , cleanReviewComment :: Text
  }
  deriving stock (Eq, Show)

newtype MergeCommit = MergeCommit { unMergeCommit :: CommitSha }
  deriving stock (Eq, Show)
