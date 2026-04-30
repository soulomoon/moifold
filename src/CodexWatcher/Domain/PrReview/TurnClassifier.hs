{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.PrReview.TurnClassifier
  ( classifyPrReviewReviewerTurn
  , classifyPrReviewWorkerTurn
  ) where

import CodexWatcher.AppServerClient
import CodexWatcher.Domain.PrReview.Protocol
import CodexWatcher.Domain.PrReview.Watcher
import CodexWatcher.Turn.Classifier.Common
import CodexWatcher.TurnOutput (reviewerPromptVersion)
import CodexWatcher.Core.Ids (CommitSha (..), ReviewThreadId (..))
import CodexWatcher.Core.Reason (BlockedReason (..))
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), reviewEvidenceFromThreadComments, reviewEvidenceFromSummaries)
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:), (.:?))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding

data ReviewerTurnReport = ReviewerTurnReport
  { reviewerReportStatus :: Maybe Text
  , reviewerReportCommit :: Maybe CommitSha
  , reviewerReportPromptVersion :: Maybe Text
  , reviewerReportAddedCommentCount :: Maybe Int
  , reviewerReportLgtmCommentPresent :: Bool
  , reviewerReportLgtmComment :: Maybe Text
  , reviewerReportFindingsSummary :: Maybe [Text]
  , reviewerReportBlockedReasonPresent :: Bool
  , reviewerReportBlockedReason :: Maybe Text
  , reviewerReportSolvedThreads :: Maybe [SolvedReviewThread]
  , reviewerReportRemainingThreads :: Maybe [RemainingReviewThread]
  }
  deriving stock (Eq, Show)

data SolvedReviewThread = SolvedReviewThread
  { solvedReviewThreadId :: ReviewThreadId
  , solvedReviewThreadSummary :: Text
  }
  deriving stock (Eq, Show)

data RemainingReviewThread = RemainingReviewThread
  { remainingReviewThreadId :: ReviewThreadId
  , remainingReviewThreadComment :: Text
  }
  deriving stock (Eq, Show)

instance FromJSON SolvedReviewThread where
  parseJSON = withObject "SolvedReviewThread" \objectValue ->
    SolvedReviewThread
      <$> (ReviewThreadId <$> objectValue .: "thread_id")
      <*> objectValue .: "resolution_summary"

instance FromJSON RemainingReviewThread where
  parseJSON = withObject "RemainingReviewThread" \objectValue ->
    RemainingReviewThread
      <$> (ReviewThreadId <$> objectValue .: "thread_id")
      <*> objectValue .: "comment"

instance FromJSON ReviewerTurnReport where
  parseJSON = withObject "ReviewerTurnReport" \objectValue -> do
    let has key = KeyMap.member (Key.fromString key) objectValue
    ReviewerTurnReport
      <$> objectValue .:? "review_status"
      <*> (fmap CommitSha <$> objectValue .:? "reviewed_commit_sha")
      <*> objectValue .:? "reviewer_prompt_version"
      <*> objectValue .:? "added_review_comment_count"
      <*> pure (has "lgtm_comment")
      <*> objectValue .:? "lgtm_comment"
      <*> objectValue .:? "findings_summary"
      <*> pure (has "blocked_reason")
      <*> objectValue .:? "blocked_reason"
      <*> objectValue .:? "solved_threads"
      <*> objectValue .:? "remaining_review_threads"

classifyPrReviewWorkerTurn :: AppServerTurn -> Maybe PrReviewObservation
classifyPrReviewWorkerTurn turn =
  ObservedWorkerOutcome <$> case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      maybe (Just (WorkerBlocked (BlockedReason reason))) classifyStructuredPrReviewWorker (parseStructuredTurnOutcome reason)
    TurnCompleted output
      | Just outcome <- missingOutputBlocked "worker turn completed without output" WorkerBlocked output ->
          Just outcome
      | Just structured <- output >>= parseStructuredTurnOutcome ->
          classifyStructuredPrReviewWorker structured
      | otherwise ->
          Just (WorkerIncomplete "worker turn completed without structured outcome")

classifyPrReviewReviewerTurn :: CommitSha -> AppServerTurn -> Maybe PrReviewObservation
classifyPrReviewReviewerTurn commit turn =
  ObservedReviewerOutcome <$> case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ReviewerBlocked (BlockedReason reason))
    TurnCompleted output
      | Just outcome <- missingOutputBlocked "reviewer turn completed without output" ReviewerBlocked output ->
          Just outcome
      | Just report <- output >>= parseReviewerTurnReport ->
          Just (validateReviewerTurnReport commit report)
      | otherwise ->
          Just (ReviewerIncomplete "reviewer turn completed without reviewer-state JSON")

