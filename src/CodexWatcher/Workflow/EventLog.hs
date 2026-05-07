{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.EventLog
  ( EventLogFixtureContract (..)
  , WorkflowReplayFailure (..)
  , WorkflowReplaySummary (..)
  , WorkflowNextDaemonRecommendation (..)
  , WorkflowTickAudit
  , WorkflowTransitionFailure (..)
  , applyMoifoldWorkflowEvent
  , initializeMoifoldWorkflow
  , replayMoifoldWorkflowEvents
  , replayWorkflowEventLog
  , replayWorkflowEventLogDetailed
  , formatWorkflowReplayFailure
  , validateEventLogFixtureContract
  , workflowAuditCommittedEventLabel
  , workflowAuditFailureClassification
  , workflowAuditFinalStateLabel
  , workflowAuditNextDaemonRecommendation
  , workflowAuditObservationLabel
  , workflowAuditPostCommitReports
  , workflowAuditPreCommitReports
  , workflowAuditPriorStateLabel
  , workflowDryRunAudit
  , workflowFailureAudit
  , workflowSuccessAudit
  ) where

import CodexWatcher.Effects (EffectPlan)
import CodexWatcher.EventLog.Replay (applyEvent, initializeFromEvent, replayEventLog)
import CodexWatcher.EventLog.Types (EventReplayResult, ReplayFailure, WatcherEvent)
import CodexWatcher.Failure (FailureClassification, failureIsRetryable)
import CodexWatcher.Core.State (SomeWatcherState)
import CodexWatcher.Workflow.Audit
  ( WorkflowNextDaemonRecommendation (..)
  , workflowAuditCommittedEventLabel
  , workflowAuditFailureClassification
  , workflowAuditFinalStateLabel
  , workflowAuditNextDaemonRecommendation
  , workflowAuditObservationLabel
  , workflowAuditPostCommitReports
  , workflowAuditPreCommitReports
  , workflowAuditPriorStateLabel
  )
import CodexWatcher.Workflow.Audit qualified as WorkflowAudit
import CodexWatcher.Workflow.EventLog.Core
  ( EventLogFixtureContract (..)
  , WorkflowReplayFailure (..)
  , WorkflowReplaySummary (..)
  , WorkflowTransitionFailure (..)
  , formatWorkflowReplayFailure
  , replayWorkflowEventLogDetailed
  , validateEventLogFixtureContract
  )
import CodexWatcher.Workflow.Spec (PlannedTransition (..), WorkflowSpec (..))
import Data.Text (Text)

type WorkflowTickAudit spec report = WorkflowAudit.WorkflowTickAudit spec FailureClassification report

replayWorkflowEventLog
  :: forall spec. WorkflowSpec spec
  => [WorkflowEvent spec]
  -> Either (WorkflowError spec) (WorkflowReplayResult spec)
replayWorkflowEventLog =
  WorkflowAudit.replayWorkflowEventLog @spec

workflowDryRunAudit
  :: forall spec report. WorkflowSpec spec
  => WorkflowState spec
  -> WorkflowObservation spec
  -> PlannedTransition spec
  -> WorkflowState spec
  -> [report]
  -> [report]
  -> WorkflowTickAudit spec report
workflowDryRunAudit =
  WorkflowAudit.workflowDryRunAudit @spec

workflowSuccessAudit
  :: forall spec report. WorkflowSpec spec
  => WorkflowState spec
  -> WorkflowObservation spec
  -> PlannedTransition spec
  -> WorkflowState spec
  -> [report]
  -> [report]
  -> WorkflowTickAudit spec report
workflowSuccessAudit =
  WorkflowAudit.workflowSuccessAudit @spec

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
workflowFailureAudit =
  WorkflowAudit.workflowFailureAudit @spec failureIsRetryable

initializeMoifoldWorkflow :: WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
initializeMoifoldWorkflow =
  initializeFromEvent

applyMoifoldWorkflowEvent :: SomeWatcherState -> WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
applyMoifoldWorkflowEvent =
  applyEvent

replayMoifoldWorkflowEvents :: [WatcherEvent] -> Either ReplayFailure EventReplayResult
replayMoifoldWorkflowEvents =
  replayEventLog
