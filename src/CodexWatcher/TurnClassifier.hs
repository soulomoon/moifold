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
  , classifyIssueTriageTurn
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
import CodexWatcher.Types
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:?), (.!=))
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
  | StructuredAlreadyFixed Text
  | StructuredNeedsImplementation Text
  | StructuredProblems Text
  | StructuredClean Text
  deriving stock (Eq, Show)

newtype StructuredPlanningIssueRequests = StructuredPlanningIssueRequests [IssueCreationRequest]
  deriving stock (Eq, Show)

instance FromJSON StructuredPlanningIssueRequests where
  parseJSON = withObject "StructuredPlanningIssueRequests" \objectValue -> do
    issues <- objectValue .:? "issues_to_create" .!= []
    subissues <- objectValue .:? "subissues_to_create" .!= []
    pure (StructuredPlanningIssueRequests (issues <> subissues))

instance FromJSON StructuredTurnOutcome where
  parseJSON = withObject "StructuredTurnOutcome" \objectValue -> do
    maybeOutcome <- objectValue .:? "outcome"
    maybeStatus <- objectValue .:? "status"
    maybeResult <- objectValue .:? "result"
    outcome <- maybe (fail "missing outcome/status/result") pure (firstNonEmpty [maybeOutcome, maybeStatus, maybeResult])
    reason <- objectValue .:? "reason"
    summary <- objectValue .:? "summary"
    comment <- objectValue .:? "comment"
    evidence <- objectValue .:? "evidence"
    let detail = firstNonEmpty [reason, summary, comment, evidence]
        withDetail constructor fallback = pure (constructor (maybe fallback id detail))
    case normalize outcome of
      "blocked" -> withDetail StructuredBlocked "blocked"
      "cannot_proceed" -> withDetail StructuredBlocked "cannot proceed"
      "cannot proceed" -> withDetail StructuredBlocked "cannot proceed"
      "incomplete" -> withDetail StructuredIncomplete "incomplete"
      "not_complete" -> withDetail StructuredIncomplete "not complete"
      "not complete" -> withDetail StructuredIncomplete "not complete"
      "needs_follow_up" -> withDetail StructuredIncomplete "needs follow-up"
      "needs follow-up" -> withDetail StructuredIncomplete "needs follow-up"
      "complete" -> withDetail StructuredComplete "complete"
      "completed" -> withDetail StructuredComplete "complete"
      "success" -> withDetail StructuredComplete "complete"
      "ready_for_review" -> withDetail StructuredComplete "ready for review"
      "ready for review" -> withDetail StructuredComplete "ready for review"
      "pr_ready" -> withDetail StructuredComplete "PR ready"
      "already_fixed" -> withDetail StructuredAlreadyFixed "already fixed"
      "already fixed" -> withDetail StructuredAlreadyFixed "already fixed"
      "already_resolved" -> withDetail StructuredAlreadyFixed "already resolved"
      "already resolved" -> withDetail StructuredAlreadyFixed "already resolved"
      "no_changes_needed" -> withDetail StructuredAlreadyFixed "no changes needed"
      "needs_implementation" -> withDetail StructuredNeedsImplementation "needs implementation"
      "needs implementation" -> withDetail StructuredNeedsImplementation "needs implementation"
      "implement" -> withDetail StructuredNeedsImplementation "needs implementation"
      "problems" -> withDetail StructuredProblems "problems found"
      "problem" -> withDetail StructuredProblems "problems found"
      "comments_added" -> withDetail StructuredProblems "comments added"
      "comments added" -> withDetail StructuredProblems "comments added"
      "changes_requested" -> withDetail StructuredProblems "changes requested"
      "changes requested" -> withDetail StructuredProblems "changes requested"
      "clean" -> withDetail StructuredClean "LGTM"
      "lgtm" -> withDetail StructuredClean "LGTM"
      "approved" -> withDetail StructuredClean "approved"
      "no_issues" -> withDetail StructuredClean "no issues"
      "no issues" -> withDetail StructuredClean "no issues"
      other -> fail ("unsupported structured turn outcome: " <> Text.unpack other)

