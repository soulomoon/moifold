{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Daemon.Types
  ( DaemonFailure (..)
  , DaemonObservedTickResult (..)
  , DaemonObservedTransactionFailure (..)
  , DaemonOptions (..)
  , DaemonTickResult (..)
  , PreMergeGateResult (..)
  , formatDaemonFailure
  ) where

import CodexWatcher.EventLog.Types (EventReplayResult, ReplayFailure (..), WatcherEvent)
import CodexWatcher.Failure (FailureClassification)
import CodexWatcher.Runtime.Command.Render (commandText)
import CodexWatcher.Runtime.Command.Types (CommandReport)
import CodexWatcher.Runtime.Compatibility (CompatibilityWrite)
import CodexWatcher.Core.State (SomeWatcherState)
import CodexWatcher.Workflow.Audit qualified as WorkflowAudit
import CodexWatcher.Workflow.Execution
import CodexWatcher.Workflow.Transaction.Core (WorkflowTransactionFailureStage)
import CodexWatcher.Workflow.Types (MoifoldSpec)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data DaemonOptions = DaemonOptions
  { daemonEventLogPath :: FilePath
  , daemonRuntimeConfig :: EffectRuntimeConfig
  , daemonExecutionMode :: ActionExecutionMode
  }
  deriving stock (Eq, Show, Generic)

data DaemonFailure
  = DaemonEventLogDecodeFailed Text
  | DaemonReplayFailed ReplayFailure
  | DaemonObservationRejected Text
  | DaemonActionFailed PlannedAction CommandReport
  | DaemonActionResultInvalid PlannedAction Text
  | DaemonObservedTransactionFailed DaemonObservedTransactionFailure
  deriving stock (Eq, Show, Generic)

data DaemonObservedTransactionFailure = DaemonObservedTransactionFailure
  { daemonObservedTransactionFailureStage :: WorkflowTransactionFailureStage
  , daemonObservedTransactionFailureReason :: DaemonFailure
  , daemonObservedTransactionFailurePlannedEvent :: Maybe WatcherEvent
  , daemonObservedTransactionFailureCommittedEvents :: [WatcherEvent]
  , daemonObservedTransactionFailureCompiledEffects :: Maybe WorkflowCompiledEffectPlan
  , daemonObservedTransactionFailurePreCommitReports :: [ActionExecutionReport]
  , daemonObservedTransactionFailurePostCommitReports :: [ActionExecutionReport]
  , daemonObservedTransactionFailureAudit :: Maybe (WorkflowAudit.WorkflowTickAudit MoifoldSpec DaemonFailure ActionExecutionReport)
  }
  deriving stock (Eq, Show, Generic)

data DaemonTickResult = DaemonTickResult
  { daemonReplayResult :: EventReplayResult
  , daemonCompiledEffects :: CompiledEffectPlan
  , daemonActionReports :: [ActionExecutionReport]
  }
  deriving stock (Show, Generic)

data DaemonObservedTickResult = DaemonObservedTickResult
  { daemonObservedReplayResult :: EventReplayResult
  , daemonObservedEvent :: WatcherEvent
  , daemonObservedCommittedEvents :: [WatcherEvent]
  , daemonObservedState :: SomeWatcherState
  , daemonObservedCompatibilityWrites :: [CompatibilityWrite]
  , daemonObservedCompiledEffects :: CompiledEffectPlan
  , daemonObservedActionReports :: [ActionExecutionReport]
  , daemonObservedAudit :: WorkflowAudit.WorkflowTickAudit MoifoldSpec FailureClassification ActionExecutionReport
  }
  deriving stock (Show, Generic)

data PreMergeGateResult
  = PreMergeGatePassed
  | PreMergeGateRetry Text
  | PreMergeGateRecheck Text
  | PreMergeGateFixRequired Text
  | PreMergeGateBlocked Text

formatDaemonFailure :: DaemonFailure -> Text
formatDaemonFailure = \case
  DaemonEventLogDecodeFailed message ->
    "event log decode failed: " <> message
  DaemonReplayFailed failure ->
    "event replay failed at event "
      <> Text.pack (show failure.eventIndex)
      <> " ("
      <> Text.pack (show failure.event)
      <> "): "
      <> failure.reason
  DaemonObservationRejected message ->
    "observation rejected: " <> message
  DaemonActionFailed action report ->
    "action failed before event commit: " <> Text.pack (show action) <> ": " <> commandText report
  DaemonActionResultInvalid action message ->
    "action returned invalid result before event commit: " <> Text.pack (show action) <> ": " <> message
  DaemonObservedTransactionFailed failure ->
    formatDaemonObservedTransactionFailure failure

formatDaemonObservedTransactionFailure :: DaemonObservedTransactionFailure -> Text
formatDaemonObservedTransactionFailure failure =
  "observed transaction failed during "
    <> Text.pack (show failure.daemonObservedTransactionFailureStage)
    <> ": "
    <> formatDaemonFailure failure.daemonObservedTransactionFailureReason
    <> "; committed events: "
    <> Text.pack (show (length failure.daemonObservedTransactionFailureCommittedEvents))
    <> maybe "" formatAudit failure.daemonObservedTransactionFailureAudit
 where
  formatAudit audit =
    "; audit prior="
      <> WorkflowAudit.workflowAuditPriorStateLabel audit
      <> ", committed="
      <> maybe "<none>" id (WorkflowAudit.workflowAuditCommittedEventLabel audit)
      <> ", final="
      <> maybe "<none>" id (WorkflowAudit.workflowAuditFinalStateLabel audit)
      <> ", recommendation="
      <> Text.pack (show (WorkflowAudit.workflowAuditNextDaemonRecommendation audit))
