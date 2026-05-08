{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Daemon.Core
  ( WorkflowDaemonTickResult (..)
  , WorkflowObservedDaemonTickFailure (..)
  , WorkflowObservedDaemonTickResult (..)
  , workflowDaemonTickResult
  , workflowObservedDaemonTickFailure
  , workflowObservedDaemonTickResult
  ) where

import CodexWatcher.Workflow.Audit (WorkflowTickAudit)
import CodexWatcher.Workflow.Spec (PlannedTransition (..), WorkflowSpec (..))
import CodexWatcher.Workflow.Transaction.Core
  ( WorkflowObservedTransactionFailure (..)
  , WorkflowObservedTransactionResult (..)
  , WorkflowTransactionFailureStage
  )

data WorkflowDaemonTickResult spec compiled report = WorkflowDaemonTickResult
  { workflowDaemonReplayResult :: WorkflowReplayResult spec
  , workflowDaemonCompiledEffects :: compiled
  , workflowDaemonActionReports :: [report]
  }

data WorkflowObservedDaemonTickResult spec compiled report failure = WorkflowObservedDaemonTickResult
  { workflowObservedDaemonPriorReplay :: WorkflowReplayResult spec
  , workflowObservedDaemonEvent :: WorkflowEvent spec
  , workflowObservedDaemonState :: WorkflowState spec
  , workflowObservedDaemonCommittedEvents :: [WorkflowEvent spec]
  , workflowObservedDaemonCompiledEffects :: compiled
  , workflowObservedDaemonPreCommitReports :: [report]
  , workflowObservedDaemonPostCommitReports :: [report]
  , workflowObservedDaemonActionReports :: [report]
  , workflowObservedDaemonAudit :: WorkflowTickAudit spec failure report
  }

data WorkflowObservedDaemonTickFailure spec compiled report failure = WorkflowObservedDaemonTickFailure
  { workflowObservedDaemonFailureStage :: WorkflowTransactionFailureStage
  , workflowObservedDaemonFailureReason :: failure
  , workflowObservedDaemonFailurePriorReplay :: Maybe (WorkflowReplayResult spec)
  , workflowObservedDaemonFailurePlanned :: Maybe (PlannedTransition spec)
  , workflowObservedDaemonFailureFinalState :: Maybe (WorkflowState spec)
  , workflowObservedDaemonFailureCommittedEvents :: [WorkflowEvent spec]
  , workflowObservedDaemonFailureCompiledEffects :: Maybe compiled
  , workflowObservedDaemonFailurePreCommitReports :: [report]
  , workflowObservedDaemonFailurePostCommitReports :: [report]
  , workflowObservedDaemonFailureAudit :: Maybe (WorkflowTickAudit spec failure report)
  }

workflowDaemonTickResult
  :: WorkflowReplayResult spec
  -> compiled
  -> [report]
  -> WorkflowDaemonTickResult spec compiled report
workflowDaemonTickResult replay compiled reports =
  WorkflowDaemonTickResult
    { workflowDaemonReplayResult = replay
    , workflowDaemonCompiledEffects = compiled
    , workflowDaemonActionReports = reports
    }

workflowObservedDaemonTickResult
  :: WorkflowObservedTransactionResult spec compiled report failure
  -> WorkflowObservedDaemonTickResult spec compiled report failure
workflowObservedDaemonTickResult result =
  WorkflowObservedDaemonTickResult
    { workflowObservedDaemonPriorReplay = result.workflowTransactionPriorReplay
    , workflowObservedDaemonEvent = result.workflowTransactionPlanned.plannedEvent
    , workflowObservedDaemonState = result.workflowTransactionFinalState
    , workflowObservedDaemonCommittedEvents = result.workflowTransactionCommittedEvents
    , workflowObservedDaemonCompiledEffects = result.workflowTransactionCompiledEffects
    , workflowObservedDaemonPreCommitReports = result.workflowTransactionPreCommitReports
    , workflowObservedDaemonPostCommitReports = result.workflowTransactionPostCommitReports
    , workflowObservedDaemonActionReports = result.workflowTransactionPreCommitReports <> result.workflowTransactionPostCommitReports
    , workflowObservedDaemonAudit = result.workflowTransactionAudit
    }

workflowObservedDaemonTickFailure
  :: WorkflowObservedTransactionFailure spec compiled report failure
  -> WorkflowObservedDaemonTickFailure spec compiled report failure
workflowObservedDaemonTickFailure failure =
  WorkflowObservedDaemonTickFailure
    { workflowObservedDaemonFailureStage = failure.workflowTransactionFailureStage
    , workflowObservedDaemonFailureReason = failure.workflowTransactionFailureReason
    , workflowObservedDaemonFailurePriorReplay = failure.workflowTransactionFailurePriorReplay
    , workflowObservedDaemonFailurePlanned = failure.workflowTransactionFailurePlanned
    , workflowObservedDaemonFailureFinalState = failure.workflowTransactionFailureFinalState
    , workflowObservedDaemonFailureCommittedEvents = failure.workflowTransactionFailureCommittedEvents
    , workflowObservedDaemonFailureCompiledEffects = failure.workflowTransactionFailureCompiledEffects
    , workflowObservedDaemonFailurePreCommitReports = failure.workflowTransactionFailurePreCommitReports
    , workflowObservedDaemonFailurePostCommitReports = failure.workflowTransactionFailurePostCommitReports
    , workflowObservedDaemonFailureAudit = failure.workflowTransactionFailureAudit
    }