classifyTurnCompletion :: AppServerTurn -> TurnCompletion
classifyTurnCompletion turn
  | normalizedStatus `elem` runningStatuses = TurnStillRunning
  | normalizedStatus `elem` completedStatuses = TurnCompleted turn.appServerTurnOutput
  | normalizedStatus `elem` failedStatuses = TurnFailed (reason "turn ended unsuccessfully")
  | otherwise = TurnStillRunning
 where
  normalizedStatus = normalize turn.appServerTurnStatus
  reason fallback = maybe fallback nonEmptyOutput turn.appServerTurnOutput

classifyIssueTriageTurn :: AppServerTurn -> Maybe IssueImplementObservation
classifyIssueTriageTurn turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedIssueImplementBlocked (BlockedReason reason))
    TurnCompleted output
      | Just structured <- output >>= parseStructuredTurnOutcome ->
          classifyStructuredIssueTriage structured
      | outputHasAny ["blocked", "cannot proceed"] output ->
          Just (ObservedIssueImplementBlocked (BlockedReason (outputReason "triage turn reported blocked" output)))
      | outputHasAny ["already_fixed", "already fixed", "already_resolved", "already resolved", "no changes needed"] output ->
          Just ObservedTriageAlreadyFixed
      | otherwise ->
          Just ObservedTriageNeedsImplementation

classifyIssuePlanningTurn :: AppServerTurn -> Maybe IssuePlanningObservation
classifyIssuePlanningTurn turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedPlanningBlocked (BlockedReason reason))
    TurnCompleted output
      | Just (firstRequest : restRequests) <- output >>= parsePlanningIssueRequests ->
          Just (ObservedPlanningIssuesRequested (firstRequest : restRequests))
      | Just structured <- output >>= parseStructuredTurnOutcome ->
          classifyStructuredIssuePlanning structured
      | outputHasAny ["blocked", "cannot proceed"] output ->
          Just (ObservedPlanningBlocked (BlockedReason (outputReason "planning turn reported blocked" output)))
      | otherwise ->
          Just ObservedPlanningTurnCompleted

classifyIssuePlanTurn :: AppServerTurn -> Maybe IssueImplementObservation
classifyIssuePlanTurn turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedIssueImplementBlocked (BlockedReason reason))
    TurnCompleted output
      | Just structured <- output >>= parseStructuredTurnOutcome ->
          classifyStructuredIssuePlan structured
      | outputHasAny ["blocked", "cannot proceed"] output ->
          Just (ObservedIssueImplementBlocked (BlockedReason (outputReason "plan turn reported blocked" output)))
      | otherwise ->
          Just (ObservedPlanCompleted Nothing)

classifyIssueImplementationTurn :: Maybe PrNumber -> AppServerTurn -> Maybe IssueImplementObservation
classifyIssueImplementationTurn maybePr turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedImplementationBlocked (BlockedReason reason))
    TurnCompleted output
      | Just structured <- output >>= parseStructuredTurnOutcome ->
          classifyStructuredIssueImplementation maybePr structured
      | outputHasAny ["blocked", "cannot proceed"] output ->
          Just (ObservedImplementationBlocked (BlockedReason (outputReason "implementation turn reported blocked" output)))
      | outputHasAny ["incomplete", "not complete", "needs follow-up", "needs follow up"] output ->
          Just (ObservedImplementationIncomplete (outputReason "implementation turn reported incomplete" output))
      | Just prNumber <- maybePr
      , outputHasAny ["complete", "completed", "ready for review", "review handoff", "pr ready"] output ->
          Just (ObservedImplementationCompleted prNumber)
      | otherwise ->
          Just (ObservedImplementationIncomplete (outputReason "implementation turn completed without a completion marker" output))

