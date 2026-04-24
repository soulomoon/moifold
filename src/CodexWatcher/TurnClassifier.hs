{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.TurnClassifier
  ( TurnCompletion (..)
  , StructuredTurnOutcome (..)
  , classifyIssueImplementationTurn
  , classifyIssuePlanningTurn
  , classifyIssuePlanTurn
  , classifyPrReviewReviewerTurn
  , classifyPrReviewWorkerTurn
  , classifyTurnCompletion
  , parseStructuredTurnOutcome
  ) where

import CodexWatcher.AppServerClient
import CodexWatcher.IssueImplementWatcher
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.PrReviewWatcher
import CodexWatcher.Protocol
import CodexWatcher.TurnOutput (reviewerPromptVersion)
import CodexWatcher.Types
import Data.Aeson (FromJSON (..), Value (..), eitherDecodeStrict', withObject, (.:), (.:?), (.!=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List (find)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding

data TurnCompletion
  = TurnStillRunning
  | TurnCompleted (Maybe Text)
  | TurnFailed Text
  deriving stock (Eq, Show)

data StructuredTurnOutcome
  = StructuredBlocked Text
  | StructuredIncomplete Text
  | StructuredComplete Text
  deriving stock (Eq, Show)

data StructuredOutcomeSpec = StructuredOutcomeSpec
  { structuredOutcomeAliases :: [Text]
  , structuredOutcomeConstructor :: Text -> StructuredTurnOutcome
  }

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

data IssuePlanTurnReport = IssuePlanTurnReport
  { issuePlanReportOutcome :: Text
  , issuePlanReportReason :: Text
  , issuePlanReportSummary :: Text
  , issuePlanReportMarkdown :: Text
  }
  deriving stock (Eq, Show)

newtype StructuredPlanningIssueRequests = StructuredPlanningIssueRequests (NonEmpty IssueCreationRequest)
  deriving stock (Eq, Show)

newtype StructuredPlanningGraph = StructuredPlanningGraph PlanningGraph
  deriving stock (Eq, Show)

instance FromJSON StructuredPlanningIssueRequests where
  parseJSON = withObject "StructuredPlanningIssueRequests" \objectValue -> do
    issues <- objectValue .:? "issues_to_create" .!= []
    subissues <- objectValue .:? "subissues_to_create" .!= []
    case issues <> subissues of
      firstRequest : restRequests -> pure (StructuredPlanningIssueRequests (firstRequest :| restRequests))
      [] -> fail "issues_to_create and subissues_to_create must not both be empty"

instance FromJSON StructuredPlanningGraph where
  parseJSON = withObject "StructuredPlanningGraph" \objectValue ->
    if hasPlanningGraphFields objectValue
      then StructuredPlanningGraph <$> parseJSON (Object objectValue)
      else fail "missing planning graph fields"

instance FromJSON IssuePlanTurnReport where
  parseJSON = withObject "IssuePlanTurnReport" \objectValue ->
    IssuePlanTurnReport
      <$> objectValue .: "outcome"
      <*> objectValue .: "reason"
      <*> objectValue .: "summary"
      <*> objectValue .: "plan_markdown"

instance FromJSON StructuredTurnOutcome where
  parseJSON = withObject "StructuredTurnOutcome" \objectValue -> do
    maybeOutcome <- objectValue .:? "outcome"
    outcome <- maybe (fail "missing outcome") pure (firstNonEmpty [maybeOutcome])
    reason <- objectValue .:? "reason"
    summary <- objectValue .:? "summary"
    comment <- objectValue .:? "comment"
    evidence <- objectValue .:? "evidence"
    detail <- maybe (fail "missing structured outcome detail") pure (firstNonEmpty [reason, summary, comment, evidence])
    case find (matchesStructuredOutcome (normalize outcome)) structuredOutcomeSpecs of
      Just spec -> pure (spec.structuredOutcomeConstructor detail)
      Nothing -> fail ("unsupported structured turn outcome: " <> Text.unpack (normalize outcome))

matchesStructuredOutcome :: Text -> StructuredOutcomeSpec -> Bool
matchesStructuredOutcome outcome spec =
  outcome `elem` spec.structuredOutcomeAliases

structuredOutcomeSpecs :: [StructuredOutcomeSpec]
structuredOutcomeSpecs =
  [ StructuredOutcomeSpec ["blocked"] StructuredBlocked
  , StructuredOutcomeSpec ["incomplete"] StructuredIncomplete
  , StructuredOutcomeSpec ["complete"] StructuredComplete
  ]

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

classifyTurnCompletion :: AppServerTurn -> TurnCompletion
classifyTurnCompletion turn
  | normalizedStatus `elem` runningStatuses = TurnStillRunning
  | normalizedStatus `elem` completedStatuses = TurnCompleted turn.appServerTurnOutput
  | normalizedStatus `elem` failedStatuses = TurnFailed (reason "turn ended unsuccessfully")
  | otherwise = TurnStillRunning
 where
  normalizedStatus = normalize turn.appServerTurnStatus
  reason fallback = maybe fallback nonEmptyOutput turn.appServerTurnOutput

classifyIssuePlanningTurn :: AppServerTurn -> Maybe IssuePlanningObservation
classifyIssuePlanningTurn turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedPlanningBlocked (BlockedReason reason))
    TurnCompleted output
      | Just observation <- missingOutputBlocked "planning turn completed without output" ObservedPlanningBlocked output ->
          Just observation
      | Just requests <- output >>= parsePlanningIssueRequests ->
          Just (ObservedPlanningIssuesRequested requests)
      | Just outputText <- output
      , planningIssueRequestPayloadInvalid outputText ->
          Just (ObservedPlanningBlocked (BlockedReason "planning turn returned invalid issue creation payload"))
      | Just graph <- output >>= parsePlanningGraph ->
          Just (ObservedPlanningGraphUpdated graph)
      | Just structured <- output >>= parseStructuredTurnOutcome ->
          classifyStructuredIssuePlanning structured
      | otherwise ->
          Just (ObservedPlanningBlocked (BlockedReason "planning turn completed without structured outcome"))

classifyIssuePlanTurn :: AppServerTurn -> Maybe IssueImplementObservation
classifyIssuePlanTurn turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedIssueImplementBlocked (BlockedReason reason))
    TurnCompleted output
      | Just observation <- missingOutputBlocked "plan turn completed without output" ObservedIssueImplementBlocked output ->
          Just observation
      | Just report <- output >>= parseIssuePlanTurnReport ->
          classifyIssuePlanReport report
      | otherwise ->
          Just (ObservedIssueImplementBlocked (BlockedReason "plan turn completed without structured plan output"))

