{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.PrReview.TurnClassifier
  ( classifyPrReviewReviewerTurn
  , classifyPrReviewWorkerTurn
  ) where

import CodexWatcher.Domain.PrReview.Protocol
import CodexWatcher.Domain.PrReview.Watcher
import CodexWatcher.Turn.Classifier.Common
import CodexWatcher.TurnOutput.Version (reviewerPromptVersion)
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)
import CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), ReviewThreadId (..))
import CodexWatcher.Core.Reason (BlockedReason (..))
import CodexWatcher.Domain.PrReview.Types
  ( CleanReviewEvidence (..)
  , NewFindingsStatus (..)
  , PriorFindingsStatus (..)
  , ReviewEvidence (..)
  , ReviewFinding (..)
  , parseNewFindingsStatus
  , parsePriorFindingsStatus
  )
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:), (.:?))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding

data RawReviewerTurnReport = RawReviewerTurnReport
  { rawReviewerReportCommit :: Maybe CommitSha
  , rawReviewerReportPromptVersion :: Maybe Text
  , rawReviewerReportAddedCommentCount :: Maybe Int
  , rawReviewerReportPriorFindingsStatus :: Maybe Text
  , rawReviewerReportNewFindingsStatus :: Maybe Text
  , rawReviewerReportLgtmCommentPresent :: Bool
  , rawReviewerReportLgtmComment :: Maybe Text
  , rawReviewerReportPriorFindingsSummary :: Maybe [Text]
  , rawReviewerReportNewFindingsSummary :: Maybe [Text]
  , rawReviewerReportBlockedReasonPresent :: Bool
  , rawReviewerReportBlockedReason :: Maybe Text
  , rawReviewerReportSolvedThreads :: Maybe [SolvedReviewThread]
  , rawReviewerReportRemainingThreads :: Maybe [RemainingReviewThread]
  }
  deriving stock (Eq, Show)

data RequiredReviewerTurnReport = RequiredReviewerTurnReport
  { requiredReviewerReportCommit :: CommitSha
  , requiredReviewerReportPromptVersion :: Text
  , requiredReviewerReportAddedCommentCount :: Int
  , requiredReviewerReportPriorFindingsStatus :: Text
  , requiredReviewerReportNewFindingsStatus :: Text
  , requiredReviewerReportLgtmComment :: Maybe Text
  , requiredReviewerReportPriorFindingsSummary :: [Text]
  , requiredReviewerReportNewFindingsSummary :: [Text]
  , requiredReviewerReportBlockedReason :: Maybe Text
  , requiredReviewerReportSolvedThreads :: [SolvedReviewThread]
  , requiredReviewerReportRemainingThreads :: [RemainingReviewThread]
  }
  deriving stock (Eq, Show)

data PriorReviewResult
  = NoPriorFeedback
  | PriorFeedbackResolved [SolvedReviewThread]
  | PriorFeedbackUnresolved (NonEmpty ReviewFinding) [SolvedReviewThread]
  deriving stock (Eq, Show)

data NewReviewResult
  = NoNewReviewFindings
  | NewReviewFindings (NonEmpty Text)
  deriving stock (Eq, Show)

