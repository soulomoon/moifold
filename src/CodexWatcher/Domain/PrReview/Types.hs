{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving #-}

module CodexWatcher.Domain.PrReview.Types
  ( PrConfig (..)
  , PriorFindingsStatus (..)
  , priorFindingsStatusText
  , parsePriorFindingsStatus
  , allPriorFindingsStatuses
  , NewFindingsStatus (..)
  , newFindingsStatusText
  , parseNewFindingsStatus
  , allNewFindingsStatuses
  , ReviewFinding (..)
  , ReviewEvidence (..)
  , ReviewMode (..)
  , ReviewContext (..)
  , SomeReviewContext (..)
  , normalReviewContext
  , verificationReviewContext
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
import Data.Text qualified as Text

data PrConfig = PrConfig
  { prRepo :: RepoName
  , prNumber :: PrNumber
  , prBranch :: BranchName
  }
  deriving stock (Eq, Show)

data PriorFindingsStatus
  = PriorFindingsNotApplicable
  | PriorFindingsResolved
  | PriorFindingsUnresolved
  | PriorFindingsInconclusive
  | PriorFindingsBlocked
  deriving stock (Eq, Show)

priorFindingsStatusText :: PriorFindingsStatus -> Text
priorFindingsStatusText = \case
  PriorFindingsNotApplicable -> "not_applicable"
  PriorFindingsResolved -> "resolved"
  PriorFindingsUnresolved -> "unresolved"
  PriorFindingsInconclusive -> "inconclusive"
  PriorFindingsBlocked -> "blocked"

parsePriorFindingsStatus :: Text -> Maybe PriorFindingsStatus
parsePriorFindingsStatus status =
  case Text.toLower (Text.strip status) of
    "not_applicable" -> Just PriorFindingsNotApplicable
    "resolved" -> Just PriorFindingsResolved
    "unresolved" -> Just PriorFindingsUnresolved
    "inconclusive" -> Just PriorFindingsInconclusive
    "blocked" -> Just PriorFindingsBlocked
    _ -> Nothing

allPriorFindingsStatuses :: [PriorFindingsStatus]
allPriorFindingsStatuses =
  [ PriorFindingsNotApplicable
  , PriorFindingsResolved
  , PriorFindingsUnresolved
  , PriorFindingsInconclusive
  , PriorFindingsBlocked
  ]

data NewFindingsStatus
  = NewFindingsNone
  | NewFindingsFound
  | NewFindingsInconclusive
  | NewFindingsBlocked
  deriving stock (Eq, Show)

newFindingsStatusText :: NewFindingsStatus -> Text
newFindingsStatusText = \case
  NewFindingsNone -> "none"
  NewFindingsFound -> "found"
  NewFindingsInconclusive -> "inconclusive"
  NewFindingsBlocked -> "blocked"

parseNewFindingsStatus :: Text -> Maybe NewFindingsStatus
parseNewFindingsStatus status =
  case Text.toLower (Text.strip status) of
    "none" -> Just NewFindingsNone
    "found" -> Just NewFindingsFound
    "inconclusive" -> Just NewFindingsInconclusive
    "blocked" -> Just NewFindingsBlocked
    _ -> Nothing

allNewFindingsStatuses :: [NewFindingsStatus]
allNewFindingsStatuses =
  [ NewFindingsNone
  , NewFindingsFound
  , NewFindingsInconclusive
  , NewFindingsBlocked
  ]

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

data ReviewMode = NormalReview | VerificationReview
  deriving stock (Eq, Show)

data ReviewContext mode where
  NormalReviewContext :: ReviewContext 'NormalReview
  VerificationReviewContext :: ReviewEvidence -> ReviewContext 'VerificationReview

deriving stock instance Eq (ReviewContext mode)
deriving stock instance Show (ReviewContext mode)

data SomeReviewContext where
  SomeReviewContext :: ReviewContext mode -> SomeReviewContext

instance Eq SomeReviewContext where
  SomeReviewContext NormalReviewContext == SomeReviewContext NormalReviewContext = True
  SomeReviewContext (VerificationReviewContext left) == SomeReviewContext (VerificationReviewContext right) = left == right
  _ == _ = False

instance Show SomeReviewContext where
  show (SomeReviewContext NormalReviewContext) = "SomeReviewContext NormalReviewContext"
  show (SomeReviewContext (VerificationReviewContext evidence)) = "SomeReviewContext (VerificationReviewContext " <> show evidence <> ")"

normalReviewContext :: SomeReviewContext
normalReviewContext =
  SomeReviewContext NormalReviewContext

verificationReviewContext :: ReviewEvidence -> SomeReviewContext
verificationReviewContext evidence =
  SomeReviewContext (VerificationReviewContext evidence)

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