classifyIssueImplementationTurn :: Maybe PrNumber -> AppServerTurn -> Maybe IssueImplementObservation
classifyIssueImplementationTurn maybePr turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedImplementationBlocked (BlockedReason reason))
    TurnCompleted output
      | Just observation <- missingOutputBlocked "implementation turn completed without output" ObservedImplementationBlocked output ->
          Just observation
      | Just structured <- output >>= parseStructuredTurnOutcome ->
          classifyStructuredIssueImplementation maybePr structured
      | otherwise ->
          Just (ObservedImplementationIncomplete "implementation turn completed without structured outcome")

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

parseStructuredTurnOutcome :: Text -> Maybe StructuredTurnOutcome
parseStructuredTurnOutcome output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right structured -> Just structured

parsePlanningIssueRequests :: Text -> Maybe (NonEmpty IssueCreationRequest)
parsePlanningIssueRequests output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right (StructuredPlanningIssueRequests requests) -> Just requests

parsePlanningGraph :: Text -> Maybe PlanningGraph
parsePlanningGraph output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right (StructuredPlanningGraph graph) -> Just graph

parseIssuePlanTurnReport :: Text -> Maybe IssuePlanTurnReport
parseIssuePlanTurnReport output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right report -> Just report

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

planningIssueRequestPayloadInvalid :: Text -> Bool
planningIssueRequestPayloadInvalid output =
  case eitherDecodeStrict' bytes :: Either String StructuredPlanningIssueRequests of
    Right _ -> False
    Left _ ->
      case eitherDecodeStrict' bytes :: Either String Value of
        Right (Object objectValue) ->
          any
            (`KeyMap.member` objectValue)
            [ Key.fromString "issues_to_create"
            , Key.fromString "subissues_to_create"
            ]
        _ -> False
 where
  bytes = Text.Encoding.encodeUtf8 (Text.strip output)

