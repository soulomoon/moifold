{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.TurnClassifier
  ( TurnCompletion (..)
  , classifyIssueImplementationTurn
  , classifyIssuePlanTurn
  , classifyIssueTriageTurn
  , classifyPrReviewReviewerTurn
  , classifyPrReviewWorkerTurn
  , classifyTurnCompletion
  ) where

import CodexWatcher.AppServerClient
import CodexWatcher.IssueImplementWatcher
import CodexWatcher.PrReviewWatcher
import CodexWatcher.Protocol
import CodexWatcher.Types
import Data.Text (Text)
import Data.Text qualified as Text

data TurnCompletion
  = TurnStillRunning
  | TurnCompleted (Maybe Text)
  | TurnFailed Text
  deriving stock (Eq, Show)

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
      | outputHasAny ["blocked", "cannot proceed"] output ->
          Just (ObservedIssueImplementBlocked (BlockedReason (outputReason "triage turn reported blocked" output)))
      | outputHasAny ["already_fixed", "already fixed", "already_resolved", "already resolved", "no changes needed"] output ->
          Just ObservedTriageAlreadyFixed
      | otherwise ->
          Just ObservedTriageNeedsImplementation

classifyIssuePlanTurn :: AppServerTurn -> Maybe IssueImplementObservation
classifyIssuePlanTurn turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedIssueImplementBlocked (BlockedReason reason))
    TurnCompleted output
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

nonEmptyOutput :: Text -> Text
nonEmptyOutput output
  | Text.null stripped = "empty app-server turn output"
  | otherwise = stripped
 where
  stripped = Text.strip output

normalize :: Text -> Text
normalize =
  Text.toLower . Text.strip
