{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Daemon.Core
  ( WorkflowDaemonTickResult (..)
  , WorkflowObservedDaemonTickResult (..)
  , workflowDaemonTickResult
  , workflowObservedDaemonTickResult
  ) where

import CodexWatcher.Workflow.Audit (WorkflowTickAudit)
import CodexWatcher.Workflow.Spec (PlannedTransition (..), WorkflowSpec (..))
import CodexWatcher.Workflow.Transaction.Core (WorkflowObservedTransactionResult (..))

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