data ValidReviewerTurnReport = ValidReviewerTurnReport
  { validReviewerReportAddedCommentCount :: Int
  , validReviewerReportPriorResult :: PriorReviewResult
  , validReviewerReportNewResult :: NewReviewResult
  , validReviewerReportLgtmComment :: Maybe Text
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

instance FromJSON RawReviewerTurnReport where
  parseJSON = withObject "RawReviewerTurnReport" \objectValue -> do
    let has key = KeyMap.member (Key.fromString key) objectValue
    RawReviewerTurnReport
      <$> (fmap CommitSha <$> objectValue .:? "reviewed_commit_sha")
      <*> objectValue .:? "reviewer_prompt_version"
      <*> objectValue .:? "added_review_comment_count"
      <*> objectValue .:? "prior_findings_status"
      <*> objectValue .:? "new_findings_status"
      <*> pure (has "lgtm_comment")
      <*> objectValue .:? "lgtm_comment"
      <*> objectValue .:? "prior_findings_summary"
      <*> objectValue .:? "new_findings_summary"
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

parseReviewerTurnReport :: Text -> Maybe RawReviewerTurnReport
parseReviewerTurnReport output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right report -> Just report

validateReviewerTurnReport :: CommitSha -> RawReviewerTurnReport -> ReviewerOutcome
validateReviewerTurnReport expectedCommit rawReport =
  case requireReviewerTurnReport rawReport of
    Left missingFields ->
      ReviewerIncomplete ("reviewer state missing required fields: " <> Text.intercalate ", " missingFields)
    Right report ->
      case validateRequiredReviewerTurnReport expectedCommit report of
        Left outcome -> outcome
        Right validReport -> reviewerOutcomeFromValidReport expectedCommit validReport

requireReviewerTurnReport :: RawReviewerTurnReport -> Either [Text] RequiredReviewerTurnReport
requireReviewerTurnReport report =
  case missingReviewerFields report of
    [] ->
      case
        ( rawReviewerReportCommit report
        , rawReviewerReportPromptVersion report
        , rawReviewerReportAddedCommentCount report
        , rawReviewerReportPriorFindingsStatus report
        , rawReviewerReportNewFindingsStatus report
        , rawReviewerReportPriorFindingsSummary report
        , rawReviewerReportNewFindingsSummary report
        , rawReviewerReportSolvedThreads report
        , rawReviewerReportRemainingThreads report
        )
      of
        (Just commit, Just promptVersion, Just commentCount, Just priorStatus, Just newStatus, Just priorSummary, Just newSummary, Just solvedThreads, Just remainingThreads) ->
          Right
            RequiredReviewerTurnReport
              { requiredReviewerReportCommit = commit
              , requiredReviewerReportPromptVersion = promptVersion
              , requiredReviewerReportAddedCommentCount = commentCount
              , requiredReviewerReportPriorFindingsStatus = priorStatus
              , requiredReviewerReportNewFindingsStatus = newStatus
              , requiredReviewerReportLgtmComment = rawReviewerReportLgtmComment report
              , requiredReviewerReportPriorFindingsSummary = priorSummary
              , requiredReviewerReportNewFindingsSummary = newSummary
              , requiredReviewerReportBlockedReason = rawReviewerReportBlockedReason report
              , requiredReviewerReportSolvedThreads = solvedThreads
              , requiredReviewerReportRemainingThreads = remainingThreads
              }
        _ -> Left ["internal reviewer state presence validation failed"]
    missingFields -> Left missingFields

validateRequiredReviewerTurnReport :: CommitSha -> RequiredReviewerTurnReport -> Either ReviewerOutcome ValidReviewerTurnReport
validateRequiredReviewerTurnReport expectedCommit report
  | report.requiredReviewerReportAddedCommentCount < 0 =
      Left (ReviewerIncomplete "added_review_comment_count must be a non-negative integer")
  | report.requiredReviewerReportCommit /= expectedCommit =
      Left (ReviewerIncomplete ("reviewer inspected " <> unCommitSha report.requiredReviewerReportCommit <> ", expected " <> unCommitSha expectedCommit))
  | report.requiredReviewerReportPromptVersion /= reviewerPromptVersion =
      Left (ReviewerIncomplete ("reviewer used prompt version " <> report.requiredReviewerReportPromptVersion <> ", expected " <> reviewerPromptVersion))
  | hasOverlappingResolution report =
      Left (ReviewerIncomplete "solved_threads and remaining_review_threads must not overlap")
  | otherwise =
      case (parsePriorFindingsStatus report.requiredReviewerReportPriorFindingsStatus, parseNewFindingsStatus report.requiredReviewerReportNewFindingsStatus) of
        (Nothing, _) ->
          Left (ReviewerIncomplete ("unsupported prior_findings_status: " <> normalize report.requiredReviewerReportPriorFindingsStatus))
        (_, Nothing) ->
          Left (ReviewerIncomplete ("unsupported new_findings_status: " <> normalize report.requiredReviewerReportNewFindingsStatus))
        (Just PriorFindingsBlocked, _) ->
          Left (ReviewerBlocked (BlockedReason (maybe "reviewer marked blocked without a reason" id blockedReason)))
        (_, Just NewFindingsBlocked) ->
          Left (ReviewerBlocked (BlockedReason (maybe "reviewer marked blocked without a reason" id blockedReason)))
        (Just PriorFindingsInconclusive, _) ->
          Left (ReviewerIncomplete (maybe "reviewer marked findings status inconclusive" id blockedReason))
        (_, Just NewFindingsInconclusive) ->
          Left (ReviewerIncomplete (maybe "reviewer marked findings status inconclusive" id blockedReason))
        (Just priorStatus, Just newStatus) ->
          case (buildPriorReviewResult priorStatus report, buildNewReviewResult newStatus report) of
            (Left reason, _) -> Left (ReviewerIncomplete reason)
            (_, Left reason) -> Left (ReviewerIncomplete reason)
            (Right priorResult, Right newResult) ->
              Right
                ValidReviewerTurnReport
                  { validReviewerReportAddedCommentCount = report.requiredReviewerReportAddedCommentCount
                  , validReviewerReportPriorResult = priorResult
                  , validReviewerReportNewResult = newResult
                  , validReviewerReportLgtmComment = report.requiredReviewerReportLgtmComment
                  }
 where
  blockedReason = nonEmptyOutput <$> report.requiredReviewerReportBlockedReason

reviewerOutcomeFromValidReport :: CommitSha -> ValidReviewerTurnReport -> ReviewerOutcome
reviewerOutcomeFromValidReport expectedCommit report
  | isCleanReviewerReport report =
      if report.validReviewerReportAddedCommentCount == 0
        then ReviewerClean (CleanReviewEvidence expectedCommit (reviewerCleanComment report)) (priorReviewSolvedThreadIds report.validReviewerReportPriorResult)
        else ReviewerIncomplete "clean review must record added_review_comment_count as 0"
  | otherwise =
      case reviewerProblemEvidence report expectedCommit of
        Just evidence -> ReviewerProblemsAdded evidence (priorReviewSolvedThreadIds report.validReviewerReportPriorResult)
        Nothing -> ReviewerIncomplete "reviewer reported findings status without actionable findings"

missingReviewerFields :: RawReviewerTurnReport -> [Text]
missingReviewerFields report =
  concat
    [ missing "reviewed_commit_sha" report.rawReviewerReportCommit
    , missing "reviewer_prompt_version" report.rawReviewerReportPromptVersion
    , missing "added_review_comment_count" report.rawReviewerReportAddedCommentCount
    , missing "prior_findings_status" report.rawReviewerReportPriorFindingsStatus
    , missing "new_findings_status" report.rawReviewerReportNewFindingsStatus
    , missingPresence "lgtm_comment" report.rawReviewerReportLgtmCommentPresent
    , missing "prior_findings_summary" report.rawReviewerReportPriorFindingsSummary
    , missing "new_findings_summary" report.rawReviewerReportNewFindingsSummary
    , missingPresence "blocked_reason" report.rawReviewerReportBlockedReasonPresent
    , missing "solved_threads" report.rawReviewerReportSolvedThreads
    , missing "remaining_review_threads" report.rawReviewerReportRemainingThreads
    ]
 where
  missing _fieldName (Just _) = []
  missing fieldName Nothing = [fieldName]
  missingPresence fieldName present
    | present = []
    | otherwise = [fieldName]

buildPriorReviewResult :: PriorFindingsStatus -> RequiredReviewerTurnReport -> Either Text PriorReviewResult
buildPriorReviewResult status report =
  case status of
    PriorFindingsNotApplicable
      | not (null solvedThreads) ->
          Left "solved_threads require prior_findings_status=resolved or unresolved"
      | not (null remainingThreads) ->
          Left "remaining_review_threads require prior_findings_status=unresolved"
      | not (null priorFindings) ->
          Left "prior_findings_summary requires prior_findings_status=unresolved"
      | otherwise ->
          Right NoPriorFeedback
    PriorFindingsResolved
      | not (null remainingThreads) ->
          Left "remaining_review_threads require prior_findings_status=unresolved"
      | otherwise ->
          Right (PriorFeedbackResolved solvedThreads)
    PriorFindingsUnresolved
      | any (Text.null . Text.strip . remainingReviewThreadComment) remainingThreads ->
          Left "remaining_review_threads entries must include non-empty comment"
      | otherwise ->
          case nonEmptyList (priorReviewFindings report) of
            Nothing -> Left "prior_findings_status=unresolved requires remaining_review_threads or prior_findings_summary"
            Just findings -> Right (PriorFeedbackUnresolved findings solvedThreads)
    PriorFindingsInconclusive ->
      Left "reviewer marked findings status inconclusive"
    PriorFindingsBlocked ->
      Left "reviewer marked blocked without a reason"
 where
  solvedThreads = report.requiredReviewerReportSolvedThreads
  remainingThreads = report.requiredReviewerReportRemainingThreads
  priorFindings = requiredFindings report.requiredReviewerReportPriorFindingsSummary

buildNewReviewResult :: NewFindingsStatus -> RequiredReviewerTurnReport -> Either Text NewReviewResult
buildNewReviewResult status report =
  case status of
    NewFindingsNone
      | not (null findings) ->
          Left "new_findings_summary requires new_findings_status=found"
      | otherwise ->
          Right NoNewReviewFindings
    NewFindingsFound ->
      case nonEmptyList findings of
        Nothing -> Left "new_findings_status=found requires at least one new_findings_summary item"
        Just summaries -> Right (NewReviewFindings summaries)
    NewFindingsInconclusive ->
      Left "reviewer marked findings status inconclusive"
    NewFindingsBlocked ->
      Left "reviewer marked blocked without a reason"
 where
  findings = requiredFindings report.requiredReviewerReportNewFindingsSummary

isCleanReviewerReport :: ValidReviewerTurnReport -> Bool
isCleanReviewerReport report =
  case (report.validReviewerReportPriorResult, report.validReviewerReportNewResult) of
    (NoPriorFeedback, NoNewReviewFindings) -> True
    (PriorFeedbackResolved {}, NoNewReviewFindings) -> True
    _ -> False

priorReviewSolvedThreadIds :: PriorReviewResult -> [ReviewThreadId]
priorReviewSolvedThreadIds = \case
  NoPriorFeedback -> []
  PriorFeedbackResolved solvedThreads -> fmap solvedReviewThreadId solvedThreads
  PriorFeedbackUnresolved _findings solvedThreads -> fmap solvedReviewThreadId solvedThreads

reviewerProblemEvidence :: ValidReviewerTurnReport -> CommitSha -> Maybe ReviewEvidence
reviewerProblemEvidence report commit =
  case priorFindings <> newFindings of
    [] -> Nothing
    first : rest -> Just (ReviewEvidence (first :| rest) commit)
 where
  priorFindings =
    case report.validReviewerReportPriorResult of
      PriorFeedbackUnresolved findings _solvedThreads -> NonEmpty.toList findings
      _ -> []
  newFindings =
    case report.validReviewerReportNewResult of
      NewReviewFindings summaries -> ReviewSummaryFinding <$> NonEmpty.toList summaries
      NoNewReviewFindings -> []

priorReviewFindings :: RequiredReviewerTurnReport -> [ReviewFinding]
priorReviewFindings report =
  remainingThreadFindings <> priorSummaryFindings
 where
  remainingThreadFindings =
    [ ReviewThreadCommentFinding thread.remainingReviewThreadId Nothing thread.remainingReviewThreadComment
    | thread <- report.requiredReviewerReportRemainingThreads
    ]
  priorSummaryFindings =
    ReviewSummaryFinding <$> requiredFindings report.requiredReviewerReportPriorFindingsSummary

requiredFindings :: [Text] -> [Text]
requiredFindings =
  filter (not . Text.null . Text.strip)

reviewerCleanComment :: ValidReviewerTurnReport -> Text
reviewerCleanComment report =
  case Text.strip <$> report.validReviewerReportLgtmComment of
    Just comment | not (Text.null comment) -> comment
    _ -> "LGTM"

hasOverlappingResolution :: RequiredReviewerTurnReport -> Bool
hasOverlappingResolution report =
  any (`elem` remainingReviewThreadIds) solvedReviewThreadIds
 where
  solvedReviewThreadIds = fmap solvedReviewThreadId report.requiredReviewerReportSolvedThreads
  remainingReviewThreadIds = fmap remainingReviewThreadId report.requiredReviewerReportRemainingThreads

nonEmptyList :: [a] -> Maybe (NonEmpty a)
nonEmptyList [] = Nothing
nonEmptyList (first : rest) = Just (first :| rest)

classifyStructuredPrReviewWorker :: StructuredTurnOutcome -> Maybe WorkerOutcome
classifyStructuredPrReviewWorker = \case
  StructuredBlocked reason -> Just (WorkerBlocked (BlockedReason reason))
  StructuredIncomplete reason -> Just (WorkerIncomplete reason)
  StructuredComplete _reason -> Just WorkerCompleted
