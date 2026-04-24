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
import CodexWatcher.Types
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:?))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
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
  }
  deriving stock (Eq, Show)

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

classifyPrReviewWorkerTurn :: AppServerTurn -> Maybe PrReviewObservation
classifyPrReviewWorkerTurn turn =
  ObservedWorkerOutcome <$> case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (WorkerBlocked (BlockedReason reason))
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
          | report.reviewerReportLgtmComment /= Just "LGTM" ->
              ReviewerIncomplete "clean review must record lgtm_comment as LGTM"
          | otherwise ->
              ReviewerClean (CleanReviewEvidence expectedCommit "LGTM")
        "comments_added"
          | report.reviewerReportCommit /= Just expectedCommit ->
              ReviewerIncomplete ("reviewer inspected " <> maybe "missing commit" unCommitSha report.reviewerReportCommit <> ", expected " <> unCommitSha expectedCommit)
          | report.reviewerReportPromptVersion /= Just reviewerPromptVersion ->
              ReviewerIncomplete ("reviewer used prompt version " <> maybe "missing" id report.reviewerReportPromptVersion <> ", expected " <> reviewerPromptVersion)
          | maybe True (< 1) report.reviewerReportAddedCommentCount ->
              ReviewerIncomplete "comments_added review must record at least one added review comment"
          | otherwise ->
              ReviewerProblemsAdded expectedCommit
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

classifyStructuredPrReviewWorker :: StructuredTurnOutcome -> Maybe WorkerOutcome
classifyStructuredPrReviewWorker = \case
  StructuredBlocked reason -> Just (WorkerBlocked (BlockedReason reason))
  StructuredIncomplete reason -> Just (WorkerIncomplete reason)
  StructuredComplete _reason -> Just WorkerCompleted