classifyPrReviewWorkerTurn :: AppServerTurn -> Maybe PrReviewObservation
classifyPrReviewWorkerTurn turn =
  ObservedWorkerOutcome <$> case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (WorkerBlocked (BlockedReason reason))
    TurnCompleted output
      | Just structured <- output >>= parseStructuredTurnOutcome ->
          classifyStructuredPrReviewWorker structured
      | outputHasAny ["blocked", "cannot proceed"] output ->
          Just (WorkerBlocked (BlockedReason (outputReason "worker turn reported blocked" output)))
      | outputHasAny ["incomplete", "not complete", "needs follow-up", "needs follow up"] output ->
          Just (WorkerIncomplete (outputReason "worker turn reported incomplete" output))
      | otherwise ->
          Just WorkerCompleted

classifyPrReviewReviewerTurn :: CommitSha -> AppServerTurn -> Maybe PrReviewObservation
classifyPrReviewReviewerTurn commit turn =
  ObservedReviewerOutcome <$> case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ReviewerBlocked (BlockedReason reason))
    TurnCompleted output
      | Just structured <- output >>= parseStructuredTurnOutcome ->
          classifyStructuredPrReviewReviewer commit structured
      | outputHasAny ["blocked", "cannot proceed"] output ->
          Just (ReviewerBlocked (BlockedReason (outputReason "reviewer turn reported blocked" output)))
      | outputHasAny ["incomplete", "not complete", "needs follow-up", "needs follow up"] output ->
          Just (ReviewerIncomplete (outputReason "reviewer turn reported incomplete" output))
      | outputHasAny ["problem", "problems", "commented", "comments added", "changes requested"] output ->
          Just (ReviewerProblemsAdded commit)
      | outputHasAny ["clean", "lgtm", "approved", "no issues"] output ->
          Just (ReviewerClean (CleanReviewEvidence commit (outputReason "LGTM" output)))
      | otherwise ->
          Just (ReviewerIncomplete (outputReason "reviewer turn completed without a clean/problems marker" output))

parseStructuredTurnOutcome :: Text -> Maybe StructuredTurnOutcome
parseStructuredTurnOutcome output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right structured -> Just structured

parsePlanningIssueRequests :: Text -> Maybe [IssueCreationRequest]
parsePlanningIssueRequests output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right (StructuredPlanningIssueRequests requests) -> Just requests

classifyStructuredIssuePlanning :: StructuredTurnOutcome -> Maybe IssuePlanningObservation
classifyStructuredIssuePlanning = \case
  StructuredBlocked reason -> Just (ObservedPlanningBlocked (BlockedReason reason))
  StructuredIncomplete reason -> Just (ObservedPlanningBlocked (BlockedReason reason))
  StructuredProblems reason -> Just (ObservedPlanningBlocked (BlockedReason reason))
  StructuredComplete _reason -> Just ObservedPlanningTurnCompleted
  StructuredNeedsImplementation _reason -> Just ObservedPlanningTurnCompleted
  StructuredAlreadyFixed _reason -> Just ObservedPlanningTurnCompleted
  StructuredClean _reason -> Just ObservedPlanningTurnCompleted

classifyStructuredIssueTriage :: StructuredTurnOutcome -> Maybe IssueImplementObservation
classifyStructuredIssueTriage = \case
  StructuredBlocked reason -> Just (ObservedIssueImplementBlocked (BlockedReason reason))
  StructuredAlreadyFixed _reason -> Just ObservedTriageAlreadyFixed
  StructuredNeedsImplementation _reason -> Just ObservedTriageNeedsImplementation
  StructuredComplete _reason -> Just ObservedTriageNeedsImplementation
  StructuredIncomplete reason -> Just (ObservedIssueImplementBlocked (BlockedReason reason))
  StructuredProblems reason -> Just (ObservedIssueImplementBlocked (BlockedReason reason))
  StructuredClean _reason -> Just ObservedTriageAlreadyFixed

