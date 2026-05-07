{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Audit
  ( EventLogFixtureContract (..)
  , WorkflowNextDaemonRecommendation (..)
  , WorkflowTickAudit (..)
  , WorkflowTransitionFailure (..)
  , replayWorkflowEventLog
  , workflowDryRunAudit
  , workflowFailureAudit
  , workflowSuccessAudit
  ) where

import CodexWatcher.Workflow.Spec (PlannedTransition (..), WorkflowSpec (..))
import CodexWatcher.Workflow.EventLog.Core
  ( EventLogFixtureContract (..)
  , WorkflowTransitionFailure (..)
  , replayWorkflowEventLog
  )
import Data.Text (Text)

data WorkflowNextDaemonRecommendation
  = WorkflowDaemonContinue
  | WorkflowDaemonRetry
  | WorkflowDaemonRepair
  | WorkflowDaemonStop
  deriving stock (Eq, Show)

data WorkflowTickAudit spec failure report = WorkflowTickAudit
  { workflowAuditPriorStateLabel :: Text
  , workflowAuditObservationLabel :: Maybe Text
  , workflowAuditCommittedEventLabel :: Maybe Text
  , workflowAuditFinalStateLabel :: Maybe Text
  , workflowAuditPreCommitReports :: [report]
  , workflowAuditPostCommitReports :: [report]
  , workflowAuditFailureClassification :: Maybe failure
  , workflowAuditNextDaemonRecommendation :: WorkflowNextDaemonRecommendation
  }
  deriving stock (Eq, Show)

workflowDryRunAudit
  :: forall spec failure report. WorkflowSpec spec
  => WorkflowState spec
  -> WorkflowObservation spec
  -> PlannedTransition spec
  -> WorkflowState spec
  -> [report]
  -> [report]
  -> WorkflowTickAudit spec failure report
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
  :: forall spec failure report. WorkflowSpec spec
  => WorkflowState spec
  -> WorkflowObservation spec
  -> PlannedTransition spec
  -> WorkflowState spec
  -> [report]
  -> [report]
  -> WorkflowTickAudit spec failure report
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
  :: forall spec failure report. WorkflowSpec spec
  => (failure -> Bool)
  -> WorkflowState spec
  -> Maybe (WorkflowObservation spec)
  -> Maybe (WorkflowEvent spec)
  -> Maybe (WorkflowState spec)
  -> [report]
  -> [report]
  -> failure
  -> WorkflowTickAudit spec failure report
workflowFailureAudit failureIsRetryable priorState maybeObservation maybeEvent maybeFinalState preReports postReports classification =
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