parseReviewerTurnReport :: Text -> Maybe ReviewerTurnReport
parseReviewerTurnReport output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right report -> Just report

validateReviewerTurnReport :: CommitSha -> ReviewerTurnReport -> ReviewerOutcome
validateReviewerTurnReport expectedCommit report =
  case missingReviewerFields report of
    firstMissing : restMissing ->
      ReviewerIncomplete ("reviewer state missing required fields: " <> Text.intercalate ", " (firstMissing : restMissing))
    [] ->
      validateCompleteReviewerTurnReport expectedCommit report

validateCompleteReviewerTurnReport :: CommitSha -> ReviewerTurnReport -> ReviewerOutcome
validateCompleteReviewerTurnReport expectedCommit report
  | maybe False (< 0) report.reviewerReportAddedCommentCount =
      ReviewerIncomplete "added_review_comment_count must be a non-negative integer"
  | otherwise =
      case normalize (requiredText report.reviewerReportStatus) of
        "blocked" ->
          ReviewerBlocked (BlockedReason (maybe "reviewer marked blocked without a reason" nonEmptyOutput report.reviewerReportBlockedReason))
        "incomplete" ->
          ReviewerIncomplete (maybe "reviewer marked review_status incomplete" nonEmptyOutput report.reviewerReportBlockedReason)
        "clean"
          | report.reviewerReportCommit /= Just expectedCommit ->
              ReviewerIncomplete ("reviewer inspected " <> maybe "missing commit" unCommitSha report.reviewerReportCommit <> ", expected " <> unCommitSha expectedCommit)
          | report.reviewerReportPromptVersion /= Just reviewerPromptVersion ->
              ReviewerIncomplete ("reviewer used prompt version " <> maybe "missing" id report.reviewerReportPromptVersion <> ", expected " <> reviewerPromptVersion)
          | report.reviewerReportAddedCommentCount /= Just 0 ->
              ReviewerIncomplete "clean review must record added_review_comment_count as 0"
          | not (null (requiredRemainingReviewThreads report.reviewerReportRemainingThreads)) ->
              ReviewerIncomplete "clean review must not record remaining_review_threads"
          | hasOverlappingResolution report ->
              ReviewerIncomplete "solved_threads and remaining_review_threads must not overlap"
          | otherwise ->
              ReviewerClean (CleanReviewEvidence expectedCommit (reviewerCleanComment report)) (solvedReviewThreadIds report)
        "new_findings"
          | report.reviewerReportCommit /= Just expectedCommit ->
              ReviewerIncomplete ("reviewer inspected " <> maybe "missing commit" unCommitSha report.reviewerReportCommit <> ", expected " <> unCommitSha expectedCommit)
          | report.reviewerReportPromptVersion /= Just reviewerPromptVersion ->
              ReviewerIncomplete ("reviewer used prompt version " <> maybe "missing" id report.reviewerReportPromptVersion <> ", expected " <> reviewerPromptVersion)
          | not (null (requiredRemainingReviewThreads report.reviewerReportRemainingThreads)) ->
              ReviewerIncomplete "new_findings review must not record remaining_review_threads"
          | hasOverlappingResolution report ->
              ReviewerIncomplete "solved_threads and remaining_review_threads must not overlap"
          | null (requiredFindings report.reviewerReportFindingsSummary) ->
              ReviewerIncomplete "new_findings review must include at least one findings_summary item"
          | otherwise ->
              ReviewerProblemsAdded (reviewEvidenceFromSummaries (firstFinding (requiredFindings report.reviewerReportFindingsSummary)) expectedCommit) (solvedReviewThreadIds report)
        "remaining_findings"
          | report.reviewerReportCommit /= Just expectedCommit ->
              ReviewerIncomplete ("reviewer inspected " <> maybe "missing commit" unCommitSha report.reviewerReportCommit <> ", expected " <> unCommitSha expectedCommit)
          | report.reviewerReportPromptVersion /= Just reviewerPromptVersion ->
              ReviewerIncomplete ("reviewer used prompt version " <> maybe "missing" id report.reviewerReportPromptVersion <> ", expected " <> reviewerPromptVersion)
          | null (requiredRemainingReviewThreads report.reviewerReportRemainingThreads) ->
              ReviewerIncomplete "remaining_findings review must record remaining_review_threads"
          | any (Text.null . Text.strip . remainingReviewThreadComment) (requiredRemainingReviewThreads report.reviewerReportRemainingThreads) ->
              ReviewerIncomplete "remaining_review_threads entries must include non-empty comment"
          | not (null (requiredFindings report.reviewerReportFindingsSummary)) ->
              ReviewerIncomplete "remaining_findings review must leave top-level findings_summary empty; put each remaining prior thread comment in remaining_review_threads"
          | hasOverlappingResolution report ->
              ReviewerIncomplete "solved_threads and remaining_review_threads must not overlap"
          | otherwise ->
              case remainingReviewThreadComments report of
                Just comments -> ReviewerProblemsAdded (reviewEvidenceFromThreadComments comments expectedCommit) (solvedReviewThreadIds report)
                Nothing -> ReviewerIncomplete "remaining_findings review must include remaining_review_threads"
        other ->
          ReviewerIncomplete ("unsupported review_status: " <> other)