classifyStructuredIssuePlan :: StructuredTurnOutcome -> Maybe IssueImplementObservation
classifyStructuredIssuePlan = \case
  StructuredBlocked reason -> Just (ObservedIssueImplementBlocked (BlockedReason reason))
  StructuredIncomplete reason -> Just (ObservedIssueImplementBlocked (BlockedReason reason))
  StructuredComplete _reason -> Just (ObservedPlanCompleted Nothing)
  StructuredNeedsImplementation _reason -> Just (ObservedPlanCompleted Nothing)
  StructuredAlreadyFixed _reason -> Just (ObservedPlanCompleted Nothing)
  StructuredProblems reason -> Just (ObservedIssueImplementBlocked (BlockedReason reason))
  StructuredClean _reason -> Just (ObservedPlanCompleted Nothing)

classifyStructuredIssueImplementation :: Maybe PrNumber -> StructuredTurnOutcome -> Maybe IssueImplementObservation
classifyStructuredIssueImplementation maybePr = \case
  StructuredBlocked reason -> Just (ObservedImplementationBlocked (BlockedReason reason))
  StructuredIncomplete reason -> Just (ObservedImplementationIncomplete reason)
  StructuredComplete _reason ->
    case maybePr of
      Just prNumber -> Just (ObservedImplementationCompleted prNumber)
      Nothing -> Just (ObservedImplementationIncomplete "implementation completed before a pull request was known")
  StructuredNeedsImplementation reason -> Just (ObservedImplementationIncomplete reason)
  StructuredAlreadyFixed _reason ->
    case maybePr of
      Just prNumber -> Just (ObservedImplementationCompleted prNumber)
      Nothing -> Just (ObservedImplementationIncomplete "implementation completed before a pull request was known")
  StructuredProblems reason -> Just (ObservedImplementationIncomplete reason)
  StructuredClean _reason ->
    case maybePr of
      Just prNumber -> Just (ObservedImplementationCompleted prNumber)
      Nothing -> Just (ObservedImplementationIncomplete "implementation completed before a pull request was known")

classifyStructuredPrReviewWorker :: StructuredTurnOutcome -> Maybe WorkerOutcome
classifyStructuredPrReviewWorker = \case
  StructuredBlocked reason -> Just (WorkerBlocked (BlockedReason reason))
  StructuredIncomplete reason -> Just (WorkerIncomplete reason)
  StructuredComplete _reason -> Just WorkerCompleted
  StructuredNeedsImplementation reason -> Just (WorkerIncomplete reason)
  StructuredAlreadyFixed _reason -> Just WorkerCompleted
  StructuredProblems reason -> Just (WorkerIncomplete reason)
  StructuredClean _reason -> Just WorkerCompleted

classifyStructuredPrReviewReviewer :: CommitSha -> StructuredTurnOutcome -> Maybe ReviewerOutcome
classifyStructuredPrReviewReviewer commit = \case
  StructuredBlocked reason -> Just (ReviewerBlocked (BlockedReason reason))
  StructuredIncomplete reason -> Just (ReviewerIncomplete reason)
  StructuredProblems _reason -> Just (ReviewerProblemsAdded commit)
  StructuredClean comment -> Just (ReviewerClean (CleanReviewEvidence commit comment))
  StructuredComplete comment -> Just (ReviewerClean (CleanReviewEvidence commit comment))
  StructuredAlreadyFixed comment -> Just (ReviewerClean (CleanReviewEvidence commit comment))
  StructuredNeedsImplementation reason -> Just (ReviewerIncomplete reason)

runningStatuses :: [Text]
runningStatuses =
  ["", "unknown", "queued", "created", "starting", "running", "in_progress", "in-progress", "pending"]

completedStatuses :: [Text]
completedStatuses =
  ["complete", "completed", "done", "success", "succeeded", "finished"]

failedStatuses :: [Text]
failedStatuses =
  ["failed", "failure", "error", "errored", "cancelled", "canceled", "interrupted", "aborted"]

outputHasAny :: [Text] -> Maybe Text -> Bool
outputHasAny needles output =
  maybe False (\text -> any (`Text.isInfixOf` normalize text) needles) output

outputReason :: Text -> Maybe Text -> Text
outputReason fallback =
  maybe fallback nonEmptyOutput

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
