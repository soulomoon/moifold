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
  , applyWorkflowEvent
  , applyMoifoldWorkflowEvent
  , initializeMoifoldWorkflow
  , initializeWorkflowEvent
  , replayMoifoldWorkflowEvents
  , replayWorkflowEventLog
  , replayWorkflowEventLogDetailed
  , formatWorkflowReplayFailure
  , formatWorkflowTransitionFailure
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
import CodexWatcher.EventLog.Replay (replayEventLog)
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
  , applyWorkflowEvent
  , formatWorkflowReplayFailure
  , formatWorkflowTransitionFailure
  , initializeWorkflowEvent
  , replayWorkflowEventLog
  , replayWorkflowEventLogDetailed
  , validateEventLogFixtureContract
  )
import CodexWatcher.Workflow.Types (MoifoldSpec)
import CodexWatcher.Workflow.Spec (PlannedTransition (..), WorkflowSpec (..))
import Data.Text (Text)

type WorkflowTickAudit spec report = WorkflowAudit.WorkflowTickAudit spec FailureClassification report

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
initializeMoifoldWorkflow event =
  case initializeWorkflowEvent @MoifoldSpec id event of
    Left failure -> Left (formatWorkflowTransitionFailure failure)
    Right initialized -> Right initialized

applyMoifoldWorkflowEvent :: SomeWatcherState -> WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
applyMoifoldWorkflowEvent state event =
  case applyWorkflowEvent @MoifoldSpec id state event of
    Left failure -> Left (formatWorkflowTransitionFailure failure)
    Right applied -> Right applied

replayMoifoldWorkflowEvents :: [WatcherEvent] -> Either ReplayFailure EventReplayResult
replayMoifoldWorkflowEvents =
  replayEventLog