missingReviewerFields :: ReviewerTurnReport -> [Text]
missingReviewerFields report =
  concat
    [ missing "review_status" report.reviewerReportStatus
    , missing "reviewed_commit_sha" report.reviewerReportCommit
    , missing "reviewer_prompt_version" report.reviewerReportPromptVersion
    , missing "added_review_comment_count" report.reviewerReportAddedCommentCount
    , missingPresence "lgtm_comment" report.reviewerReportLgtmCommentPresent
    , missing "findings_summary" report.reviewerReportFindingsSummary
    , missingPresence "blocked_reason" report.reviewerReportBlockedReasonPresent
    , missing "solved_threads" report.reviewerReportSolvedThreads
    , missing "remaining_review_threads" report.reviewerReportRemainingThreads
    ]
 where
  missing _fieldName (Just _) = []
  missing fieldName Nothing = [fieldName]
  missingPresence fieldName present
    | present = []
    | otherwise = [fieldName]

requiredText :: Maybe Text -> Text
requiredText =
  maybe "" id

requiredSolvedReviewThreads :: Maybe [SolvedReviewThread] -> [SolvedReviewThread]
requiredSolvedReviewThreads =
  maybe [] id

requiredRemainingReviewThreads :: Maybe [RemainingReviewThread] -> [RemainingReviewThread]
requiredRemainingReviewThreads =
  maybe [] id

solvedReviewThreadIds :: ReviewerTurnReport -> [ReviewThreadId]
solvedReviewThreadIds report =
  fmap solvedReviewThreadId (requiredSolvedReviewThreads report.reviewerReportSolvedThreads)

remainingReviewThreadIds :: ReviewerTurnReport -> [ReviewThreadId]
remainingReviewThreadIds report =
  fmap remainingReviewThreadId (requiredRemainingReviewThreads report.reviewerReportRemainingThreads)

remainingReviewThreadComments :: ReviewerTurnReport -> Maybe (NonEmpty (ReviewThreadId, Text))
remainingReviewThreadComments report =
  case fmap threadComment (requiredRemainingReviewThreads report.reviewerReportRemainingThreads) of
    first : rest -> Just (first :| rest)
    [] -> Nothing
 where
  threadComment remainingThread =
    (remainingThread.remainingReviewThreadId, remainingThread.remainingReviewThreadComment)

requiredFindings :: Maybe [Text] -> [Text]
requiredFindings =
  maybe [] (filter (not . Text.null . Text.strip))

firstFinding :: [Text] -> NonEmpty Text
firstFinding [] = "reviewer reported problems" :| []
firstFinding (first : rest) = first :| rest

reviewerCleanComment :: ReviewerTurnReport -> Text
reviewerCleanComment report =
  case Text.strip <$> report.reviewerReportLgtmComment of
    Just comment | not (Text.null comment) -> comment
    _ -> "LGTM"

hasOverlappingResolution :: ReviewerTurnReport -> Bool
hasOverlappingResolution report =
  any (`elem` remainingReviewThreadIds report) (solvedReviewThreadIds report)

classifyStructuredPrReviewWorker :: StructuredTurnOutcome -> Maybe WorkerOutcome
classifyStructuredPrReviewWorker = \case
  StructuredBlocked reason -> Just (WorkerBlocked (BlockedReason reason))
  StructuredIncomplete reason -> Just (WorkerIncomplete reason)
  StructuredComplete _reason -> Just WorkerCompleted
