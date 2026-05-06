{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.EventLog
  ( EventLogFixtureContract (..)
  , WorkflowNextDaemonRecommendation (..)
  , WorkflowTickAudit (..)
  , WorkflowTransitionFailure (..)
  , applyMoifoldWorkflowEvent
  , initializeMoifoldWorkflow
  , replayMoifoldWorkflowEvents
  , replayWorkflowEventLog
  , workflowDryRunAudit
  , workflowFailureAudit
  , workflowSuccessAudit
  ) where

import CodexWatcher.Effects (EffectPlan)
import CodexWatcher.EventLog.Replay (applyEvent, initializeFromEvent, replayEventLog)
import CodexWatcher.EventLog.Types (EventReplayResult, ReplayFailure, WatcherEvent)
import CodexWatcher.Failure (FailureClassification, failureIsRetryable)
import CodexWatcher.Core.State (SomeWatcherState)
import CodexWatcher.Workflow.Spec (PlannedTransition (..), WorkflowSpec (..))
import Data.Text (Text)

data WorkflowTransitionFailure spec = WorkflowTransitionFailure
  { workflowTransitionEvent :: WorkflowEvent spec
  , workflowTransitionError :: WorkflowError spec
  }

data EventLogFixtureContract spec = EventLogFixtureContract
  { fixtureExpectedStateLabel :: Text
  , fixtureExpectedEventCount :: Maybe Int
  }

data WorkflowNextDaemonRecommendation
  = WorkflowDaemonContinue
  | WorkflowDaemonRetry
  | WorkflowDaemonRepair
  | WorkflowDaemonStop
  deriving stock (Eq, Show)

data WorkflowTickAudit spec report = WorkflowTickAudit
  { workflowAuditPriorStateLabel :: Text
  , workflowAuditObservationLabel :: Maybe Text
  , workflowAuditCommittedEventLabel :: Maybe Text
  , workflowAuditFinalStateLabel :: Maybe Text
  , workflowAuditPreCommitReports :: [report]
  , workflowAuditPostCommitReports :: [report]
  , workflowAuditFailureClassification :: Maybe FailureClassification
  , workflowAuditNextDaemonRecommendation :: WorkflowNextDaemonRecommendation
  }
  deriving stock (Eq, Show)

replayWorkflowEventLog
  :: forall spec. WorkflowSpec spec
  => [WorkflowEvent spec]
  -> Either (WorkflowError spec) (WorkflowReplayResult spec)
replayWorkflowEventLog =
  workflowReplayEvents @spec

workflowDryRunAudit
  :: forall spec report. WorkflowSpec spec
  => WorkflowState spec
  -> WorkflowObservation spec
  -> PlannedTransition spec
  -> WorkflowState spec
  -> [report]
  -> [report]
  -> WorkflowTickAudit spec report
workflowDryRunAudit priorState observation _planned finalState preReports postReports =
  WorkflowTickAudit
    { workflowAuditPriorStateLabel = workflowStateLabel @spec priorState
    , workflowAuditObservationLabel = Just (workflowObservationLabel @spec observation)
    , workflowAuditCommittedEventLabel = Nothing
    , workflowAuditFinalStateLabel = Just (workflowStateLabel @spec finalState)
    , workflowAuditPreCommitReports = preReports
    , workflowAuditPostCommitReports = postReports
    , workflowAuditFailureClassification = Nothing
    , workflowAuditNextDaemonRecommendation = successRecommendation @spec finalState
    }

workflowSuccessAudit
  :: forall spec report. WorkflowSpec spec
  => WorkflowState spec
  -> WorkflowObservation spec
  -> PlannedTransition spec
  -> WorkflowState spec
  -> [report]
  -> [report]
  -> WorkflowTickAudit spec report
workflowSuccessAudit priorState observation planned finalState preReports postReports =
  WorkflowTickAudit
    { workflowAuditPriorStateLabel = workflowStateLabel @spec priorState
    , workflowAuditObservationLabel = Just (workflowObservationLabel @spec observation)
    , workflowAuditCommittedEventLabel = Just (workflowEventLabel @spec planned.plannedEvent)
    , workflowAuditFinalStateLabel = Just (workflowStateLabel @spec finalState)
    , workflowAuditPreCommitReports = preReports
    , workflowAuditPostCommitReports = postReports
    , workflowAuditFailureClassification = Nothing
    , workflowAuditNextDaemonRecommendation = successRecommendation @spec finalState
    }

workflowFailureAudit
  :: forall spec report. WorkflowSpec spec
  => WorkflowState spec
  -> Maybe (WorkflowObservation spec)
  -> Maybe (WorkflowEvent spec)
  -> Maybe (WorkflowState spec)
  -> [report]
  -> [report]
  -> FailureClassification
  -> WorkflowTickAudit spec report
workflowFailureAudit priorState maybeObservation maybeEvent maybeFinalState preReports postReports classification =
  WorkflowTickAudit
    { workflowAuditPriorStateLabel = workflowStateLabel @spec priorState
    , workflowAuditObservationLabel = workflowObservationLabel @spec <$> maybeObservation
    , workflowAuditCommittedEventLabel = workflowEventLabel @spec <$> maybeEvent
    , workflowAuditFinalStateLabel = workflowStateLabel @spec <$> maybeFinalState
    , workflowAuditPreCommitReports = preReports
    , workflowAuditPostCommitReports = postReports
    , workflowAuditFailureClassification = Just classification
    , workflowAuditNextDaemonRecommendation =
        if failureIsRetryable classification
          then WorkflowDaemonRetry
          else WorkflowDaemonStop
    }

successRecommendation :: forall spec. WorkflowSpec spec => WorkflowState spec -> WorkflowNextDaemonRecommendation
successRecommendation state =
  if workflowIsTerminal @spec state
    then WorkflowDaemonStop
    else WorkflowDaemonContinue

initializeMoifoldWorkflow :: WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
initializeMoifoldWorkflow =
  initializeFromEvent

applyMoifoldWorkflowEvent :: SomeWatcherState -> WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
applyMoifoldWorkflowEvent =
  applyEvent

replayMoifoldWorkflowEvents :: [WatcherEvent] -> Either ReplayFailure EventReplayResult
replayMoifoldWorkflowEvents =
  replayEventLog