hasPlanningGraphFields :: KeyMap.KeyMap Value -> Bool
hasPlanningGraphFields objectValue =
  any
    (`KeyMap.member` objectValue)
    [ Key.fromString "ready_issues"
    , Key.fromString "blocked_issues"
    , Key.fromString "dependencies"
    ]

classifyStructuredIssuePlanning :: StructuredTurnOutcome -> Maybe IssuePlanningObservation
classifyStructuredIssuePlanning structured =
  maybe
    (Just ObservedPlanningTurnCompleted)
    Just
    (structuredBlockedLikeObservation ObservedPlanningBlocked structured)

classifyIssuePlanReport :: IssuePlanTurnReport -> Maybe IssueImplementObservation
classifyIssuePlanReport report =
  case normalize report.issuePlanReportOutcome of
    "complete"
      | Text.null planMarkdown ->
          Just (ObservedIssueImplementBlocked (BlockedReason "plan turn completed with empty plan_markdown"))
      | otherwise ->
          Just (ObservedPlanCompleted planMarkdown Nothing)
    "blocked" ->
      Just (ObservedIssueImplementBlocked (BlockedReason (nonEmptyDetail "plan turn blocked without reason" report.issuePlanReportReason)))
    _ ->
      Just (ObservedIssueImplementBlocked (BlockedReason ("unsupported issue plan outcome: " <> report.issuePlanReportOutcome)))
 where
  planMarkdown = Text.strip report.issuePlanReportMarkdown
  nonEmptyDetail fallback detail =
    case Text.strip detail of
      "" -> fallback
      stripped -> stripped

classifyStructuredIssueImplementation :: Maybe PrNumber -> StructuredTurnOutcome -> Maybe IssueImplementObservation
classifyStructuredIssueImplementation maybePr = \case
  StructuredBlocked reason -> Just (ObservedImplementationBlocked (BlockedReason reason))
  StructuredIncomplete reason -> Just (ObservedImplementationIncomplete reason)
  StructuredComplete _reason ->
    Just (completedImplementationObservation maybePr)

classifyStructuredPrReviewWorker :: StructuredTurnOutcome -> Maybe WorkerOutcome
classifyStructuredPrReviewWorker = \case
  StructuredBlocked reason -> Just (WorkerBlocked (BlockedReason reason))
  StructuredIncomplete reason -> Just (WorkerIncomplete reason)
  StructuredComplete _reason -> Just WorkerCompleted

structuredBlockedLikeObservation :: (BlockedReason -> observation) -> StructuredTurnOutcome -> Maybe observation
structuredBlockedLikeObservation toObservation = \case
  StructuredBlocked reason -> Just (toObservation (BlockedReason reason))
  StructuredIncomplete reason -> Just (toObservation (BlockedReason reason))
  _ -> Nothing

completedImplementationObservation :: Maybe PrNumber -> IssueImplementObservation
completedImplementationObservation = \case
  Just prNumber -> ObservedImplementationCompleted prNumber
  Nothing -> ObservedImplementationIncomplete "implementation completed before a pull request was known"

runningStatuses :: [Text]
runningStatuses =
  ["", "unknown", "queued", "created", "starting", "running", "in_progress", "in-progress", "pending"]

completedStatuses :: [Text]
completedStatuses =
  ["complete", "completed", "done", "success", "succeeded", "finished"]

failedStatuses :: [Text]
failedStatuses =
  ["failed", "failure", "error", "errored", "cancelled", "canceled", "interrupted", "aborted"]

missingOutputBlocked :: Text -> (BlockedReason -> observation) -> Maybe Text -> Maybe observation
missingOutputBlocked fallback toObservation output
  | hasMeaningfulOutput output = Nothing
  | otherwise = Just (toObservation (BlockedReason fallback))

hasMeaningfulOutput :: Maybe Text -> Bool
hasMeaningfulOutput =
  maybe False (not . Text.null . Text.strip)

firstNonEmpty :: [Maybe Text] -> Maybe Text
firstNonEmpty [] = Nothing
firstNonEmpty (Nothing : rest) = firstNonEmpty rest
firstNonEmpty (Just text : rest)
  | Text.null (Text.strip text) = firstNonEmpty rest
  | otherwise = Just (Text.strip text)

nonEmptyOutput :: Text -> Text
nonEmptyOutput output
  | Text.null stripped = "empty app-server turn output"
  | otherwise = stripped
 where
  stripped = Text.strip output

normalize :: Text -> Text
normalize =
  Text.toLower . Text.strip
