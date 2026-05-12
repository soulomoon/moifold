{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}
{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module WorkflowIndexedSpec
  ( workflowIndexedTests
  )
where


import CodexWatcher.AppServerProtocol
import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.ChildDaemon (readPidFile, restoreOwnedPidFile)
import CodexWatcher.Cli.Types
import CodexWatcher.Runtime.Compatibility
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop
import CodexWatcher.EffectInterpreter
import CodexWatcher.Cli.RuntimeConfig
import CodexWatcher.Effects
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types
import CodexWatcher.EventLogRepair
import CodexWatcher.Failure
import CodexWatcher.GhGit (ReviewComment (..), ReviewThread (..), ReviewThreadsReport (..))
import CodexWatcher.GoldenReplay
import CodexWatcher.Cli.Command.IssueFanout (IssueImplementerChildLaunch (..), issueImplementerChildArgs, issueImplementerChildLaunchMode, issueImplementerLaunchManifest, readyIssueStatusFromRuntime, resolveFanoutActiveIssues, retryableLaunchCommandFailure)
import CodexWatcher.AutomaticLoop.Runner (retryableAutomaticLoopFailure)
import CodexWatcher.Domain.IssueImplement.Watcher
import CodexWatcher.Domain.IssuePlanning.Fanout
import CodexWatcher.Domain.IssuePlanning.Watcher
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Observation
import CodexWatcher.Cli.Command.Observe (parseDaemonObservation)
import CodexWatcher.Domain.IssuePlanning.Graph.Canonical
import CodexWatcher.Domain.PrReview.Protocol
import CodexWatcher.Domain.PrReview.Watcher
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (..))
import CodexWatcher.Runtime.Command.Render (renderRuntimeCommand)
import CodexWatcher.Runtime.Defaults
import CodexWatcher.Runtime.Interpreter (RuntimeInterpreter (..))
import CodexWatcher.Runtime.Owner.Cli (clearRuntimeLease, clearRuntimeLeaseIfOwnedByCurrentProcess)
import CodexWatcher.Runtime.Owner.Store
import CodexWatcher.Runtime.Owner.Types
import CodexWatcher.RunnerGuard
import CodexWatcher.Snapshot
import CodexWatcher.StateMachine
import CodexWatcher.Supervisor
import CodexWatcher.Domain.IssueImplement.TurnClassifier
import CodexWatcher.Domain.IssuePlanning.TurnClassifier
import CodexWatcher.Domain.PrReview.TurnClassifier
import CodexWatcher.Turn.Classifier.Common
import CodexWatcher.TurnOutput
import CodexWatcher.Core.Ids
import CodexWatcher.Core.Kinds
import CodexWatcher.Core.Limits
import CodexWatcher.Core.Reason
import CodexWatcher.Core.State
import CodexWatcher.Core.Thread
import CodexWatcher.Domain.IssueImplement.Types
import CodexWatcher.Domain.IssuePlanning.Types
import CodexWatcher.Domain.PrReview.Types
import CodexWatcher.Runtime.Paths
import CodexWatcher.WatcherRuntimeStatus
import CodexWatcher.Workflow.Agent qualified as WorkflowAgent
import CodexWatcher.Workflow.Agent.Codex qualified as WorkflowAgentCodex
import CodexWatcher.Workflow.Agent.Codex.Protocol qualified as WorkflowAgentCodexProtocol
import CodexWatcher.Workflow.Codec qualified as WorkflowCodec
import CodexWatcher.Workflow.Daemon.Core qualified as WorkflowDaemon
import CodexWatcher.Workflow.DSL qualified as WorkflowDSL
import CodexWatcher.Workflow.DocsMigration qualified as DocsMigration
import CodexWatcher.Workflow.Audit qualified as WorkflowAudit
import CodexWatcher.Workflow.EventLog.Commit.Core qualified as WorkflowEventLogCommit
import CodexWatcher.Workflow.EventLog.File.Core qualified as WorkflowEventLogFileCore
import CodexWatcher.Workflow.Execution qualified as WorkflowExecution
import CodexWatcher.Workflow.Execution.Core qualified as WorkflowExecutionCore
import CodexWatcher.Workflow.Indexed.Spec qualified as IndexedWorkflow
import CodexWatcher.Workflow.Moifold.IssueImplement.Indexed qualified as IssueImplementIndexed
import CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed
  ( IssuePlanningIndexedActiveTurn
  , IssuePlanningIndexedBlocked
  , IssuePlanningIndexedComplete
  , IssuePlanningIndexedEffect (..)
  , IssuePlanningIndexedEffectPlan (..)
  , IssuePlanningIndexedEvent (..)
  , IssuePlanningIndexedInitialized
  , IssuePlanningIndexedObservation (..)
  , IssuePlanningIndexedReplayResult (..)
  , IssuePlanningIndexedProjection (..)
  , IssuePlanningIndexedSpec
  , IssuePlanningIndexedState (..)
  , IssuePlanningIndexedWaitingReadyIssues
  , issuePlanningIndexedTransitionToCompatibility
  , projectIssuePlanningBlockedActiveTurnObservation
  , projectIssuePlanningBlockedInitializedObservation
  , projectIssuePlanningBlockedWaitingReadyIssuesObservation
  , projectIssuePlanningGraphUpdatedObservation
  , projectIssuePlanningIssuesRequestedObservation
  , projectIssuePlanningReadyIssuesFixedObservation
  , projectIssuePlanningScopeCompletedObservation
  , projectIssuePlanningTurnCompletedDslTransition
  , projectIssuePlanningTurnCompletedObservation
  , projectIssuePlanningTurnRetryObservation
  , projectIssuePlanningTurnStartedObservation
  )
import CodexWatcher.Workflow.Moifold.PrReview qualified as WorkflowPrReview
import CodexWatcher.Workflow.Moifold.PrReview.Agent qualified as WorkflowPrReviewAgent
import CodexWatcher.Workflow.Moifold.PrReview.Checking.Indexed
  ( PrReviewCheckingIndexedCheckingReviews
  , PrReviewCheckingIndexedEffect (..)
  , PrReviewCheckingIndexedEffectPlan (..)
  , PrReviewCheckingIndexedEvent (..)
  , PrReviewCheckingIndexedFixingReviews
  , PrReviewCheckingIndexedObservation (..)
  , PrReviewCheckingIndexedReplayResult (..)
  , PrReviewCheckingIndexedReviewingClean
  , PrReviewCheckingIndexedSpec
  , PrReviewCheckingIndexedState (..)
  , PrReviewCheckingIndexedUninitialized
  )
import CodexWatcher.Workflow.Moifold.PrReview.Mergeability.Indexed
  ( PrReviewIndexedBlocked
  , PrReviewIndexedCheckingReviews
  , PrReviewIndexedComplete
  , PrReviewIndexedEffect (..)
  , PrReviewIndexedEffectPlan (..)
  , PrReviewIndexedEvent (..)
  , PrReviewIndexedFixingReviews
  , PrReviewIndexedMerging
  , PrReviewIndexedObservation (..)
  , PrReviewIndexedReplayResult (..)
  , PrReviewIndexedReviewingClean
  , PrReviewIndexedState (..)
  , PrReviewIndexedUninitialized
  , PrReviewIndexedWaitingForMergeability
  , PrReviewMergeabilityIndexedProjection (..)
  , PrReviewMergeabilityIndexedSpec
  , projectPrReviewMergeabilityCleanObservation
  )
import CodexWatcher.Workflow.Moifold.PrReview.Mergeability qualified as WorkflowPrReviewMergeability
import CodexWatcher.Workflow.Moifold.PrReview.Reviewer.Indexed
  ( PrReviewReviewerIndexedBlocked
  , PrReviewReviewerIndexedCheckingReviews
  , PrReviewReviewerIndexedEffect (..)
  , PrReviewReviewerIndexedEffectPlan (..)
  , PrReviewReviewerIndexedEvent (..)
  , PrReviewReviewerIndexedFixingReviews
  , PrReviewReviewerIndexedObservation (..)
  , PrReviewReviewerIndexedReplayResult (..)
  , PrReviewReviewerIndexedReviewingClean
  , PrReviewReviewerIndexedSpec
  , PrReviewReviewerIndexedState (..)
  , PrReviewReviewerIndexedUninitialized
  , PrReviewReviewerIndexedVerifyingReviewFix
  , PrReviewReviewerIndexedWaitingMergeability
  )
import CodexWatcher.Workflow.Moifold.PrReview.Worker.Indexed
  ( PrReviewWorkerIndexedBlocked
  , PrReviewWorkerIndexedCheckingReviews
  , PrReviewWorkerIndexedEffect (..)
  , PrReviewWorkerIndexedEffectPlan (..)
  , PrReviewWorkerIndexedEvent (..)
  , PrReviewWorkerIndexedFixingReviews
  , PrReviewWorkerIndexedObservation (..)
  , PrReviewWorkerIndexedReplayResult (..)
  , PrReviewWorkerIndexedSpec
  , PrReviewWorkerIndexedState (..)
  , PrReviewWorkerIndexedUninitialized
  )
import CodexWatcher.Workflow.Observation.Agent qualified as WorkflowObservationAgent
import CodexWatcher.Workflow.Permission qualified as WorkflowPermission
import CodexWatcher.Workflow.Transaction.Core qualified as WorkflowTransaction
import CodexWatcher.Workflow.Types (MoifoldSpec, PlannedTransition (..), WorkflowSpec (..), legacyObservedPlannedTransition, moifoldPlannedTransitionFromEffects, workflowPlanObservation)
import Control.Exception (try)
import Control.Monad (when)
import Data.Aeson
  ( Value (..)
  , eitherDecodeStrict'
  , encode
  , object
  , toJSON
  , (.=)
  )
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Foldable qualified as Foldable
import Data.IORef
import Data.Kind (Type)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import Data.Text.IO qualified as TextIO
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), addUTCTime, getCurrentTime, secondsToDiffTime)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, removePathForcibly)
import System.FilePath ((</>))
import System.Exit (ExitCode (..), exitFailure)
import System.Posix.Process (getProcessID)
import Test.QuickCheck
import TestSupport.Workflow

workflowIndexedTests :: IO Bool
workflowIndexedTests =
  sequenceAnd
    [ workflowIndexedSpecExistentialsPreserveLabels
    , workflowIssuePlanningIndexedSpecMatchesPolicyTransitions
    , workflowIssuePlanningIndexedSpecPreservesGraphValidation
    , workflowIssuePlanningIndexedSpecRejectsInvalidObservationsLikeCompatibility
    , workflowIssuePlanningIndexedProjectionStartsPlannerTurn
    , workflowIssuePlanningIndexedProjectionHandlesActiveTurnOutcomes
    , workflowIssuePlanningIndexedProjectionHandlesTerminalAndRetryOutcomes
    , workflowIssuePlanningIndexedDaemonDryRunMatchesCompatibility
    , workflowIssuePlanningIndexedDaemonExecuteMatchesCompatibility
    , workflowIssuePlanningIndexedDaemonDryRunMatchesActiveTurnCompatibility
    , workflowIssuePlanningIndexedDaemonExecuteMatchesActiveTurnCompatibility
    , workflowIssuePlanningIndexedDaemonDryRunMatchesTerminalAndRetryCompatibility
    , workflowIssuePlanningIndexedDaemonExecuteMatchesTerminalAndRetryCompatibility
    , workflowIssuePlanningIndexedDaemonRejectsInvalidTurnStart
    , workflowIssuePlanningIndexedDaemonRejectsInvalidActiveTurnRoutingLikeCompatibility
    , workflowIssuePlanningIndexedDaemonRejectsInvalidTerminalAndRetryRoutingLikeCompatibility
    , workflowIssueImplementIndexedSpecMatchesCompatibilityForPolicyTransitions
    , workflowIssueImplementIndexedSpecCoversInvalidObservationsLikeCompatibility
    , workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPlanPrSetupAndImplementationWorkerProjections
    , workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchHandoffAndMergeWaitProjections
    , workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPostMergeReviewProjections
    , workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchIssueCloseProjections
    , workflowIssueImplementIndexedDaemonRoutingIsLimitedToDaemonProjectionOnly
    , workflowIssueImplementIndexedDaemonDoesNotRouteLaterProjectors
    , workflowPrReviewCheckingIndexedSpecMatchesCompatibilityForReviewThreads
    , workflowPrReviewCheckingIndexedSpecMatchesCompatibilityForFeedbackSources
    , workflowPrReviewCheckingIndexedSpecMatchesCompatibilityForVerificationStart
    , workflowPrReviewCheckingIndexedSpecRejectsInvalidObservationLikeFacade
    , workflowPrReviewCheckingIndexedSpecPreservesTerminalAndPermissionLaws
    , workflowPrReviewWorkerIndexedSpecMatchesCompatibilityForOutcomes
    , workflowPrReviewWorkerIndexedSpecMatchesClassifierBackedOutcomes
    , workflowPrReviewWorkerIndexedSpecRejectsInvalidObservationLikeFacade
    , workflowPrReviewReviewerIndexedSpecMatchesCompatibilityForOutcomes
    , workflowPrReviewReviewerIndexedSpecMatchesClassifierBackedOutcomes
    , workflowPrReviewReviewerIndexedSpecRejectsInvalidObservationLikeFacade
    , workflowPrReviewMergeabilityIndexedSpecMatchesCompatibilityForWaitingOutcomes
    , workflowPrReviewMergeabilityIndexedSpecMatchesCompatibilityForCleanFromGoldenLifecycle
    , workflowPrReviewMergeabilityIndexedSpecMatchesCompatibilityForBlockedAndMergeComplete
    , workflowPrReviewMergeabilityIndexedSpecPreservesMergeEffectOrdering
    , workflowPrReviewMergeabilityIndexedSpecRejectsMismatchedCleanCommitLikeFacade
    , workflowPrReviewMergeabilityIndexedSpecRejectsInvalidTerminalObservationsLikeCompatibility
    , workflowPrReviewMergeabilityIndexedDaemonDryRunMatchesCompatibility
    , workflowPrReviewMergeabilityIndexedDaemonExecuteMatchesCompatibility
    , workflowPrReviewMergeabilityIndexedDaemonFailureMatchesCompatibility
    , workflowPrReviewMergeabilityIndexedDaemonRejectsInvalidObservations
    ]


data IndexedTestPoint

data IndexedTestQueued

data IndexedTestDone

data IndexedTestSpec

data IndexedTestState state where
  IndexedTestQueuedState :: IndexedTestState IndexedTestQueued
  IndexedTestDoneState :: IndexedTestState IndexedTestDone

data IndexedTestEvent source target where
  IndexedTestCompleteEvent :: IndexedTestEvent IndexedTestQueued IndexedTestDone

data IndexedTestObservation source target where
  IndexedTestCompleteObservation :: IndexedTestObservation IndexedTestQueued IndexedTestDone

data IndexedTestEffect source target =
  IndexedTestEffect Text

newtype IndexedTestPlan source target =
  IndexedTestPlan [IndexedTestEffect source target]

data IndexedTestTick source target =
  IndexedTestTick
    (IndexedTestEvent source target)
    (IndexedTestState target)
    (IndexedTestPlan source target)

newtype IndexedTestReplayResult state =
  IndexedTestReplayResult (IndexedTestState state)

type instance IndexedWorkflow.WorkflowIndex IndexedTestSpec = IndexedTestPoint

instance IndexedWorkflow.IndexedWorkflowSpec IndexedTestSpec where
  type IndexedWorkflowState IndexedTestSpec state = IndexedTestState state
  type IndexedWorkflowEvent IndexedTestSpec source target = IndexedTestEvent source target
  type IndexedWorkflowObservation IndexedTestSpec source target = IndexedTestObservation source target
  type IndexedWorkflowObservedTick IndexedTestSpec source target = IndexedTestTick source target
  type IndexedWorkflowEffect IndexedTestSpec source target = IndexedTestEffect source target
  type IndexedWorkflowEffectPlan IndexedTestSpec source target = IndexedTestPlan source target
  type IndexedWorkflowReplayResult IndexedTestSpec state = IndexedTestReplayResult state
  type IndexedWorkflowError IndexedTestSpec = Text

  indexedWorkflowInitialEvent IndexedTestCompleteEvent =
    Right (IndexedTestDoneState, IndexedTestPlan [IndexedTestEffect "pre-indexed-effect"])
  indexedWorkflowApplyEvent _state IndexedTestCompleteEvent =
    Right (IndexedTestDoneState, IndexedTestPlan [IndexedTestEffect "pre-indexed-effect"])
  indexedWorkflowObserve _state IndexedTestCompleteObservation =
    Right (IndexedTestTick IndexedTestCompleteEvent IndexedTestDoneState (IndexedTestPlan [IndexedTestEffect "pre-indexed-effect"]))
  indexedWorkflowObservedTransition (IndexedTestTick event _state effects) =
    IndexedWorkflow.indexedWorkflowPlanTransition @IndexedTestSpec event effects
  indexedWorkflowObservedState (IndexedTestTick _event state _effects) =
    state
  indexedWorkflowPlanTransition event effects =
    IndexedWorkflow.IndexedPlannedTransition
      { IndexedWorkflow.indexedPlannedEvent = event
      , IndexedWorkflow.indexedPlannedPreCommitEffects = effects
      , IndexedWorkflow.indexedPlannedPostCommitEffects = IndexedTestPlan [IndexedTestEffect "post-indexed-effect"]
      }
  indexedWorkflowReplayEvents [IndexedWorkflow.SomeIndexedWorkflowEvent IndexedTestCompleteEvent] =
    Right (IndexedWorkflow.SomeIndexedWorkflowReplayResult (IndexedTestReplayResult IndexedTestDoneState))
  indexedWorkflowReplayEvents _events =
    Left "unexpected indexed test replay events"
  indexedWorkflowReplayState (IndexedTestReplayResult state) =
    state
  indexedWorkflowValidateEffects _state _effects =
    Right ()
  indexedWorkflowEffectPlanEffects (IndexedTestPlan effects) =
    effects
  indexedWorkflowEffectAllowed _state _effect =
    Right ()
  indexedWorkflowIsTerminal IndexedTestQueuedState =
    False
  indexedWorkflowIsTerminal IndexedTestDoneState =
    True
  indexedWorkflowStateLabel IndexedTestQueuedState =
    "queued"
  indexedWorkflowStateLabel IndexedTestDoneState =
    "done"
  indexedWorkflowEventLabel IndexedTestCompleteEvent =
    "complete"
  indexedWorkflowEventSourceLabel IndexedTestCompleteEvent =
    "queued"
  indexedWorkflowEventTargetLabel IndexedTestCompleteEvent =
    "done"
  indexedWorkflowObservationLabel IndexedTestCompleteObservation =
    "complete-observation"
  indexedWorkflowObservationSourceLabel IndexedTestCompleteObservation =
    "queued"
  indexedWorkflowObservationTargetLabel IndexedTestCompleteObservation =
    "done"
  indexedWorkflowEffectLabel (IndexedTestEffect effectText) =
    effectText


prReviewIndexedTransitionEvent
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewMergeabilityIndexedSpec source target
  -> WatcherEvent
prReviewIndexedTransitionEvent transition =
  case IndexedWorkflow.indexedPlannedEvent transition of
    PrReviewIndexedEvent _sourceLabel _targetLabel event -> event

prReviewIndexedTransitionPreCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewMergeabilityIndexedSpec source target
  -> EffectPlan
prReviewIndexedTransitionPreCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPreCommitEffects transition of
    PrReviewIndexedEffectPlan effects -> effects

prReviewIndexedTransitionPostCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewMergeabilityIndexedSpec source target
  -> EffectPlan
prReviewIndexedTransitionPostCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPostCommitEffects transition of
    PrReviewIndexedEffectPlan effects -> effects

prReviewIndexedReplayResult :: IndexedWorkflow.SomeIndexedWorkflowReplayResult PrReviewMergeabilityIndexedSpec -> EventReplayResult
prReviewIndexedReplayResult (IndexedWorkflow.SomeIndexedWorkflowReplayResult (PrReviewIndexedReplayResult replay)) =
  replay

issuePlanningIndexedTransitionEvent
  :: IndexedWorkflow.IndexedPlannedTransition IssuePlanningIndexedSpec source target
  -> WatcherEvent
issuePlanningIndexedTransitionEvent transition =
  case IndexedWorkflow.indexedPlannedEvent transition of
    IssuePlanningIndexedEvent _sourceLabel _targetLabel event -> event

issuePlanningIndexedTransitionPreCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition IssuePlanningIndexedSpec source target
  -> EffectPlan
issuePlanningIndexedTransitionPreCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPreCommitEffects transition of
    IssuePlanningIndexedEffectPlan effects -> effects

issuePlanningIndexedTransitionPostCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition IssuePlanningIndexedSpec source target
  -> EffectPlan
issuePlanningIndexedTransitionPostCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPostCommitEffects transition of
    IssuePlanningIndexedEffectPlan effects -> effects

prReviewCheckingIndexedTransitionEvent
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewCheckingIndexedSpec source target
  -> WatcherEvent
prReviewCheckingIndexedTransitionEvent transition =
  case IndexedWorkflow.indexedPlannedEvent transition of
    PrReviewCheckingIndexedEvent _sourceLabel _targetLabel event -> event

prReviewCheckingIndexedTransitionPreCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewCheckingIndexedSpec source target
  -> EffectPlan
prReviewCheckingIndexedTransitionPreCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPreCommitEffects transition of
    PrReviewCheckingIndexedEffectPlan effects -> effects

prReviewCheckingIndexedTransitionPostCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewCheckingIndexedSpec source target
  -> EffectPlan
prReviewCheckingIndexedTransitionPostCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPostCommitEffects transition of
    PrReviewCheckingIndexedEffectPlan effects -> effects

prReviewCheckingIndexedReplayResult :: IndexedWorkflow.SomeIndexedWorkflowReplayResult PrReviewCheckingIndexedSpec -> EventReplayResult
prReviewCheckingIndexedReplayResult (IndexedWorkflow.SomeIndexedWorkflowReplayResult (PrReviewCheckingIndexedReplayResult replay)) =
  replay

prReviewWorkerIndexedTransitionEvent
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewWorkerIndexedSpec source target
  -> WatcherEvent
prReviewWorkerIndexedTransitionEvent transition =
  case IndexedWorkflow.indexedPlannedEvent transition of
    PrReviewWorkerIndexedEvent _sourceLabel _targetLabel event -> event

prReviewWorkerIndexedTransitionPreCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewWorkerIndexedSpec source target
  -> EffectPlan
prReviewWorkerIndexedTransitionPreCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPreCommitEffects transition of
    PrReviewWorkerIndexedEffectPlan effects -> effects

prReviewWorkerIndexedTransitionPostCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewWorkerIndexedSpec source target
  -> EffectPlan
prReviewWorkerIndexedTransitionPostCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPostCommitEffects transition of
    PrReviewWorkerIndexedEffectPlan effects -> effects

prReviewWorkerIndexedReplayResult :: IndexedWorkflow.SomeIndexedWorkflowReplayResult PrReviewWorkerIndexedSpec -> EventReplayResult
prReviewWorkerIndexedReplayResult (IndexedWorkflow.SomeIndexedWorkflowReplayResult (PrReviewWorkerIndexedReplayResult replay)) =
  replay

prReviewReviewerIndexedTransitionEvent
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewReviewerIndexedSpec source target
  -> WatcherEvent
prReviewReviewerIndexedTransitionEvent transition =
  case IndexedWorkflow.indexedPlannedEvent transition of
    PrReviewReviewerIndexedEvent _sourceLabel _targetLabel event -> event

prReviewReviewerIndexedTransitionPreCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewReviewerIndexedSpec source target
  -> EffectPlan
prReviewReviewerIndexedTransitionPreCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPreCommitEffects transition of
    PrReviewReviewerIndexedEffectPlan effects -> effects

prReviewReviewerIndexedTransitionPostCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewReviewerIndexedSpec source target
  -> EffectPlan
prReviewReviewerIndexedTransitionPostCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPostCommitEffects transition of
    PrReviewReviewerIndexedEffectPlan effects -> effects

prReviewReviewerIndexedReplayResult :: IndexedWorkflow.SomeIndexedWorkflowReplayResult PrReviewReviewerIndexedSpec -> EventReplayResult
prReviewReviewerIndexedReplayResult (IndexedWorkflow.SomeIndexedWorkflowReplayResult (PrReviewReviewerIndexedReplayResult replay)) =
  replay

docsMigrationIndexedTransitionEvent
  :: IndexedWorkflow.IndexedPlannedTransition DocsMigration.DocsMigrationSpec source target
  -> DocsMigration.DocsMigrationEvent
docsMigrationIndexedTransitionEvent transition =
  case IndexedWorkflow.indexedPlannedEvent transition of
    DocsMigration.DocsMigrationIndexedEvent _sourceLabel _targetLabel event -> event

docsMigrationIndexedTransitionPreCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition DocsMigration.DocsMigrationSpec source target
  -> [DocsMigration.DocsMigrationEffect]
docsMigrationIndexedTransitionPreCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPreCommitEffects transition of
    DocsMigration.DocsMigrationIndexedEffectPlan effects -> effects

docsMigrationIndexedTransitionPostCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition DocsMigration.DocsMigrationSpec source target
  -> [DocsMigration.DocsMigrationEffect]
docsMigrationIndexedTransitionPostCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPostCommitEffects transition of
    DocsMigration.DocsMigrationIndexedEffectPlan effects -> effects

docsMigrationIndexedReplayResult
  :: IndexedWorkflow.SomeIndexedWorkflowReplayResult DocsMigration.DocsMigrationSpec
  -> DocsMigration.DocsMigrationReplayResult
docsMigrationIndexedReplayResult (IndexedWorkflow.SomeIndexedWorkflowReplayResult (DocsMigration.DocsMigrationIndexedReplayResult replay)) =
  replay

workflowIndexedSpecExistentialsPreserveLabels :: IO Bool
workflowIndexedSpecExistentialsPreserveLabels = do
  let state =
        IndexedWorkflow.SomeIndexedWorkflowState
          (IndexedTestQueuedState :: IndexedTestState IndexedTestQueued)
      event =
        IndexedWorkflow.SomeIndexedWorkflowEvent
          (IndexedTestCompleteEvent :: IndexedTestEvent IndexedTestQueued IndexedTestDone)
      observation =
        IndexedWorkflow.SomeIndexedWorkflowObservation
          (IndexedTestCompleteObservation :: IndexedTestObservation IndexedTestQueued IndexedTestDone)
      effect =
        IndexedWorkflow.SomeIndexedWorkflowEffect
          (IndexedTestEffect "pre-indexed-effect" :: IndexedTestEffect IndexedTestQueued IndexedTestDone)
      plan =
        IndexedWorkflow.SomeIndexedWorkflowEffectPlan
          (IndexedTestPlan [IndexedTestEffect "pre-indexed-effect"] :: IndexedTestPlan IndexedTestQueued IndexedTestDone)
      transition =
        IndexedWorkflow.indexedWorkflowPlanTransition
          @IndexedTestSpec
          IndexedTestCompleteEvent
          (IndexedTestPlan [IndexedTestEffect "pre-indexed-effect"])
      wrappedTransition =
        IndexedWorkflow.SomeIndexedPlannedTransition transition
      observedTick =
        IndexedWorkflow.SomeIndexedWorkflowObservedTick
          (IndexedTestTick IndexedTestCompleteEvent IndexedTestDoneState (IndexedTestPlan [IndexedTestEffect "pre-indexed-effect"]))
      replayResult =
        IndexedWorkflow.SomeIndexedWorkflowReplayResult
          (IndexedTestReplayResult IndexedTestDoneState)
      plannedObservation =
        IndexedWorkflow.indexedWorkflowPlanObservation
          @IndexedTestSpec
          IndexedTestQueuedState
          IndexedTestCompleteObservation
  assert "indexed workflow existentials preserve labels and typed transition boundaries" $
    IndexedWorkflow.someIndexedWorkflowStateLabel @IndexedTestSpec state == "queued"
      && IndexedWorkflow.someIndexedWorkflowEventLabel @IndexedTestSpec event == "complete"
      && IndexedWorkflow.someIndexedWorkflowEventSourceLabel @IndexedTestSpec event == "queued"
      && IndexedWorkflow.someIndexedWorkflowEventTargetLabel @IndexedTestSpec event == "done"
      && IndexedWorkflow.someIndexedWorkflowObservationLabel @IndexedTestSpec observation == "complete-observation"
      && IndexedWorkflow.someIndexedWorkflowObservationSourceLabel @IndexedTestSpec observation == "queued"
      && IndexedWorkflow.someIndexedWorkflowObservationTargetLabel @IndexedTestSpec observation == "done"
      && IndexedWorkflow.someIndexedWorkflowEffectLabel @IndexedTestSpec effect == "pre-indexed-effect"
      && IndexedWorkflow.someIndexedWorkflowEffectPlanEffectLabels @IndexedTestSpec plan == ["pre-indexed-effect"]
      && IndexedWorkflow.someIndexedWorkflowTransitionEventLabel @IndexedTestSpec wrappedTransition == "complete"
      && IndexedWorkflow.someIndexedWorkflowTransitionSourceLabel @IndexedTestSpec wrappedTransition == "queued"
      && IndexedWorkflow.someIndexedWorkflowTransitionTargetLabel @IndexedTestSpec wrappedTransition == "done"
      && IndexedWorkflow.someIndexedWorkflowTransitionPreCommitEffectLabels @IndexedTestSpec wrappedTransition == ["pre-indexed-effect"]
      && IndexedWorkflow.someIndexedWorkflowTransitionPostCommitEffectLabels @IndexedTestSpec wrappedTransition == ["post-indexed-effect"]
      && IndexedWorkflow.someIndexedWorkflowObservedTickStateLabel @IndexedTestSpec observedTick == "done"
      && IndexedWorkflow.someIndexedWorkflowObservedTickTransitionLabel @IndexedTestSpec observedTick == "complete"
      && IndexedWorkflow.someIndexedWorkflowReplayStateLabel @IndexedTestSpec replayResult == "done"
      && case plannedObservation of
        Right planned ->
          IndexedWorkflow.indexedWorkflowPlannedTransitionEventLabel @IndexedTestSpec planned == "complete"
            && IndexedWorkflow.indexedWorkflowPlannedTransitionSourceLabel @IndexedTestSpec planned == "queued"
            && IndexedWorkflow.indexedWorkflowPlannedTransitionTargetLabel @IndexedTestSpec planned == "done"
        Left _failure -> False

workflowIssuePlanningIndexedSpecMatchesPolicyTransitions :: IO Bool
workflowIssuePlanningIndexedSpecMatchesPolicyTransitions = do
  let config = issuePlanningIndexedConfig
      threadId = ThreadId "planner-thread"
      turnId = TurnId "planner-turn"
      readyState = SomeWatcherState (PlanningReady config)
      readyPrefix = [IssuePlanningInitialized config]
      readyIndexedPrefix = [issuePlanningIndexedInitializedEvent config]
      activeState = SomeWatcherState (PlanningTurnActive config (ActiveTurn threadId turnId))
      activePrefix = readyPrefix <> [IssuePlanningTurnStarted threadId turnId]
      activeIndexedPrefix = readyIndexedPrefix <> [issuePlanningIndexedTurnStartedEvent threadId turnId]
      requestOne = IssueCreationRequest "split parser work" "Implement parser support." (Just (IssueNumber 12))
      requestTwo = IssueCreationRequest "split runtime work" "Implement runtime support." (Just (IssueNumber 12))
      validGraph =
        PlanningGraph
          [IssueNumber 15]
          [BlockedPlanningIssue (IssueNumber 12) [IssueNumber 15, IssueNumber 16] "split work"]
          [ IssueDependency (IssueNumber 12) [IssueNumber 15, IssueNumber 16]
          , IssueDependency (IssueNumber 16) [IssueNumber 15]
          ]
      waitingState = SomeWatcherState (PlanningWaitingForReadyIssues config validGraph)
      waitingPrefix = activePrefix <> [IssuePlanningGraphUpdated validGraph]
      waitingIndexedPrefix = activeIndexedPrefix <> [issuePlanningIndexedGraphUpdatedEvent validGraph]
      retryReason = BlockedReason "planner requested another pass"
      blockedReason = BlockedReason "planner could not continue"
  results <-
    sequence
      [ issuePlanningIndexedSpecMatchesCompatibility
          "indexed workflow issue planning turn start matches compatibility"
          readyState
          readyPrefix
          readyIndexedPrefix
          (ObservedPlanningTurnStarted threadId turnId)
          ( IssuePlanningIndexedObservation "IssuePlanning/Initialized" "IssuePlanning/PlanMode" (DaemonIssuePlanningObservation (ObservedPlanningTurnStarted threadId turnId))
              :: IssuePlanningIndexedObservation IssuePlanningIndexedInitialized IssuePlanningIndexedActiveTurn
          )
          (IssuePlanningTurnStarted threadId turnId)
          ( IssuePlanningIndexedEvent "IssuePlanning/Initialized" "IssuePlanning/PlanMode" (IssuePlanningTurnStarted threadId turnId)
              :: IssuePlanningIndexedEvent IssuePlanningIndexedInitialized IssuePlanningIndexedActiveTurn
          )
          "IssuePlanning/PlanMode"
          ( \planned ->
              planned.plannedPreCommitEffects == [SomeEffect (StartPlannerTurn threadId)]
                && null planned.plannedPostCommitEffects
          )
          ( \compiled ->
              fmap (appServerRequestId . WorkflowExecution.workflowPlannedAction) compiled.workflowCompiledActions == [Just 900]
                && compiled.workflowCompiledNextRequestId == RequestId 901
          )
          (const True)
      , issuePlanningIndexedSpecMatchesCompatibility
          "indexed workflow issue planning issue requests match compatibility"
          activeState
          activePrefix
          activeIndexedPrefix
          (ObservedPlanningIssuesRequested (requestOne :| [requestTwo]))
          ( IssuePlanningIndexedObservation "IssuePlanning/PlanMode" "IssuePlanning/Initialized" (DaemonIssuePlanningObservation (ObservedPlanningIssuesRequested (requestOne :| [requestTwo])))
              :: IssuePlanningIndexedObservation IssuePlanningIndexedActiveTurn IssuePlanningIndexedInitialized
          )
          (IssuePlanningIssuesRequested (requestOne :| [requestTwo]))
          ( IssuePlanningIndexedEvent "IssuePlanning/PlanMode" "IssuePlanning/Initialized" (IssuePlanningIssuesRequested (requestOne :| [requestTwo]))
              :: IssuePlanningIndexedEvent IssuePlanningIndexedActiveTurn IssuePlanningIndexedInitialized
          )
          "IssuePlanning/Initialized"
          ( \planned ->
              fmap effectTag (planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects) == [CreateIssueTag, CreateIssueTag, SleepUntilNextPollTag]
                && planned.plannedPreCommitEffects == [SomeEffect (CreateIssue config.plannerRepo requestOne), SomeEffect (CreateIssue config.plannerRepo requestTwo)]
                && planned.plannedPostCommitEffects == [SomeEffect SleepUntilNextPoll]
          )
          requestIdStable
          (const True)
      , issuePlanningIndexedSpecMatchesCompatibility
          "indexed workflow issue planning graph update matches compatibility"
          activeState
          activePrefix
          activeIndexedPrefix
          (ObservedPlanningGraphUpdated validGraph)
          ( IssuePlanningIndexedObservation "IssuePlanning/PlanMode" "IssuePlanning/Initialized" (DaemonIssuePlanningObservation (ObservedPlanningGraphUpdated validGraph))
              :: IssuePlanningIndexedObservation IssuePlanningIndexedActiveTurn IssuePlanningIndexedWaitingReadyIssues
          )
          (IssuePlanningGraphUpdated validGraph)
          ( IssuePlanningIndexedEvent "IssuePlanning/PlanMode" "IssuePlanning/Initialized" (IssuePlanningGraphUpdated validGraph)
              :: IssuePlanningIndexedEvent IssuePlanningIndexedActiveTurn IssuePlanningIndexedWaitingReadyIssues
          )
          "IssuePlanning/Initialized"
          ( \planned ->
              null planned.plannedPreCommitEffects
                && planned.plannedPostCommitEffects == [SomeEffect (RecordPlanningGraph validGraph), SomeEffect SleepUntilNextPoll]
          )
          requestIdStable
          (compatibilityWritesContainPlanningGraph validGraph)
      , issuePlanningIndexedSpecMatchesCompatibility
          "indexed workflow issue planning ready issues fixed matches compatibility"
          waitingState
          waitingPrefix
          waitingIndexedPrefix
          ObservedPlanningReadyIssuesFixed
          ( IssuePlanningIndexedObservation "IssuePlanning/Initialized" "IssuePlanning/Initialized" (DaemonIssuePlanningObservation ObservedPlanningReadyIssuesFixed)
              :: IssuePlanningIndexedObservation IssuePlanningIndexedWaitingReadyIssues IssuePlanningIndexedInitialized
          )
          IssuePlanningReadyIssuesFixed
          ( IssuePlanningIndexedEvent "IssuePlanning/Initialized" "IssuePlanning/Initialized" IssuePlanningReadyIssuesFixed
              :: IssuePlanningIndexedEvent IssuePlanningIndexedWaitingReadyIssues IssuePlanningIndexedInitialized
          )
          "IssuePlanning/Initialized"
          sleepPostCommitPlan
          requestIdStable
          (const True)
      , issuePlanningIndexedSpecMatchesCompatibility
          "indexed workflow issue planning scope completed matches compatibility"
          readyState
          readyPrefix
          readyIndexedPrefix
          ObservedPlanningScopeCompleted
          ( IssuePlanningIndexedObservation "IssuePlanning/Initialized" "IssuePlanning/Complete" (DaemonIssuePlanningObservation ObservedPlanningScopeCompleted)
              :: IssuePlanningIndexedObservation IssuePlanningIndexedInitialized IssuePlanningIndexedComplete
          )
          IssuePlanningScopeCompleted
          ( IssuePlanningIndexedEvent "IssuePlanning/Initialized" "IssuePlanning/Complete" IssuePlanningScopeCompleted
              :: IssuePlanningIndexedEvent IssuePlanningIndexedInitialized IssuePlanningIndexedComplete
          )
          "IssuePlanning/Complete"
          ( \planned ->
              null planned.plannedPreCommitEffects
                && planned.plannedPostCommitEffects == [SomeEffect StopDaemon]
          )
          requestIdStable
          (const True)
      , issuePlanningIndexedSpecMatchesCompatibility
          "indexed workflow issue planning retry matches compatibility"
          activeState
          activePrefix
          activeIndexedPrefix
          (ObservedPlanningTurnRetryRequested retryReason)
          ( IssuePlanningIndexedObservation "IssuePlanning/PlanMode" "IssuePlanning/Initialized" (DaemonIssuePlanningObservation (ObservedPlanningTurnRetryRequested retryReason))
              :: IssuePlanningIndexedObservation IssuePlanningIndexedActiveTurn IssuePlanningIndexedInitialized
          )
          (IssuePlanningTurnRetryRequested retryReason)
          ( IssuePlanningIndexedEvent "IssuePlanning/PlanMode" "IssuePlanning/Initialized" (IssuePlanningTurnRetryRequested retryReason)
              :: IssuePlanningIndexedEvent IssuePlanningIndexedActiveTurn IssuePlanningIndexedInitialized
          )
          "IssuePlanning/Initialized"
          sleepPostCommitPlan
          requestIdStable
          (const True)
      , issuePlanningIndexedSpecMatchesCompatibility
          "indexed workflow issue planning turn completed matches compatibility"
          activeState
          activePrefix
          activeIndexedPrefix
          ObservedPlanningTurnCompleted
          ( IssuePlanningIndexedObservation "IssuePlanning/PlanMode" "IssuePlanning/Complete" (DaemonIssuePlanningObservation ObservedPlanningTurnCompleted)
              :: IssuePlanningIndexedObservation IssuePlanningIndexedActiveTurn IssuePlanningIndexedComplete
          )
          IssuePlanningTurnCompleted
          ( IssuePlanningIndexedEvent "IssuePlanning/PlanMode" "IssuePlanning/Complete" IssuePlanningTurnCompleted
              :: IssuePlanningIndexedEvent IssuePlanningIndexedActiveTurn IssuePlanningIndexedComplete
          )
          "IssuePlanning/Complete"
          ( \planned ->
              null planned.plannedPreCommitEffects
                && planned.plannedPostCommitEffects == [SomeEffect StopDaemon]
          )
          requestIdStable
          (const True)
      , issuePlanningIndexedSpecMatchesCompatibility
          "indexed workflow issue planning ready blocked matches compatibility"
          readyState
          readyPrefix
          readyIndexedPrefix
          (ObservedPlanningBlocked blockedReason)
          ( IssuePlanningIndexedObservation "IssuePlanning/Initialized" "IssuePlanning/Blocked" (DaemonIssuePlanningObservation (ObservedPlanningBlocked blockedReason))
              :: IssuePlanningIndexedObservation IssuePlanningIndexedInitialized IssuePlanningIndexedBlocked
          )
          (WatcherBlocked blockedReason)
          ( IssuePlanningIndexedEvent "IssuePlanning/Initialized" "IssuePlanning/Blocked" (WatcherBlocked blockedReason)
              :: IssuePlanningIndexedEvent IssuePlanningIndexedInitialized IssuePlanningIndexedBlocked
          )
          "IssuePlanning/Blocked"
          blockedPostCommitPlan
          requestIdStable
          (const True)
      , issuePlanningIndexedSpecMatchesCompatibility
          "indexed workflow issue planning active blocked matches compatibility"
          activeState
          activePrefix
          activeIndexedPrefix
          (ObservedPlanningBlocked blockedReason)
          ( IssuePlanningIndexedObservation "IssuePlanning/PlanMode" "IssuePlanning/Blocked" (DaemonIssuePlanningObservation (ObservedPlanningBlocked blockedReason))
              :: IssuePlanningIndexedObservation IssuePlanningIndexedActiveTurn IssuePlanningIndexedBlocked
          )
          (WatcherBlocked blockedReason)
          ( IssuePlanningIndexedEvent "IssuePlanning/PlanMode" "IssuePlanning/Blocked" (WatcherBlocked blockedReason)
              :: IssuePlanningIndexedEvent IssuePlanningIndexedActiveTurn IssuePlanningIndexedBlocked
          )
          "IssuePlanning/Blocked"
          blockedPostCommitPlan
          requestIdStable
          (const True)
      , issuePlanningIndexedSpecMatchesCompatibility
          "indexed workflow issue planning waiting blocked matches compatibility"
          waitingState
          waitingPrefix
          waitingIndexedPrefix
          (ObservedPlanningBlocked blockedReason)
          ( IssuePlanningIndexedObservation "IssuePlanning/Initialized" "IssuePlanning/Blocked" (DaemonIssuePlanningObservation (ObservedPlanningBlocked blockedReason))
              :: IssuePlanningIndexedObservation IssuePlanningIndexedWaitingReadyIssues IssuePlanningIndexedBlocked
          )
          (WatcherBlocked blockedReason)
          ( IssuePlanningIndexedEvent "IssuePlanning/Initialized" "IssuePlanning/Blocked" (WatcherBlocked blockedReason)
              :: IssuePlanningIndexedEvent IssuePlanningIndexedWaitingReadyIssues IssuePlanningIndexedBlocked
          )
          "IssuePlanning/Blocked"
          blockedPostCommitPlan
          requestIdStable
          (const True)
      ]
  pure (and results)
 where
  requestIdStable compiled =
    compiled.workflowCompiledNextRequestId == RequestId 900
      && all ((== Nothing) . appServerRequestId . WorkflowExecution.workflowPlannedAction) compiled.workflowCompiledActions

workflowIssuePlanningIndexedSpecPreservesGraphValidation :: IO Bool
workflowIssuePlanningIndexedSpecPreservesGraphValidation = do
  let config = issuePlanningIndexedConfig
      threadId = ThreadId "planner-thread"
      turnId = TurnId "planner-turn"
      activeState = SomeWatcherState (PlanningTurnActive config (ActiveTurn threadId turnId))
      activePrefix = [IssuePlanningInitialized config, IssuePlanningTurnStarted threadId turnId]
      activeIndexedPrefix = [issuePlanningIndexedInitializedEvent config, issuePlanningIndexedTurnStartedEvent threadId turnId]
      invalidCases =
        [ ( "duplicate ready issue"
          , PlanningGraph [IssueNumber 15, IssueNumber 15] [] []
          , "planning graph has duplicate ready issue #15"
          )
        , ( "duplicate blocked issue"
          , PlanningGraph [] [blockedIssue 15, blockedIssue 15] []
          , "planning graph has duplicate blocked issue #15"
          )
        , ( "duplicate dependency entry"
          , PlanningGraph [] [] [IssueDependency (IssueNumber 15) [IssueNumber 16], IssueDependency (IssueNumber 15) [IssueNumber 17]]
          , "planning graph has duplicate dependency entry for issue #15"
          )
        , ( "ready blocked overlap"
          , PlanningGraph [IssueNumber 15] [blockedIssue 15] []
          , "planning graph marks issue #15 as both ready and blocked"
          )
        , ( "dependency on ready"
          , PlanningGraph [IssueNumber 15] [] [IssueDependency (IssueNumber 15) [IssueNumber 16]]
          , "planning graph marks issue #15 ready while it still depends on #16"
          )
        , ( "out of scope"
          , PlanningGraph [IssueNumber 99] [] []
          , "planning graph references issue #99 outside configured scope"
          )
        ]
  invalidResults <-
    traverse
      ( \(caseName, graph, reason) ->
          issuePlanningIndexedSpecMatchesCompatibility
            ("indexed workflow issue planning graph validation " <> caseName <> " matches compatibility")
            activeState
            activePrefix
            activeIndexedPrefix
            (ObservedPlanningGraphUpdated graph)
            ( IssuePlanningIndexedObservation "IssuePlanning/PlanMode" "IssuePlanning/Blocked" (DaemonIssuePlanningObservation (ObservedPlanningGraphUpdated graph))
                :: IssuePlanningIndexedObservation IssuePlanningIndexedActiveTurn IssuePlanningIndexedBlocked
            )
            (WatcherBlocked (BlockedReason reason))
            ( IssuePlanningIndexedEvent "IssuePlanning/PlanMode" "IssuePlanning/Blocked" (WatcherBlocked (BlockedReason reason))
                :: IssuePlanningIndexedEvent IssuePlanningIndexedActiveTurn IssuePlanningIndexedBlocked
            )
            "IssuePlanning/Blocked"
            blockedPostCommitPlan
            (\compiled -> compiled.workflowCompiledNextRequestId == RequestId 900)
            (const True)
      )
      invalidCases
  successResult <-
    issuePlanningIndexedSpecMatchesCompatibility
      "indexed workflow issue planning graph scoped closure success matches compatibility"
      activeState
      activePrefix
      activeIndexedPrefix
      (ObservedPlanningGraphUpdated scopedClosureGraph)
      ( IssuePlanningIndexedObservation "IssuePlanning/PlanMode" "IssuePlanning/Initialized" (DaemonIssuePlanningObservation (ObservedPlanningGraphUpdated scopedClosureGraph))
          :: IssuePlanningIndexedObservation IssuePlanningIndexedActiveTurn IssuePlanningIndexedWaitingReadyIssues
      )
      (IssuePlanningGraphUpdated scopedClosureGraph)
      ( IssuePlanningIndexedEvent "IssuePlanning/PlanMode" "IssuePlanning/Initialized" (IssuePlanningGraphUpdated scopedClosureGraph)
          :: IssuePlanningIndexedEvent IssuePlanningIndexedActiveTurn IssuePlanningIndexedWaitingReadyIssues
      )
      "IssuePlanning/Initialized"
      (effectTagPlan [RecordPlanningGraphTag, SleepUntilNextPollTag])
      (\compiled -> compiled.workflowCompiledNextRequestId == RequestId 900)
      (compatibilityWritesContainPlanningGraph scopedClosureGraph)
  pure (and invalidResults && successResult)
 where
  blockedIssue issue =
    BlockedPlanningIssue (IssueNumber issue) [] "blocked"
  scopedClosureGraph =
    PlanningGraph
      [IssueNumber 15]
      [BlockedPlanningIssue (IssueNumber 12) [IssueNumber 15, IssueNumber 16] "split work"]
      [ IssueDependency (IssueNumber 12) [IssueNumber 15, IssueNumber 16]
      , IssueDependency (IssueNumber 16) [IssueNumber 15]
      ]

workflowIssuePlanningIndexedSpecRejectsInvalidObservationsLikeCompatibility :: IO Bool
workflowIssuePlanningIndexedSpecRejectsInvalidObservationsLikeCompatibility = do
  let config = issuePlanningIndexedConfig
      readyState = SomeWatcherState (PlanningReady config)
      activeState = SomeWatcherState (PlanningTurnActive config (ActiveTurn (ThreadId "planner-thread") (TurnId "planner-turn")))
      waitingState = SomeWatcherState (PlanningWaitingForReadyIssues config (PlanningGraph [IssueNumber 15] [] []))
      request = IssueCreationRequest "split work" "Create the split." (Just (IssueNumber 12))
      graph = PlanningGraph [IssueNumber 15] [] []
  assert "indexed workflow issue planning rejects invalid observations like compatibility" $
    and
      [ invalid readyState (ObservedPlanningIssuesRequested (request :| [])) (IssuePlanningIndexedState readyState :: IssuePlanningIndexedState IssuePlanningIndexedInitialized) (IssuePlanningIndexedObservation "IssuePlanning/Initialized" "IssuePlanning/Initialized" (DaemonIssuePlanningObservation (ObservedPlanningIssuesRequested (request :| []))) :: IssuePlanningIndexedObservation IssuePlanningIndexedInitialized IssuePlanningIndexedInitialized)
      , invalid readyState (ObservedPlanningGraphUpdated graph) (IssuePlanningIndexedState readyState :: IssuePlanningIndexedState IssuePlanningIndexedInitialized) (IssuePlanningIndexedObservation "IssuePlanning/Initialized" "IssuePlanning/Initialized" (DaemonIssuePlanningObservation (ObservedPlanningGraphUpdated graph)) :: IssuePlanningIndexedObservation IssuePlanningIndexedInitialized IssuePlanningIndexedInitialized)
      , invalid readyState ObservedPlanningReadyIssuesFixed (IssuePlanningIndexedState readyState :: IssuePlanningIndexedState IssuePlanningIndexedInitialized) (IssuePlanningIndexedObservation "IssuePlanning/Initialized" "IssuePlanning/Initialized" (DaemonIssuePlanningObservation ObservedPlanningReadyIssuesFixed) :: IssuePlanningIndexedObservation IssuePlanningIndexedInitialized IssuePlanningIndexedInitialized)
      , invalid activeState ObservedPlanningScopeCompleted (IssuePlanningIndexedState activeState :: IssuePlanningIndexedState IssuePlanningIndexedActiveTurn) (IssuePlanningIndexedObservation "IssuePlanning/PlanMode" "IssuePlanning/PlanMode" (DaemonIssuePlanningObservation ObservedPlanningScopeCompleted) :: IssuePlanningIndexedObservation IssuePlanningIndexedActiveTurn IssuePlanningIndexedActiveTurn)
      , invalid readyState (ObservedPlanningTurnRetryRequested (BlockedReason "retry")) (IssuePlanningIndexedState readyState :: IssuePlanningIndexedState IssuePlanningIndexedInitialized) (IssuePlanningIndexedObservation "IssuePlanning/Initialized" "IssuePlanning/Initialized" (DaemonIssuePlanningObservation (ObservedPlanningTurnRetryRequested (BlockedReason "retry"))) :: IssuePlanningIndexedObservation IssuePlanningIndexedInitialized IssuePlanningIndexedInitialized)
      , invalid readyState ObservedPlanningTurnCompleted (IssuePlanningIndexedState readyState :: IssuePlanningIndexedState IssuePlanningIndexedInitialized) (IssuePlanningIndexedObservation "IssuePlanning/Initialized" "IssuePlanning/Initialized" (DaemonIssuePlanningObservation ObservedPlanningTurnCompleted) :: IssuePlanningIndexedObservation IssuePlanningIndexedInitialized IssuePlanningIndexedInitialized)
      , invalid activeState (ObservedPlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn-2")) (IssuePlanningIndexedState activeState :: IssuePlanningIndexedState IssuePlanningIndexedActiveTurn) (IssuePlanningIndexedObservation "IssuePlanning/PlanMode" "IssuePlanning/PlanMode" (DaemonIssuePlanningObservation (ObservedPlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn-2"))) :: IssuePlanningIndexedObservation IssuePlanningIndexedActiveTurn IssuePlanningIndexedActiveTurn)
      , invalid waitingState (ObservedPlanningIssuesRequested (request :| [])) (IssuePlanningIndexedState waitingState :: IssuePlanningIndexedState IssuePlanningIndexedWaitingReadyIssues) (IssuePlanningIndexedObservation "IssuePlanning/Initialized" "IssuePlanning/Initialized" (DaemonIssuePlanningObservation (ObservedPlanningIssuesRequested (request :| []))) :: IssuePlanningIndexedObservation IssuePlanningIndexedWaitingReadyIssues IssuePlanningIndexedWaitingReadyIssues)
      ]
 where
  invalid state observation indexedState indexedObservation =
    case
      ( workflowObserve @MoifoldSpec state (DaemonIssuePlanningObservation observation)
      , IndexedWorkflow.indexedWorkflowObserve @IssuePlanningIndexedSpec indexedState indexedObservation
      )
      of
      (Left compatibilityFailure, Left indexedFailure) -> compatibilityFailure == indexedFailure
      _ -> False

workflowIssuePlanningIndexedProjectionStartsPlannerTurn :: IO Bool
workflowIssuePlanningIndexedProjectionStartsPlannerTurn = do
  let config = issuePlanningIndexedConfig
      threadId = ThreadId "planner-thread"
      turnId = TurnId "planner-turn"
      state = SomeWatcherState (PlanningReady config)
      observation = DaemonIssuePlanningObservation (ObservedPlanningTurnStarted threadId turnId)
      indexedState =
        IssuePlanningIndexedState state
          :: IssuePlanningIndexedState IssuePlanningIndexedInitialized
      indexedObservation =
        IssuePlanningIndexedObservation
          "IssuePlanning/Initialized"
          "IssuePlanning/PlanMode"
          observation
          :: IssuePlanningIndexedObservation IssuePlanningIndexedInitialized IssuePlanningIndexedActiveTurn
      expectedEvent = IssuePlanningTurnStarted threadId turnId
      expectedEffects = [SomeEffect (StartPlannerTurn threadId)]
      runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 920
  assert "indexed issue-planning projection starts planner turn with compatibility labels and request id" $
    case
      ( workflowObserve @MoifoldSpec state observation
      , workflowPlanObservation @MoifoldSpec state observation
      , IndexedWorkflow.indexedWorkflowPlanObservation @IssuePlanningIndexedSpec indexedState indexedObservation
      , projectIssuePlanningTurnStartedObservation state threadId turnId
      )
      of
      (Right observed, Right compatibilityPlan, Right indexedPlan, Right projection) ->
        let projectedPlan = projection.issuePlanningIndexedProjectionPlanned
            compiled =
              WorkflowExecution.compileWorkflowEffectPlanWithMetadata
                runtimeConfig
                projection.issuePlanningIndexedProjectionEffectPlan
         in projectedPlan.plannedEvent == compatibilityPlan.plannedEvent
              && projectedPlan.plannedPreCommitEffects == compatibilityPlan.plannedPreCommitEffects
              && projectedPlan.plannedPostCommitEffects == compatibilityPlan.plannedPostCommitEffects
              && projectedPlan.plannedEvent == expectedEvent
              && issuePlanningIndexedTransitionEvent indexedPlan == expectedEvent
              && issuePlanningIndexedTransitionPreCommitEffects indexedPlan == expectedEffects
              && null (issuePlanningIndexedTransitionPostCommitEffects indexedPlan)
              && projection.issuePlanningIndexedProjectionSourceLabel == workflowStateLabel @MoifoldSpec state
              && projection.issuePlanningIndexedProjectionTargetLabel == "IssuePlanning/PlanMode"
              && workflowStateLabel @MoifoldSpec projection.issuePlanningIndexedProjectionFinalState == "IssuePlanning/PlanMode"
              && sameWatcherStateShape projection.issuePlanningIndexedProjectionFinalState observed.observedState
              && projection.issuePlanningIndexedProjectionEffectPlan == expectedEffects
              && fmap (appServerRequestId . WorkflowExecution.workflowPlannedAction) compiled.workflowCompiledActions == [Just 920]
              && compiled.workflowCompiledNextRequestId == RequestId 921
      _ -> False

workflowIssuePlanningIndexedProjectionHandlesActiveTurnOutcomes :: IO Bool
workflowIssuePlanningIndexedProjectionHandlesActiveTurnOutcomes = do
  let config = issuePlanningIndexedConfig
      threadId = ThreadId "planner-thread"
      turnId = TurnId "planner-turn"
      state = SomeWatcherState (PlanningTurnActive config (ActiveTurn threadId turnId))
      requestOne = IssueCreationRequest "split parser work" "Implement parser support." (Just (IssueNumber 12))
      requestTwo = IssueCreationRequest "split runtime work" "Implement runtime support." (Just (IssueNumber 12))
      requests = requestOne :| [requestTwo]
      graph =
        PlanningGraph
          [IssueNumber 15]
          [BlockedPlanningIssue (IssueNumber 12) [IssueNumber 15] "split work"]
          [IssueDependency (IssueNumber 12) [IssueNumber 15]]
      requestObservation = DaemonIssuePlanningObservation (ObservedPlanningIssuesRequested requests)
      graphObservation = DaemonIssuePlanningObservation (ObservedPlanningGraphUpdated graph)
      runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 960
  requestResult <-
    assert "indexed issue-planning projection preserves issue-request compatibility plan" $
      case
        ( workflowObserve @MoifoldSpec state requestObservation
        , workflowPlanObservation @MoifoldSpec state requestObservation
        , projectIssuePlanningIssuesRequestedObservation state requests
        )
        of
        (Right observed, Right compatibilityPlan, Right projection) ->
          let projectedPlan = projection.issuePlanningIndexedProjectionPlanned
              compiled =
                WorkflowExecution.compileWorkflowEffectPlanWithMetadata
                  runtimeConfig
                  projection.issuePlanningIndexedProjectionEffectPlan
           in projectedPlan.plannedEvent == IssuePlanningIssuesRequested requests
                && projectedPlan.plannedPreCommitEffects == compatibilityPlan.plannedPreCommitEffects
                && projectedPlan.plannedPostCommitEffects == compatibilityPlan.plannedPostCommitEffects
                && fmap effectTag projection.issuePlanningIndexedProjectionEffectPlan == [CreateIssueTag, CreateIssueTag, SleepUntilNextPollTag]
                && projectedPlan.plannedPreCommitEffects == [SomeEffect (CreateIssue config.plannerRepo requestOne), SomeEffect (CreateIssue config.plannerRepo requestTwo)]
                && projectedPlan.plannedPostCommitEffects == [SomeEffect SleepUntilNextPoll]
                && projection.issuePlanningIndexedProjectionSourceLabel == "IssuePlanning/PlanMode"
                && projection.issuePlanningIndexedProjectionTargetLabel == "IssuePlanning/Initialized"
                && workflowStateLabel @MoifoldSpec projection.issuePlanningIndexedProjectionFinalState == "IssuePlanning/Initialized"
                && sameWatcherStateShape projection.issuePlanningIndexedProjectionFinalState observed.observedState
                && compiled.workflowCompiledNextRequestId == RequestId 960
                && all ((== Nothing) . appServerRequestId . WorkflowExecution.workflowPlannedAction) compiled.workflowCompiledActions
        _ -> False
  graphResult <-
    assert "indexed issue-planning projection preserves graph-update compatibility plan" $
      case
        ( workflowObserve @MoifoldSpec state graphObservation
        , workflowPlanObservation @MoifoldSpec state graphObservation
        , projectIssuePlanningGraphUpdatedObservation state graph
        )
        of
        (Right observed, Right compatibilityPlan, Right projection) ->
          let projectedPlan = projection.issuePlanningIndexedProjectionPlanned
              writes = compatibilityStateWrites "/tmp/state" projection.issuePlanningIndexedProjectionFinalState
           in projectedPlan.plannedEvent == IssuePlanningGraphUpdated graph
                && projectedPlan.plannedPreCommitEffects == compatibilityPlan.plannedPreCommitEffects
                && projectedPlan.plannedPostCommitEffects == compatibilityPlan.plannedPostCommitEffects
                && fmap effectTag projection.issuePlanningIndexedProjectionEffectPlan == [RecordPlanningGraphTag, SleepUntilNextPollTag]
                && projectedPlan.plannedPostCommitEffects == [SomeEffect (RecordPlanningGraph graph), SomeEffect SleepUntilNextPoll]
                && projection.issuePlanningIndexedProjectionSourceLabel == "IssuePlanning/PlanMode"
                && projection.issuePlanningIndexedProjectionTargetLabel == "IssuePlanning/Initialized"
                && workflowStateLabel @MoifoldSpec projection.issuePlanningIndexedProjectionFinalState == "IssuePlanning/Initialized"
                && sameWatcherStateShape projection.issuePlanningIndexedProjectionFinalState observed.observedState
                && compatibilityWritesContainPlanningGraph graph writes
                && case projection.issuePlanningIndexedProjectionFinalState of
                  SomeWatcherState (PlanningWaitingForReadyIssues _ projectedGraph) -> projectedGraph == graph
                  _ -> False
        _ -> False
  pure (requestResult && graphResult)

workflowIssuePlanningIndexedProjectionHandlesTerminalAndRetryOutcomes :: IO Bool
workflowIssuePlanningIndexedProjectionHandlesTerminalAndRetryOutcomes = do
  readyFixedResult <-
    projectionCase
      "indexed issue-planning projection preserves ready-issues-fixed compatibility plan"
      waitingState
      (DaemonIssuePlanningObservation ObservedPlanningReadyIssuesFixed)
      (projectIssuePlanningReadyIssuesFixedObservation waitingState)
      IssuePlanningReadyIssuesFixed
      "IssuePlanning/Initialized"
      "IssuePlanning/Initialized"
      "IssuePlanning/Initialized"
      [SomeEffect SleepUntilNextPoll]
      requestIdStable
      (const True)
  scopeCompletedResult <-
    projectionCase
      "indexed issue-planning projection preserves scope-completed compatibility plan"
      readyState
      (DaemonIssuePlanningObservation ObservedPlanningScopeCompleted)
      (projectIssuePlanningScopeCompletedObservation readyState)
      IssuePlanningScopeCompleted
      "IssuePlanning/Initialized"
      "IssuePlanning/Complete"
      "IssuePlanning/Complete"
      [SomeEffect StopDaemon]
      requestIdStable
      (const True)
  retryResult <-
    projectionCase
      "indexed issue-planning projection preserves retry compatibility plan"
      activeState
      (DaemonIssuePlanningObservation (ObservedPlanningTurnRetryRequested retryReason))
      (projectIssuePlanningTurnRetryObservation activeState retryReason)
      (IssuePlanningTurnRetryRequested retryReason)
      "IssuePlanning/PlanMode"
      "IssuePlanning/Initialized"
      "IssuePlanning/Initialized"
      [SomeEffect SleepUntilNextPoll]
      requestIdStable
      (const True)
  completedResult <-
    projectionCase
      "indexed issue-planning projection preserves turn-completed compatibility plan"
      activeState
      (DaemonIssuePlanningObservation ObservedPlanningTurnCompleted)
      (projectIssuePlanningTurnCompletedObservation activeState)
      IssuePlanningTurnCompleted
      "IssuePlanning/PlanMode"
      "IssuePlanning/Complete"
      "IssuePlanning/Complete"
      [SomeEffect StopDaemon]
      requestIdStable
      (const True)
  blockedReadyResult <-
    projectionCase
      "indexed issue-planning projection preserves initialized blocked compatibility plan"
      readyState
      blockedObservation
      (projectIssuePlanningBlockedInitializedObservation readyState blockedReason)
      (WatcherBlocked blockedReason)
      "IssuePlanning/Initialized"
      "IssuePlanning/Blocked"
      "IssuePlanning/Blocked"
      [SomeEffect (RecordBlocked blockedReason), SomeEffect StopDaemon]
      requestIdStable
      (const True)
  blockedActiveResult <-
    projectionCase
      "indexed issue-planning projection preserves active blocked compatibility plan"
      activeState
      blockedObservation
      (projectIssuePlanningBlockedActiveTurnObservation activeState blockedReason)
      (WatcherBlocked blockedReason)
      "IssuePlanning/PlanMode"
      "IssuePlanning/Blocked"
      "IssuePlanning/Blocked"
      [SomeEffect (RecordBlocked blockedReason), SomeEffect StopDaemon]
      requestIdStable
      (const True)
  blockedWaitingResult <-
    projectionCase
      "indexed issue-planning projection preserves waiting blocked compatibility plan"
      waitingState
      blockedObservation
      (projectIssuePlanningBlockedWaitingReadyIssuesObservation waitingState blockedReason)
      (WatcherBlocked blockedReason)
      "IssuePlanning/Initialized"
      "IssuePlanning/Blocked"
      "IssuePlanning/Blocked"
      [SomeEffect (RecordBlocked blockedReason), SomeEffect StopDaemon]
      requestIdStable
      (const True)
  pure
    ( and
        [ readyFixedResult
        , scopeCompletedResult
        , retryResult
        , completedResult
        , blockedReadyResult
        , blockedActiveResult
        , blockedWaitingResult
        ]
    )
 where
  config = issuePlanningIndexedConfig
  threadId = ThreadId "planner-thread"
  turnId = TurnId "planner-turn"
  graph = PlanningGraph [IssueNumber 12] [] []
  readyState = SomeWatcherState (PlanningReady config)
  activeState = SomeWatcherState (PlanningTurnActive config (ActiveTurn threadId turnId))
  waitingState = SomeWatcherState (PlanningWaitingForReadyIssues config graph)
  retryReason = BlockedReason "planner requested another pass"
  blockedReason = BlockedReason "planner could not continue"
  blockedObservation = DaemonIssuePlanningObservation (ObservedPlanningBlocked blockedReason)
  requestIdStable compiled =
    compiled.workflowCompiledNextRequestId == RequestId 1020
      && all ((== Nothing) . appServerRequestId . WorkflowExecution.workflowPlannedAction) compiled.workflowCompiledActions
  projectionCase title state observation projection expectedEvent expectedSourceLabel expectedTargetLabel expectedFinalLabel expectedEffects compiledCheck writeCheck =
    assert title $
      case
        ( workflowObserve @MoifoldSpec state observation
        , workflowPlanObservation @MoifoldSpec state observation
        , projection
        )
        of
        (Right observed, Right compatibilityPlan, Right projected) ->
          let projectedPlan = projected.issuePlanningIndexedProjectionPlanned
              runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 1020
              compiled =
                WorkflowExecution.compileWorkflowEffectPlanWithMetadata
                  runtimeConfig
                  projected.issuePlanningIndexedProjectionEffectPlan
              compatibilityWrites = compatibilityStateWrites "/tmp/state" observed.observedState
              indexedWrites = compatibilityStateWrites "/tmp/state" projected.issuePlanningIndexedProjectionFinalState
           in projectedPlan.plannedEvent == expectedEvent
                && projectedPlan.plannedEvent == compatibilityPlan.plannedEvent
                && projectedPlan.plannedPreCommitEffects == compatibilityPlan.plannedPreCommitEffects
                && projectedPlan.plannedPostCommitEffects == compatibilityPlan.plannedPostCommitEffects
                && projected.issuePlanningIndexedProjectionEffectPlan == expectedEffects
                && projected.issuePlanningIndexedProjectionSourceLabel == expectedSourceLabel
                && projected.issuePlanningIndexedProjectionTargetLabel == expectedTargetLabel
                && workflowStateLabel @MoifoldSpec projected.issuePlanningIndexedProjectionFinalState == expectedFinalLabel
                && sameWatcherStateShape projected.issuePlanningIndexedProjectionFinalState observed.observedState
                && compatibilityWrites == indexedWrites
                && writeCheck indexedWrites
                && compiledCheck compiled
        _ -> False

workflowIssuePlanningIndexedDaemonDryRunMatchesCompatibility :: IO Bool
workflowIssuePlanningIndexedDaemonDryRunMatchesCompatibility = do
  (executor, getCalls) <- fakeActionExecutor
  let config = issuePlanningIndexedConfig
      threadId = ThreadId "planner-thread"
      turnId = TurnId "planner-turn"
      state = SomeWatcherState (PlanningReady config)
      events = [IssuePlanningInitialized config]
      observation = DaemonIssuePlanningObservation (ObservedPlanningTurnStarted threadId turnId)
      runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 930
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      expectedEvent = IssuePlanningTurnStarted threadId turnId
      expectedEffects = [SomeEffect (StartPlannerTurn threadId)]
      expectedCompiled = compileEffectPlan runtimeConfig expectedEffects
      expectedReports = dryRunCompiledEffectPlan expectedCompiled
  result <- runObservedDaemonTickWithEvents executor options events observation
  calls <- getCalls
  case
    ( result
    , workflowPlanObservation @MoifoldSpec state observation
    , projectIssuePlanningTurnStartedObservation state threadId turnId
    )
    of
    (Right tick, Right compatibilityPlan, Right projection) -> do
      let audit = tick.daemonObservedAudit
          expectedWrites =
            compatibilityStateWrites (runtimeStateDirPath runtimeConfig.effectRuntimeStateDir) tick.daemonObservedState
      results <-
        sequence
          [ assert "indexed issue-planning daemon dry-run emits compatibility start event" $
              tick.daemonObservedEvent == expectedEvent
                && tick.daemonObservedEvent == compatibilityPlan.plannedEvent
                && tick.daemonObservedEvent == projection.issuePlanningIndexedProjectionPlanned.plannedEvent
          , assert "indexed issue-planning daemon dry-run reaches active planner state" $
              sameWatcherStateShape tick.daemonObservedState projection.issuePlanningIndexedProjectionFinalState
                && workflowStateLabel @MoifoldSpec tick.daemonObservedState == "IssuePlanning/PlanMode"
                && sameWatcherStateShape tick.daemonObservedReplayResult.replayState state
          , assert "indexed issue-planning daemon dry-run preserves labels and request id progression" $
              projection.issuePlanningIndexedProjectionSourceLabel == workflowStateLabel @MoifoldSpec state
                && projection.issuePlanningIndexedProjectionTargetLabel == "IssuePlanning/PlanMode"
                && tick.daemonObservedCompiledEffects == expectedCompiled
                && tick.daemonObservedCompiledEffects.compiledNextRequestId == RequestId 931
                && fmap appServerRequestId tick.daemonObservedCompiledEffects.compiledActions == [Just 930]
          , assert "indexed issue-planning daemon dry-run keeps report and audit surfaces stable" $
              tick.daemonObservedCommittedEvents == []
                && tick.daemonObservedActionReports == expectedReports
                && tick.daemonObservedCompatibilityWrites == expectedWrites
                && WorkflowAudit.workflowAuditCommittedEventLabel audit == Nothing
                && WorkflowAudit.workflowAuditPriorStateLabel audit == workflowStateLabel @MoifoldSpec state
                && WorkflowAudit.workflowAuditFinalStateLabel audit == Just "IssuePlanning/PlanMode"
                && WorkflowAudit.workflowAuditPreCommitReports audit == expectedReports
                && WorkflowAudit.workflowAuditPostCommitReports audit == []
          , assert "indexed issue-planning daemon dry-run does not mutate runtime state" (null calls)
          ]
      pure (and results)
    (Left failure, _, _) -> do
      putStrLn ("FAIL indexed issue-planning daemon dry-run: " <> Text.unpack (formatDaemonFailure failure))
      pure False
    _ ->
      assert "indexed issue-planning daemon dry-run prepares compatibility and indexed plans" False

workflowIssuePlanningIndexedDaemonExecuteMatchesCompatibility :: IO Bool
workflowIssuePlanningIndexedDaemonExecuteMatchesCompatibility = do
  (executor, getCalls) <- fakeActionExecutor
  let config = issuePlanningIndexedConfig
      threadId = ThreadId "planner-thread"
      turnId = TurnId "planner-turn"
      state = SomeWatcherState (PlanningReady config)
      events = [IssuePlanningInitialized config]
      observation = DaemonIssuePlanningObservation (ObservedPlanningTurnStarted threadId turnId)
      runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 940
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      expectedEvent = IssuePlanningTurnStarted threadId turnId
      expectedEffects = [SomeEffect (StartPlannerTurn threadId)]
      expectedCompiled = compileEffectPlan runtimeConfig expectedEffects
  result <- runObservedDaemonTickWithEvents executor options events observation
  calls <- getCalls
  case
    ( result
    , workflowPlanObservation @MoifoldSpec state observation
    , projectIssuePlanningTurnStartedObservation state threadId turnId
    )
    of
    (Right tick, Right compatibilityPlan, Right projection) -> do
      let expectedWrites =
            compatibilityStateWrites (runtimeStateDirPath runtimeConfig.effectRuntimeStateDir) tick.daemonObservedState
          expectedAppend = FakeAppendJsonLine "/tmp/events.jsonl" (toJSON expectedEvent)
          expectedWriteCalls =
            [ FakeWriteJson (compatibilityWritePath write) (compatibilityWriteValue write)
            | write <- expectedWrites
            ]
      results <-
        sequence
          [ assert "indexed issue-planning daemon execute commits compatibility start event" $
              tick.daemonObservedEvent == expectedEvent
                && tick.daemonObservedEvent == compatibilityPlan.plannedEvent
                && tick.daemonObservedCommittedEvents == [expectedEvent]
          , assert "indexed issue-planning daemon execute reaches active planner state" $
              sameWatcherStateShape tick.daemonObservedState projection.issuePlanningIndexedProjectionFinalState
                && workflowStateLabel @MoifoldSpec tick.daemonObservedState == "IssuePlanning/PlanMode"
          , assert "indexed issue-planning daemon execute starts planner turn before append" $
              tick.daemonObservedCompiledEffects == expectedCompiled
                && tick.daemonObservedCompiledEffects.compiledNextRequestId == RequestId 941
                && case calls of
                  FakeAppServer request : FakeAppendJsonLine "/tmp/events.jsonl" appended : _ ->
                    request.requestMethod == "turn/start"
                      && request.requestId == RequestId 940
                      && appended == toJSON expectedEvent
                  _ -> False
          , assert "indexed issue-planning daemon execute writes compatibility after event append" $
              tick.daemonObservedCompatibilityWrites == expectedWrites
                && length [() | FakeWriteJson {} <- calls] == length expectedWrites
                && all (`elem` calls) expectedWriteCalls
                && all (\writeCall -> callBefore expectedAppend writeCall calls) expectedWriteCalls
          , assert "indexed issue-planning daemon execute keeps audit surfaces stable" $
              WorkflowAudit.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just "issue_planning_turn_started"
                && WorkflowAudit.workflowAuditPreCommitReports tick.daemonObservedAudit == tick.daemonObservedActionReports
                && WorkflowAudit.workflowAuditPostCommitReports tick.daemonObservedAudit == []
          ]
      pure (and results)
    (Left failure, _, _) -> do
      putStrLn ("FAIL indexed issue-planning daemon execute: " <> Text.unpack (formatDaemonFailure failure))
      pure False
    _ ->
      assert "indexed issue-planning daemon execute prepares compatibility and indexed plans" False

workflowIssuePlanningIndexedDaemonDryRunMatchesActiveTurnCompatibility :: IO Bool
workflowIssuePlanningIndexedDaemonDryRunMatchesActiveTurnCompatibility = do
  requestResult <- dryRunCase "issue requests" requestObservation expectedRequestEvent expectedRequestEffects "IssuePlanning/Initialized" (const True)
  graphResult <- dryRunCase "graph update" graphObservation expectedGraphEvent expectedGraphEffects "IssuePlanning/Initialized" (runtimeWritesContainPlanningGraph graph)
  pure (requestResult && graphResult)
 where
  config = issuePlanningIndexedConfig
  threadId = ThreadId "planner-thread"
  turnId = TurnId "planner-turn"
  events = [IssuePlanningInitialized config, IssuePlanningTurnStarted threadId turnId]
  state = SomeWatcherState (PlanningTurnActive config (ActiveTurn threadId turnId))
  request = IssueCreationRequest "split parser work" "Implement parser support." (Just (IssueNumber 12))
  graph = PlanningGraph [IssueNumber 15] [BlockedPlanningIssue (IssueNumber 12) [IssueNumber 15] "split work"] [IssueDependency (IssueNumber 12) [IssueNumber 15]]
  requestObservation = DaemonIssuePlanningObservation (ObservedPlanningIssuesRequested (request :| []))
  graphObservation = DaemonIssuePlanningObservation (ObservedPlanningGraphUpdated graph)
  expectedRequestEvent = IssuePlanningIssuesRequested (request :| [])
  expectedGraphEvent = IssuePlanningGraphUpdated graph
  expectedRequestEffects = [SomeEffect (CreateIssue config.plannerRepo request), SomeEffect SleepUntilNextPoll]
  expectedGraphEffects = [SomeEffect (RecordPlanningGraph graph), SomeEffect SleepUntilNextPoll]
  dryRunCase caseName observation expectedEvent expectedEffects expectedTargetLabel writeCheck = do
    (executor, getCalls) <- fakeActionExecutor
    let runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 970
        options =
          DaemonOptions
            { daemonEventLogPath = "/tmp/events.jsonl"
            , daemonRuntimeConfig = runtimeConfig
            , daemonExecutionMode = DryRunActions
            }
        expectedCompiled = compileEffectPlan runtimeConfig expectedEffects
        expectedReports = dryRunCompiledEffectPlan expectedCompiled
    result <- runObservedDaemonTickWithEvents executor options events observation
    calls <- getCalls
    case result of
      Right tick -> do
        let compatibilityPlan = workflowPlanObservation @MoifoldSpec state observation
            expectedWrites =
              compatibilityStateWrites (runtimeStateDirPath runtimeConfig.effectRuntimeStateDir) tick.daemonObservedState
            audit = tick.daemonObservedAudit
        results <-
          sequence
            [ assert ("indexed issue-planning daemon dry-run active " <> caseName <> " emits compatibility event") $
                tick.daemonObservedEvent == expectedEvent
                  && case compatibilityPlan of
                    Right planned -> planned.plannedEvent == expectedEvent
                    Left _ -> False
            , assert ("indexed issue-planning daemon dry-run active " <> caseName <> " reaches target state") $
                workflowStateLabel @MoifoldSpec tick.daemonObservedState == expectedTargetLabel
                  && sameWatcherStateShape tick.daemonObservedReplayResult.replayState state
            , assert ("indexed issue-planning daemon dry-run active " <> caseName <> " keeps reports and writes stable") $
                tick.daemonObservedCommittedEvents == []
                  && tick.daemonObservedCompiledEffects == expectedCompiled
                  && tick.daemonObservedActionReports == expectedReports
                  && tick.daemonObservedCompatibilityWrites == expectedWrites
                  && writeCheck expectedWrites
                  && WorkflowAudit.workflowAuditCommittedEventLabel audit == Nothing
            , assert ("indexed issue-planning daemon dry-run active " <> caseName <> " does not mutate runtime state") (null calls)
            ]
        pure (and results)
      Left failure -> do
        putStrLn ("FAIL indexed issue-planning daemon dry-run active " <> caseName <> ": " <> Text.unpack (formatDaemonFailure failure))
        pure False

workflowIssuePlanningIndexedDaemonExecuteMatchesActiveTurnCompatibility :: IO Bool
workflowIssuePlanningIndexedDaemonExecuteMatchesActiveTurnCompatibility = do
  requestResult <- executeRequestCase
  graphResult <- executeGraphCase
  pure (requestResult && graphResult)
 where
  config = issuePlanningIndexedConfig
  threadId = ThreadId "planner-thread"
  turnId = TurnId "planner-turn"
  events = [IssuePlanningInitialized config, IssuePlanningTurnStarted threadId turnId]
  request = IssueCreationRequest "split parser work" "Implement parser support." (Just (IssueNumber 12))
  graph = PlanningGraph [IssueNumber 15] [BlockedPlanningIssue (IssueNumber 12) [IssueNumber 15] "split work"] [IssueDependency (IssueNumber 12) [IssueNumber 15]]
  executeRequestCase = do
    (executor, getCalls) <- fakeActionExecutor
    let runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 980
        options = DaemonOptions "/tmp/events.jsonl" runtimeConfig ExecuteActions
        observation = DaemonIssuePlanningObservation (ObservedPlanningIssuesRequested (request :| []))
        expectedEvent = IssuePlanningIssuesRequested (request :| [])
        expectedCommand = GhIssueCreate config.plannerRepo request
        expectedAppend = FakeAppendJsonLine "/tmp/events.jsonl" (toJSON expectedEvent)
        expectedCompiled = compileEffectPlan runtimeConfig [SomeEffect (CreateIssue config.plannerRepo request), SomeEffect SleepUntilNextPoll]
    result <- runObservedDaemonTickWithEvents executor options events observation
    calls <- getCalls
    case result of
      Right tick -> do
        let expectedWrites = compatibilityStateWrites (runtimeStateDirPath runtimeConfig.effectRuntimeStateDir) tick.daemonObservedState
            expectedWriteCalls = [FakeWriteJson (compatibilityWritePath write) (compatibilityWriteValue write) | write <- expectedWrites]
        results <-
          sequence
            [ assert "indexed issue-planning daemon execute active issue requests commits compatibility event" $
                tick.daemonObservedEvent == expectedEvent
                  && tick.daemonObservedCommittedEvents == [expectedEvent]
                  && workflowStateLabel @MoifoldSpec tick.daemonObservedState == "IssuePlanning/Initialized"
            , assert "indexed issue-planning daemon execute active issue requests creates issues before append" $
                tick.daemonObservedCompiledEffects == expectedCompiled
                  && callBefore (FakeCommand expectedCommand) expectedAppend calls
            , assert "indexed issue-planning daemon execute active issue requests writes compatibility before post sleep" $
                tick.daemonObservedCompatibilityWrites == expectedWrites
                  && all (`elem` calls) expectedWriteCalls
                  && all (\writeCall -> callBefore expectedAppend writeCall calls) expectedWriteCalls
                  && callBefore expectedAppend FakeSleep calls
            , assert "indexed issue-planning daemon execute active issue requests keeps audit labels" $
                WorkflowAudit.workflowAuditPriorStateLabel tick.daemonObservedAudit == "IssuePlanning/PlanMode"
                  && WorkflowAudit.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just "issue_planning_issues_requested"
                  && WorkflowAudit.workflowAuditFinalStateLabel tick.daemonObservedAudit == Just "IssuePlanning/Initialized"
            ]
        pure (and results)
      Left failure -> do
        putStrLn ("FAIL indexed issue-planning daemon execute active issue requests: " <> Text.unpack (formatDaemonFailure failure))
        pure False
  executeGraphCase = do
    (executor, getCalls) <- fakeActionExecutor
    let runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 990
        options = DaemonOptions "/tmp/events.jsonl" runtimeConfig ExecuteActions
        observation = DaemonIssuePlanningObservation (ObservedPlanningGraphUpdated graph)
        expectedEvent = IssuePlanningGraphUpdated graph
        expectedAppend = FakeAppendJsonLine "/tmp/events.jsonl" (toJSON expectedEvent)
        expectedCompiled = compileEffectPlan runtimeConfig [SomeEffect (RecordPlanningGraph graph), SomeEffect SleepUntilNextPoll]
        graphPath = runtimeStateDirFile runtimeConfig.effectRuntimeStateDir "planning-state.json"
        graphWrite = FakeWriteJson graphPath (toJSON graph)
    result <- runObservedDaemonTickWithEvents executor options events observation
    calls <- getCalls
    case result of
      Right tick -> do
        let expectedWrites = compatibilityStateWrites (runtimeStateDirPath runtimeConfig.effectRuntimeStateDir) tick.daemonObservedState
            expectedWriteCalls = [FakeWriteJson (compatibilityWritePath write) (compatibilityWriteValue write) | write <- expectedWrites]
        results <-
          sequence
            [ assert "indexed issue-planning daemon execute active graph update commits compatibility event" $
                tick.daemonObservedEvent == expectedEvent
                  && tick.daemonObservedCommittedEvents == [expectedEvent]
                  && workflowStateLabel @MoifoldSpec tick.daemonObservedState == "IssuePlanning/Initialized"
                  && runtimeWritesContainPlanningGraph graph tick.daemonObservedCompatibilityWrites
            , assert "indexed issue-planning daemon execute active graph update records graph after append" $
                tick.daemonObservedCompiledEffects == expectedCompiled
                  && graphWrite `elem` calls
                  && length [() | FakeWriteJson path value <- calls, path == graphPath, value == toJSON graph] == 2
                  && callBefore expectedAppend graphWrite calls
            , assert "indexed issue-planning daemon execute active graph update writes compatibility after append" $
                tick.daemonObservedCompatibilityWrites == expectedWrites
                  && all (`elem` calls) expectedWriteCalls
                  && all (\writeCall -> callBefore expectedAppend writeCall calls) expectedWriteCalls
                  && callBefore expectedAppend FakeSleep calls
            , assert "indexed issue-planning daemon execute active graph update keeps audit labels" $
                WorkflowAudit.workflowAuditPriorStateLabel tick.daemonObservedAudit == "IssuePlanning/PlanMode"
                  && WorkflowAudit.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just "issue_planning_graph_updated"
                  && WorkflowAudit.workflowAuditFinalStateLabel tick.daemonObservedAudit == Just "IssuePlanning/Initialized"
            ]
        pure (and results)
      Left failure -> do
        putStrLn ("FAIL indexed issue-planning daemon execute active graph update: " <> Text.unpack (formatDaemonFailure failure))
        pure False

workflowIssuePlanningIndexedDaemonRejectsInvalidTurnStart :: IO Bool
workflowIssuePlanningIndexedDaemonRejectsInvalidTurnStart = do
  (executor, getCalls) <- fakeActionExecutor
  let config = issuePlanningIndexedConfig
      threadId = ThreadId "planner-thread"
      turnId = TurnId "planner-turn"
      secondTurnId = TurnId "planner-turn-2"
      state = SomeWatcherState (PlanningTurnActive config (ActiveTurn threadId turnId))
      events = [IssuePlanningInitialized config, IssuePlanningTurnStarted threadId turnId]
      observation = DaemonIssuePlanningObservation (ObservedPlanningTurnStarted threadId secondTurnId)
      runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 950
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
  result <- runObservedDaemonTickWithEvents executor options events observation
  calls <- getCalls
  let directFailure = workflowPlanObservation @MoifoldSpec state observation
      indexedFailure = projectIssuePlanningTurnStartedObservation state threadId secondTurnId
  results <-
    sequence
      [ assert "indexed issue-planning daemon rejects turn start outside ready state like compatibility" $
          case (result, directFailure, indexedFailure) of
            (Left (DaemonObservationRejected daemonFailure), Left compatibilityFailure, Left projectionFailure) ->
              daemonFailure == compatibilityFailure
                && projectionFailure == compatibilityFailure
                && "ObservedPlanningTurnStarted" `Text.isInfixOf` daemonFailure
            _ -> False
      , assert "indexed issue-planning daemon invalid turn start commits no event" (null calls)
      ]
  pure (and results)

workflowIssuePlanningIndexedDaemonRejectsInvalidActiveTurnRoutingLikeCompatibility :: IO Bool
workflowIssuePlanningIndexedDaemonRejectsInvalidActiveTurnRoutingLikeCompatibility = do
  wrongIssueResult <- wrongSourceCase "issue requests" wrongIssueObservation (projectIssuePlanningIssuesRequestedObservation readyState (request :| []))
  wrongGraphResult <- wrongSourceCase "graph updates" wrongGraphObservation (projectIssuePlanningGraphUpdatedObservation readyState validGraph)
  invalidGraphResult <- invalidGraphBlocksLikeCompatibility
  pure (wrongIssueResult && wrongGraphResult && invalidGraphResult)
 where
  config = issuePlanningIndexedConfig
  threadId = ThreadId "planner-thread"
  turnId = TurnId "planner-turn"
  readyState = SomeWatcherState (PlanningReady config)
  readyEvents = [IssuePlanningInitialized config]
  activeEvents = [IssuePlanningInitialized config, IssuePlanningTurnStarted threadId turnId]
  request = IssueCreationRequest "split parser work" "Implement parser support." (Just (IssueNumber 12))
  validGraph = PlanningGraph [IssueNumber 15] [] []
  invalidGraph = PlanningGraph [IssueNumber 15, IssueNumber 15] [] []
  invalidReason = "planning graph has duplicate ready issue #15"
  wrongIssueObservation = DaemonIssuePlanningObservation (ObservedPlanningIssuesRequested (request :| []))
  wrongGraphObservation = DaemonIssuePlanningObservation (ObservedPlanningGraphUpdated validGraph)
  wrongSourceCase caseName observation projectionFailure = do
    (executor, getCalls) <- fakeActionExecutor
    let options = DaemonOptions "/tmp/events.jsonl" (effectRuntimeConfig config.plannerRepo "/tmp/work" 1000) DryRunActions
    result <- runObservedDaemonTickWithEvents executor options readyEvents observation
    calls <- getCalls
    let directFailure = workflowPlanObservation @MoifoldSpec readyState observation
    results <-
      sequence
        [ assert ("indexed issue-planning daemon rejects wrong-source active " <> caseName <> " like compatibility") $
            case (result, directFailure, projectionFailure) of
              (Left (DaemonObservationRejected daemonFailure), Left compatibilityFailure, Left indexedFailure) ->
                daemonFailure == compatibilityFailure
                  && indexedFailure == compatibilityFailure
              _ -> False
        , assert ("indexed issue-planning daemon wrong-source active " <> caseName <> " commits no event") (null calls)
        ]
    pure (and results)
  invalidGraphBlocksLikeCompatibility = do
    (executor, getCalls) <- fakeActionExecutor
    let runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 1010
        options = DaemonOptions "/tmp/events.jsonl" runtimeConfig ExecuteActions
        observation = DaemonIssuePlanningObservation (ObservedPlanningGraphUpdated invalidGraph)
        expectedEvent = WatcherBlocked (BlockedReason invalidReason)
        expectedAppend = FakeAppendJsonLine "/tmp/events.jsonl" (toJSON expectedEvent)
    result <- runObservedDaemonTickWithEvents executor options activeEvents observation
    calls <- getCalls
    case
      ( result
      , workflowPlanObservation @MoifoldSpec (SomeWatcherState (PlanningTurnActive config (ActiveTurn threadId turnId))) observation
      , projectIssuePlanningGraphUpdatedObservation (SomeWatcherState (PlanningTurnActive config (ActiveTurn threadId turnId))) invalidGraph
      )
      of
      (Right tick, Right compatibilityPlan, Right projection) -> do
        let expectedWrites = compatibilityStateWrites (runtimeStateDirPath runtimeConfig.effectRuntimeStateDir) tick.daemonObservedState
            expectedWriteCalls = [FakeWriteJson (compatibilityWritePath write) (compatibilityWriteValue write) | write <- expectedWrites]
        results <-
          sequence
            [ assert "indexed issue-planning daemon invalid graph records blocked event through active route" $
                tick.daemonObservedEvent == expectedEvent
                  && tick.daemonObservedEvent == compatibilityPlan.plannedEvent
                  && tick.daemonObservedEvent == projection.issuePlanningIndexedProjectionPlanned.plannedEvent
                  && tick.daemonObservedCommittedEvents == [expectedEvent]
                  && workflowStateLabel @MoifoldSpec tick.daemonObservedState == "IssuePlanning/Blocked"
                  && projection.issuePlanningIndexedProjectionTargetLabel == "IssuePlanning/Blocked"
            , assert "indexed issue-planning daemon invalid graph preserves blocked effect ordering and writes" $
                blockedPostCommitPlan compatibilityPlan
                  && all (`elem` calls) expectedWriteCalls
                  && all (\writeCall -> callBefore expectedAppend writeCall calls) expectedWriteCalls
                  && callBefore expectedAppend FakeStop calls
            , assert "indexed issue-planning daemon invalid graph keeps audit labels" $
                WorkflowAudit.workflowAuditPriorStateLabel tick.daemonObservedAudit == "IssuePlanning/PlanMode"
                  && WorkflowAudit.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just "watcher_blocked"
                  && WorkflowAudit.workflowAuditFinalStateLabel tick.daemonObservedAudit == Just "IssuePlanning/Blocked"
            ]
        pure (and results)
      (Left failure, _, _) -> do
        putStrLn ("FAIL indexed issue-planning daemon invalid graph: " <> Text.unpack (formatDaemonFailure failure))
        pure False
      _ ->
        assert "indexed issue-planning daemon invalid graph prepares compatibility and indexed plans" False

workflowIssuePlanningIndexedDaemonRejectsInvalidTerminalAndRetryRoutingLikeCompatibility :: IO Bool
workflowIssuePlanningIndexedDaemonRejectsInvalidTerminalAndRetryRoutingLikeCompatibility = do
  results <-
    sequence
      [ invalidRouteCase
          "ready issues fixed"
          readyEvents
          readyState
          (DaemonIssuePlanningObservation ObservedPlanningReadyIssuesFixed)
          (projectIssuePlanningReadyIssuesFixedObservation readyState)
      , invalidRouteCase
          "scope completed"
          activeEvents
          activeState
          (DaemonIssuePlanningObservation ObservedPlanningScopeCompleted)
          (projectIssuePlanningScopeCompletedObservation activeState)
      , invalidRouteCase
          "retry"
          readyEvents
          readyState
          (DaemonIssuePlanningObservation (ObservedPlanningTurnRetryRequested retryReason))
          (projectIssuePlanningTurnRetryObservation readyState retryReason)
      , invalidRouteCase
          "turn completed"
          readyEvents
          readyState
          (DaemonIssuePlanningObservation ObservedPlanningTurnCompleted)
          (projectIssuePlanningTurnCompletedObservation readyState)
      , invalidRouteCase
          "blocked from terminal complete"
          completeEvents
          completeState
          blockedObservation
          (projectIssuePlanningBlockedInitializedObservation completeState blockedReason)
      ]
  pure (and results)
 where
  config = issuePlanningIndexedConfig
  threadId = ThreadId "planner-thread"
  turnId = TurnId "planner-turn"
  readyState = SomeWatcherState (PlanningReady config)
  activeState = SomeWatcherState (PlanningTurnActive config (ActiveTurn threadId turnId))
  completeState = SomeWatcherState (CompleteState PlanningComplete :: WatcherState 'IssuePlanning 'Complete)
  readyEvents = [IssuePlanningInitialized config]
  activeEvents = readyEvents <> [IssuePlanningTurnStarted threadId turnId]
  completeEvents = readyEvents <> [IssuePlanningScopeCompleted]
  retryReason = BlockedReason "retry planning turn"
  blockedReason = BlockedReason "block planning"
  blockedObservation = DaemonIssuePlanningObservation (ObservedPlanningBlocked blockedReason)
  invalidRouteCase caseName events state observation projectionFailure = do
    (executor, getCalls) <- fakeActionExecutor
    let options = DaemonOptions "/tmp/events.jsonl" (effectRuntimeConfig config.plannerRepo "/tmp/work" 1050) DryRunActions
    result <- runObservedDaemonTickWithEvents executor options events observation
    calls <- getCalls
    let directFailure = workflowPlanObservation @MoifoldSpec state observation
    checks <-
      sequence
        [ assert ("indexed issue-planning daemon rejects invalid terminal/retry " <> caseName <> " like compatibility") $
            case (result, directFailure, projectionFailure) of
              (Left (DaemonObservationRejected daemonFailure), Left compatibilityFailure, Left indexedFailure) ->
                daemonFailure == compatibilityFailure
                  && indexedFailure == compatibilityFailure
              _ -> False
        , assert ("indexed issue-planning daemon invalid terminal/retry " <> caseName <> " commits no event") (null calls)
        ]
    pure (and checks)

workflowIssuePlanningIndexedDaemonDryRunMatchesTerminalAndRetryCompatibility :: IO Bool
workflowIssuePlanningIndexedDaemonDryRunMatchesTerminalAndRetryCompatibility = do
  results <-
    sequence
      [ dryRunRouteCase
          "ready issues fixed"
          waitingEvents
          waitingState
          (DaemonIssuePlanningObservation ObservedPlanningReadyIssuesFixed)
          (projectIssuePlanningReadyIssuesFixedObservation waitingState)
          IssuePlanningReadyIssuesFixed
          [SomeEffect SleepUntilNextPoll]
          "IssuePlanning/Initialized"
      , dryRunRouteCase
          "scope completed"
          readyEvents
          readyState
          (DaemonIssuePlanningObservation ObservedPlanningScopeCompleted)
          (projectIssuePlanningScopeCompletedObservation readyState)
          IssuePlanningScopeCompleted
          [SomeEffect StopDaemon]
          "IssuePlanning/Complete"
      , dryRunRouteCase
          "retry"
          activeEvents
          activeState
          (DaemonIssuePlanningObservation (ObservedPlanningTurnRetryRequested retryReason))
          (projectIssuePlanningTurnRetryObservation activeState retryReason)
          (IssuePlanningTurnRetryRequested retryReason)
          [SomeEffect SleepUntilNextPoll]
          "IssuePlanning/Initialized"
      , dryRunRouteCase
          "turn completed"
          activeEvents
          activeState
          (DaemonIssuePlanningObservation ObservedPlanningTurnCompleted)
          (projectIssuePlanningTurnCompletedObservation activeState)
          IssuePlanningTurnCompleted
          [SomeEffect StopDaemon]
          "IssuePlanning/Complete"
      , dryRunRouteCase
          "initialized blocked"
          readyEvents
          readyState
          blockedObservation
          (projectIssuePlanningBlockedInitializedObservation readyState blockedReason)
          (WatcherBlocked blockedReason)
          blockedEffects
          "IssuePlanning/Blocked"
      , dryRunRouteCase
          "active blocked"
          activeEvents
          activeState
          blockedObservation
          (projectIssuePlanningBlockedActiveTurnObservation activeState blockedReason)
          (WatcherBlocked blockedReason)
          blockedEffects
          "IssuePlanning/Blocked"
      , dryRunRouteCase
          "waiting blocked"
          waitingEvents
          waitingState
          blockedObservation
          (projectIssuePlanningBlockedWaitingReadyIssuesObservation waitingState blockedReason)
          (WatcherBlocked blockedReason)
          blockedEffects
          "IssuePlanning/Blocked"
      ]
  pure (and results)
 where
  config = issuePlanningIndexedConfig
  threadId = ThreadId "planner-thread"
  turnId = TurnId "planner-turn"
  graph = PlanningGraph [IssueNumber 12] [] []
  readyState = SomeWatcherState (PlanningReady config)
  activeState = SomeWatcherState (PlanningTurnActive config (ActiveTurn threadId turnId))
  waitingState = SomeWatcherState (PlanningWaitingForReadyIssues config graph)
  readyEvents = [IssuePlanningInitialized config]
  activeEvents = readyEvents <> [IssuePlanningTurnStarted threadId turnId]
  waitingEvents = activeEvents <> [IssuePlanningGraphUpdated graph]
  retryReason = BlockedReason "retry planning turn"
  blockedReason = BlockedReason "block planning"
  blockedObservation = DaemonIssuePlanningObservation (ObservedPlanningBlocked blockedReason)
  blockedEffects = [SomeEffect (RecordBlocked blockedReason), SomeEffect StopDaemon]
  dryRunRouteCase caseName events state observation projection expectedEvent expectedEffects expectedTargetLabel = do
    (executor, getCalls) <- fakeActionExecutor
    let runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 1030
        options = DaemonOptions "/tmp/events.jsonl" runtimeConfig DryRunActions
        expectedCompiled = compileEffectPlan runtimeConfig expectedEffects
        expectedReports = dryRunCompiledEffectPlan expectedCompiled
    result <- runObservedDaemonTickWithEvents executor options events observation
    calls <- getCalls
    case (result, workflowPlanObservation @MoifoldSpec state observation, projection) of
      (Right tick, Right compatibilityPlan, Right projected) -> do
        let expectedWrites = compatibilityStateWrites (runtimeStateDirPath runtimeConfig.effectRuntimeStateDir) tick.daemonObservedState
            audit = tick.daemonObservedAudit
        checks <-
          sequence
            [ assert ("indexed issue-planning daemon dry-run " <> caseName <> " emits compatibility event") $
                tick.daemonObservedEvent == expectedEvent
                  && tick.daemonObservedEvent == compatibilityPlan.plannedEvent
                  && tick.daemonObservedEvent == projected.issuePlanningIndexedProjectionPlanned.plannedEvent
            , assert ("indexed issue-planning daemon dry-run " <> caseName <> " reaches projected state") $
                workflowStateLabel @MoifoldSpec tick.daemonObservedState == expectedTargetLabel
                  && sameWatcherStateShape tick.daemonObservedState projected.issuePlanningIndexedProjectionFinalState
                  && sameWatcherStateShape tick.daemonObservedReplayResult.replayState state
            , assert ("indexed issue-planning daemon dry-run " <> caseName <> " keeps reports, writes, and audit stable") $
                tick.daemonObservedCommittedEvents == []
                  && tick.daemonObservedCompiledEffects == expectedCompiled
                  && tick.daemonObservedActionReports == expectedReports
                  && tick.daemonObservedCompatibilityWrites == expectedWrites
                  && WorkflowAudit.workflowAuditCommittedEventLabel audit == Nothing
                  && WorkflowAudit.workflowAuditPriorStateLabel audit == workflowStateLabel @MoifoldSpec state
                  && WorkflowAudit.workflowAuditFinalStateLabel audit == Just expectedTargetLabel
            , assert ("indexed issue-planning daemon dry-run " <> caseName <> " does not mutate runtime state") (null calls)
            ]
        pure (and checks)
      (Left failure, _, _) -> do
        putStrLn ("FAIL indexed issue-planning daemon dry-run " <> caseName <> ": " <> Text.unpack (formatDaemonFailure failure))
        pure False
      _ ->
        assert ("indexed issue-planning daemon dry-run " <> caseName <> " prepares compatibility and indexed plans") False

workflowIssuePlanningIndexedDaemonExecuteMatchesTerminalAndRetryCompatibility :: IO Bool
workflowIssuePlanningIndexedDaemonExecuteMatchesTerminalAndRetryCompatibility = do
  results <-
    sequence
      [ executeRouteCase
          "ready issues fixed"
          waitingEvents
          waitingState
          (DaemonIssuePlanningObservation ObservedPlanningReadyIssuesFixed)
          IssuePlanningReadyIssuesFixed
          [SomeEffect SleepUntilNextPoll]
          "IssuePlanning/Initialized"
          (Just FakeSleep)
      , executeRouteCase
          "scope completed"
          readyEvents
          readyState
          (DaemonIssuePlanningObservation ObservedPlanningScopeCompleted)
          IssuePlanningScopeCompleted
          [SomeEffect StopDaemon]
          "IssuePlanning/Complete"
          (Just FakeStop)
      , executeRouteCase
          "retry"
          activeEvents
          activeState
          (DaemonIssuePlanningObservation (ObservedPlanningTurnRetryRequested retryReason))
          (IssuePlanningTurnRetryRequested retryReason)
          [SomeEffect SleepUntilNextPoll]
          "IssuePlanning/Initialized"
          (Just FakeSleep)
      , executeRouteCase
          "turn completed"
          activeEvents
          activeState
          (DaemonIssuePlanningObservation ObservedPlanningTurnCompleted)
          IssuePlanningTurnCompleted
          [SomeEffect StopDaemon]
          "IssuePlanning/Complete"
          (Just FakeStop)
      , executeRouteCase
          "initialized blocked"
          readyEvents
          readyState
          blockedObservation
          (WatcherBlocked blockedReason)
          blockedEffects
          "IssuePlanning/Blocked"
          (Just FakeStop)
      , executeRouteCase
          "active blocked"
          activeEvents
          activeState
          blockedObservation
          (WatcherBlocked blockedReason)
          blockedEffects
          "IssuePlanning/Blocked"
          (Just FakeStop)
      , executeRouteCase
          "waiting blocked"
          waitingEvents
          waitingState
          blockedObservation
          (WatcherBlocked blockedReason)
          blockedEffects
          "IssuePlanning/Blocked"
          (Just FakeStop)
      ]
  pure (and results)
 where
  config = issuePlanningIndexedConfig
  threadId = ThreadId "planner-thread"
  turnId = TurnId "planner-turn"
  graph = PlanningGraph [IssueNumber 12] [] []
  readyState = SomeWatcherState (PlanningReady config)
  activeState = SomeWatcherState (PlanningTurnActive config (ActiveTurn threadId turnId))
  waitingState = SomeWatcherState (PlanningWaitingForReadyIssues config graph)
  readyEvents = [IssuePlanningInitialized config]
  activeEvents = readyEvents <> [IssuePlanningTurnStarted threadId turnId]
  waitingEvents = activeEvents <> [IssuePlanningGraphUpdated graph]
  retryReason = BlockedReason "retry planning turn"
  blockedReason = BlockedReason "block planning"
  blockedObservation = DaemonIssuePlanningObservation (ObservedPlanningBlocked blockedReason)
  blockedEffects = [SomeEffect (RecordBlocked blockedReason), SomeEffect StopDaemon]
  executeRouteCase caseName events state observation expectedEvent expectedEffects expectedTargetLabel expectedPostCall = do
    (executor, getCalls) <- fakeActionExecutor
    let runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 1040
        options = DaemonOptions "/tmp/events.jsonl" runtimeConfig ExecuteActions
        expectedCompiled = compileEffectPlan runtimeConfig expectedEffects
        expectedAppend = FakeAppendJsonLine "/tmp/events.jsonl" (toJSON expectedEvent)
    result <- runObservedDaemonTickWithEvents executor options events observation
    calls <- getCalls
    case (result, workflowPlanObservation @MoifoldSpec state observation) of
      (Right tick, Right compatibilityPlan) -> do
        let expectedWrites = compatibilityStateWrites (runtimeStateDirPath runtimeConfig.effectRuntimeStateDir) tick.daemonObservedState
            expectedWriteCalls = [FakeWriteJson (compatibilityWritePath write) (compatibilityWriteValue write) | write <- expectedWrites]
            postCallOk =
              case expectedPostCall of
                Nothing -> True
                Just call -> callBefore expectedAppend call calls
        checks <-
          sequence
            [ assert ("indexed issue-planning daemon execute " <> caseName <> " commits compatibility event") $
                tick.daemonObservedEvent == expectedEvent
                  && tick.daemonObservedEvent == compatibilityPlan.plannedEvent
                  && tick.daemonObservedCommittedEvents == [expectedEvent]
                  && expectedAppend `elem` calls
            , assert ("indexed issue-planning daemon execute " <> caseName <> " reaches target state") $
                workflowStateLabel @MoifoldSpec tick.daemonObservedState == expectedTargetLabel
            , assert ("indexed issue-planning daemon execute " <> caseName <> " writes compatibility after append") $
                tick.daemonObservedCompiledEffects == expectedCompiled
                  && tick.daemonObservedCompatibilityWrites == expectedWrites
                  && all (`elem` calls) expectedWriteCalls
                  && all (\writeCall -> callBefore expectedAppend writeCall calls) expectedWriteCalls
                  && postCallOk
            , assert ("indexed issue-planning daemon execute " <> caseName <> " keeps audit labels") $
                WorkflowAudit.workflowAuditPriorStateLabel tick.daemonObservedAudit == workflowStateLabel @MoifoldSpec state
                  && WorkflowAudit.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just (eventName expectedEvent)
                  && WorkflowAudit.workflowAuditFinalStateLabel tick.daemonObservedAudit == Just expectedTargetLabel
            ]
        pure (and checks)
      (Left failure, _) -> do
        putStrLn ("FAIL indexed issue-planning daemon execute " <> caseName <> ": " <> Text.unpack (formatDaemonFailure failure))
        pure False
      _ ->
        assert ("indexed issue-planning daemon execute " <> caseName <> " prepares compatibility plan") False

issuePlanningIndexedSpecMatchesCompatibility
  :: forall (source :: Type) (target :: Type).
     String
  -> SomeWatcherState
  -> [WatcherEvent]
  -> [IndexedWorkflow.SomeIndexedWorkflowEvent IssuePlanningIndexedSpec]
  -> IssuePlanningObservation
  -> IssuePlanningIndexedObservation source target
  -> WatcherEvent
  -> IssuePlanningIndexedEvent source target
  -> Text
  -> (PlannedTransition MoifoldSpec -> Bool)
  -> (WorkflowExecution.WorkflowCompiledEffectPlan -> Bool)
  -> ([CompatibilityWrite] -> Bool)
  -> IO Bool
issuePlanningIndexedSpecMatchesCompatibility title state replayPrefix indexedReplayPrefix facadeObservation indexedObservation expectedEvent indexedEvent expectedTargetLabel planCheck compiledCheck writeCheck =
  assert title $
    case
      ( issuePlanningObserve state facadeObservation
      , workflowObserve @MoifoldSpec state observation
      , workflowPlanObservation @MoifoldSpec state observation
      , IndexedWorkflow.indexedWorkflowObserve @IssuePlanningIndexedSpec indexedState indexedObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @IssuePlanningIndexedSpec indexedState indexedObservation
      , workflowApplyEvent @MoifoldSpec state expectedEvent
      , IndexedWorkflow.indexedWorkflowApplyEvent @IssuePlanningIndexedSpec indexedState indexedEvent
      , workflowReplayEvents @MoifoldSpec (replayPrefix <> [expectedEvent])
      , IndexedWorkflow.indexedWorkflowReplayEvents @IssuePlanningIndexedSpec
          (indexedReplayPrefix <> [IndexedWorkflow.SomeIndexedWorkflowEvent indexedEvent])
      )
      of
      ( Right facadeObserved
        , Right compatibilityObserved
        , Right compatibilityPlan
        , Right indexedObserved
        , Right indexedPlan
        , Right (appliedState, appliedEffects)
        , Right (IssuePlanningIndexedState indexedAppliedState, IssuePlanningIndexedEffectPlan indexedAppliedEffects)
        , Right compatibilityReplay
        , Right indexedReplay
        ) ->
          let IssuePlanningIndexedState indexedNextState =
                IndexedWorkflow.indexedWorkflowObservedState @IssuePlanningIndexedSpec indexedObserved
              indexedReplayResultValue = issuePlanningIndexedReplayResult indexedReplay
              wrappedTransition = IndexedWorkflow.SomeIndexedPlannedTransition indexedPlan
              projectedPlan = issuePlanningIndexedTransitionToCompatibility indexedPlan
              fullCompatibilityPlan = compatibilityPlan.plannedPreCommitEffects <> compatibilityPlan.plannedPostCommitEffects
              indexedFullPlan =
                IssuePlanningIndexedEffectPlan fullCompatibilityPlan
                  :: IssuePlanningIndexedEffectPlan source target
              runtimeConfig = effectRuntimeConfig issuePlanningIndexedConfig.plannerRepo "/tmp/work" 900
              workflowCompiled = WorkflowExecution.compileWorkflowEffectPlanWithMetadata runtimeConfig fullCompatibilityPlan
              legacyCompiled = compileEffectPlan runtimeConfig fullCompatibilityPlan
              compatibilityWrites = compatibilityStateWrites "/tmp/state" compatibilityObserved.observedState
              indexedWrites = compatibilityStateWrites "/tmp/state" indexedNextState
           in facadeObserved.issuePlanningTickEvent == compatibilityObserved.observedEvent
                && facadeObserved.issuePlanningTickEffects == compatibilityObserved.observedEffects
                && sameWatcherStateShape facadeObserved.issuePlanningTickState compatibilityObserved.observedState
                && compatibilityObserved.observedEvent == expectedEvent
                && projectedPlan.plannedEvent == compatibilityPlan.plannedEvent
                && projectedPlan.plannedEvent == expectedEvent
                && IndexedWorkflow.someIndexedWorkflowTransitionSourceLabel @IssuePlanningIndexedSpec wrappedTransition == workflowStateLabel @MoifoldSpec state
                && IndexedWorkflow.someIndexedWorkflowTransitionTargetLabel @IssuePlanningIndexedSpec wrappedTransition == expectedTargetLabel
                && workflowStateLabel @MoifoldSpec indexedNextState == workflowStateLabel @MoifoldSpec compatibilityObserved.observedState
                && sameWatcherStateShape compatibilityObserved.observedState indexedNextState
                && sameWatcherStateShape compatibilityObserved.observedState appliedState
                && sameWatcherStateShape appliedState indexedAppliedState
                && projectedPlan.plannedPreCommitEffects == compatibilityPlan.plannedPreCommitEffects
                && projectedPlan.plannedPostCommitEffects == compatibilityPlan.plannedPostCommitEffects
                && fullCompatibilityPlan == compatibilityObserved.observedEffects
                && appliedEffects == fullCompatibilityPlan
                && indexedAppliedEffects == fullCompatibilityPlan
                && planCheck compatibilityPlan
                && IndexedWorkflow.indexedWorkflowPlannedTransitionPreCommitEffectLabels @IssuePlanningIndexedSpec indexedPlan
                  == fmap (workflowEffectLabel @MoifoldSpec) compatibilityPlan.plannedPreCommitEffects
                && IndexedWorkflow.indexedWorkflowPlannedTransitionPostCommitEffectLabels @IssuePlanningIndexedSpec indexedPlan
                  == fmap (workflowEffectLabel @MoifoldSpec) compatibilityPlan.plannedPostCommitEffects
                && workflowValidateEffects @MoifoldSpec state fullCompatibilityPlan
                  == IndexedWorkflow.indexedWorkflowValidateEffects @IssuePlanningIndexedSpec indexedState indexedFullPlan
                && all
                  ( \effect ->
                      workflowEffectAllowed @MoifoldSpec state effect
                        == IndexedWorkflow.indexedWorkflowEffectAllowed @IssuePlanningIndexedSpec indexedState (IssuePlanningIndexedEffect effect)
                  )
                  fullCompatibilityPlan
                && fmap WorkflowExecution.workflowPlannedAction workflowCompiled.workflowCompiledActions == legacyCompiled.compiledActions
                && WorkflowExecution.dryRunWorkflowCompiledEffectPlan workflowCompiled == dryRunCompiledEffectPlan legacyCompiled
                && compiledCheck workflowCompiled
                && sameWatcherStateShape compatibilityReplay.replayState indexedReplayResultValue.replayState
                && workflowStateLabel @MoifoldSpec compatibilityReplay.replayState == workflowStateLabel @MoifoldSpec indexedReplayResultValue.replayState
                && compatibilityReplay.replayEffects == indexedReplayResultValue.replayEffects
                && compatibilityWrites == indexedWrites
                && writeCheck indexedWrites
      _ -> False
 where
  indexedState =
    IssuePlanningIndexedState state
      :: IssuePlanningIndexedState source
  observation = DaemonIssuePlanningObservation facadeObservation

issuePlanningIndexedReplayResult :: IndexedWorkflow.SomeIndexedWorkflowReplayResult IssuePlanningIndexedSpec -> EventReplayResult
issuePlanningIndexedReplayResult (IndexedWorkflow.SomeIndexedWorkflowReplayResult (IssuePlanningIndexedReplayResult replay)) =
  replay

issuePlanningIndexedConfig :: PlannerConfig
issuePlanningIndexedConfig =
  PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 4) [IssueNumber 12]

issuePlanningIndexedInitializedEvent :: PlannerConfig -> IndexedWorkflow.SomeIndexedWorkflowEvent IssuePlanningIndexedSpec
issuePlanningIndexedInitializedEvent config =
  IndexedWorkflow.SomeIndexedWorkflowEvent
    ( IssuePlanningIndexedEvent "IssuePlanning/Uninitialized" "IssuePlanning/Initialized" (IssuePlanningInitialized config)
        :: IssuePlanningIndexedEvent IssuePlanningIndexedInitialized IssuePlanningIndexedInitialized
    )

issuePlanningIndexedTurnStartedEvent :: ThreadId -> TurnId -> IndexedWorkflow.SomeIndexedWorkflowEvent IssuePlanningIndexedSpec
issuePlanningIndexedTurnStartedEvent threadId turnId =
  IndexedWorkflow.SomeIndexedWorkflowEvent
    ( IssuePlanningIndexedEvent "IssuePlanning/Initialized" "IssuePlanning/PlanMode" (IssuePlanningTurnStarted threadId turnId)
        :: IssuePlanningIndexedEvent IssuePlanningIndexedInitialized IssuePlanningIndexedActiveTurn
    )

issuePlanningIndexedGraphUpdatedEvent :: PlanningGraph -> IndexedWorkflow.SomeIndexedWorkflowEvent IssuePlanningIndexedSpec
issuePlanningIndexedGraphUpdatedEvent graph =
  IndexedWorkflow.SomeIndexedWorkflowEvent
    ( IssuePlanningIndexedEvent "IssuePlanning/PlanMode" "IssuePlanning/Initialized" (IssuePlanningGraphUpdated graph)
        :: IssuePlanningIndexedEvent IssuePlanningIndexedActiveTurn IssuePlanningIndexedWaitingReadyIssues
    )

compatibilityWritesContainPlanningGraph :: PlanningGraph -> [CompatibilityWrite] -> Bool
compatibilityWritesContainPlanningGraph graph writes =
  CompatibilityWrite "/tmp/state/planning-state.json" (toJSON graph) `elem` writes

runtimeWritesContainPlanningGraph :: PlanningGraph -> [CompatibilityWrite] -> Bool
runtimeWritesContainPlanningGraph graph writes =
  any ((== toJSON graph) . compatibilityWriteValue) writes

data PrReviewMergeabilityGoldenSlice = PrReviewMergeabilityGoldenSlice
  { prReviewMergeabilityGoldenPrefix :: [WatcherEvent]
  , prReviewMergeabilityGoldenIndexedPrefix :: [IndexedWorkflow.SomeIndexedWorkflowEvent PrReviewMergeabilityIndexedSpec]
  , prReviewMergeabilityGoldenState :: SomeWatcherState
  , prReviewMergeabilityGoldenConfig :: PrConfig
  , prReviewMergeabilityGoldenEvidence :: CleanReviewEvidence
  , prReviewMergeabilityGoldenCommit :: CommitSha
  , prReviewMergeabilityGoldenMergeCommit :: MergeCommit
  }

loadPrReviewMergeabilityGoldenSlice :: IO (Either String PrReviewMergeabilityGoldenSlice)
loadPrReviewMergeabilityGoldenSlice = do
  loaded <- loadEventLogFile "golden/event-log/pr-review/mlf2-pr6-merged/events.jsonl"
  pure $ do
    events <- loaded
    let (prefix, suffix) = break isMergeabilityClean events
    commit <-
      case suffix of
        PrReviewMergeabilityClean cleanCommit : _ -> Right cleanCommit
        _ -> Left "golden PR-review lifecycle does not contain pr_review_mergeability_clean"
    mergeCommit <-
      case suffix of
        PrReviewMergeabilityClean _ : PrReviewMergeCompleted completedCommit : _ -> Right completedCommit
        _ -> Left "golden PR-review lifecycle does not contain pr_review_merge_completed after pr_review_mergeability_clean"
    indexedPrefix <- indexedPrReviewGoldenLifecyclePrefix prefix
    replay <-
      case workflowReplayEvents @MoifoldSpec prefix of
        Right replayResult -> Right replayResult
        Left failure -> Left (Text.unpack failure)
    case replay.replayState of
      SomeWatcherState (PrWaitingForMergeability prConfig cleanEvidence _worker _reviewer)
        | cleanReviewCommit cleanEvidence == commit ->
            Right
              PrReviewMergeabilityGoldenSlice
                { prReviewMergeabilityGoldenPrefix = prefix
                , prReviewMergeabilityGoldenIndexedPrefix = indexedPrefix
                , prReviewMergeabilityGoldenState = replay.replayState
                , prReviewMergeabilityGoldenConfig = prConfig
                , prReviewMergeabilityGoldenEvidence = cleanEvidence
                , prReviewMergeabilityGoldenCommit = commit
                , prReviewMergeabilityGoldenMergeCommit = mergeCommit
                }
        | otherwise ->
            Left "golden PR-review lifecycle mergeability commit does not match clean review commit"
      _ ->
        Left "golden PR-review lifecycle prefix does not replay to PrWaitingForMergeability"
 where
  isMergeabilityClean = \case
    PrReviewMergeabilityClean {} -> True
    _ -> False

indexedPrReviewGoldenLifecyclePrefix :: [WatcherEvent] -> Either String [IndexedWorkflow.SomeIndexedWorkflowEvent PrReviewMergeabilityIndexedSpec]
indexedPrReviewGoldenLifecyclePrefix = \case
  [ initialized@PrReviewInitialized {}
    , unresolved@PrReviewUnresolvedFound {}
    , fixCompleted@PrReviewFixCompleted
    , verificationStarted@PrReviewFixVerificationStarted {}
    , cleanFoundBeforeFinalCheck@PrReviewCleanFound {}
    , noUnresolved@PrReviewNoUnresolvedFound {}
    , cleanFound@PrReviewCleanFound {}
    ] ->
      Right
        [ IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewIndexedEvent "PrReview/Uninitialized" "PrReview/CheckingReviews" initialized
                :: PrReviewIndexedEvent PrReviewIndexedUninitialized PrReviewIndexedCheckingReviews
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewIndexedEvent "PrReview/CheckingReviews" "PrReview/FixingReviews" unresolved
                :: PrReviewIndexedEvent PrReviewIndexedCheckingReviews PrReviewIndexedFixingReviews
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewIndexedEvent "PrReview/FixingReviews" "PrReview/CheckingReviews" fixCompleted
                :: PrReviewIndexedEvent PrReviewIndexedFixingReviews PrReviewIndexedCheckingReviews
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewIndexedEvent "PrReview/CheckingReviews" "PrReview/ReviewingClean" verificationStarted
                :: PrReviewIndexedEvent PrReviewIndexedCheckingReviews PrReviewIndexedReviewingClean
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewIndexedEvent "PrReview/ReviewingClean" "PrReview/CheckingReviews" cleanFoundBeforeFinalCheck
                :: PrReviewIndexedEvent PrReviewIndexedReviewingClean PrReviewIndexedCheckingReviews
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewIndexedEvent "PrReview/CheckingReviews" "PrReview/ReviewingClean" noUnresolved
                :: PrReviewIndexedEvent PrReviewIndexedCheckingReviews PrReviewIndexedReviewingClean
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewIndexedEvent "PrReview/ReviewingClean" "PrReview/WaitingMergeability" cleanFound
                :: PrReviewIndexedEvent PrReviewIndexedReviewingClean PrReviewIndexedWaitingForMergeability
            )
        ]
  _ -> Left "golden PR-review lifecycle prefix shape changed before mergeability clean"

indexedPrReviewMergeabilityCleanEvent :: CommitSha -> IndexedWorkflow.SomeIndexedWorkflowEvent PrReviewMergeabilityIndexedSpec
indexedPrReviewMergeabilityCleanEvent commit =
  IndexedWorkflow.SomeIndexedWorkflowEvent
    ( PrReviewIndexedEvent "PrReview/WaitingMergeability" "PrReview/Merging" (PrReviewMergeabilityClean commit)
        :: PrReviewIndexedEvent PrReviewIndexedWaitingForMergeability PrReviewIndexedMerging
    )

indexedPrReviewMergeabilityCleanObservation
  :: CommitSha
  -> PrReviewIndexedObservation PrReviewIndexedWaitingForMergeability PrReviewIndexedMerging
indexedPrReviewMergeabilityCleanObservation commit =
  PrReviewIndexedObservation
    "PrReview/WaitingMergeability"
    "PrReview/Merging"
    (DaemonPrReviewObservation (ObservedMergeabilityClean commit))

workflowPrReviewMergeabilityIndexedSpecMatchesCompatibilityForWaitingOutcomes :: IO Bool
workflowPrReviewMergeabilityIndexedSpecMatchesCompatibilityForWaitingOutcomes = do
  loaded <- loadPrReviewMergeabilityGoldenSlice
  case loaded of
    Left failure -> assert "indexed workflow PR-review mergeability golden lifecycle loads for waiting outcomes" False <* putStrLn ("FAIL golden lifecycle: " <> failure)
    Right slice -> do
      let state = prReviewMergeabilityGoldenState slice
          commit = prReviewMergeabilityGoldenCommit slice
          prConfig = prReviewMergeabilityGoldenConfig slice
          retryReason = "mergeability still pending"
          recheckReason = "reviewed head changed"
          fixEvidence = reviewEvidenceFromSummaries ("merge latest base branch into the PR branch" :| []) commit
          retryObservation =
            PrReviewIndexedObservation
              "PrReview/WaitingMergeability"
              "PrReview/WaitingMergeability"
              (DaemonPrReviewObservation (ObservedMergeabilityRetry retryReason))
              :: PrReviewIndexedObservation PrReviewIndexedWaitingForMergeability PrReviewIndexedWaitingForMergeability
          retryEvent =
            PrReviewIndexedEvent "PrReview/WaitingMergeability" "PrReview/WaitingMergeability" (PrReviewMergeabilityWaiting retryReason)
              :: PrReviewIndexedEvent PrReviewIndexedWaitingForMergeability PrReviewIndexedWaitingForMergeability
          recheckObservation =
            PrReviewIndexedObservation
              "PrReview/WaitingMergeability"
              "PrReview/CheckingReviews"
              (DaemonPrReviewObservation (ObservedMergeabilityRecheck recheckReason))
              :: PrReviewIndexedObservation PrReviewIndexedWaitingForMergeability PrReviewIndexedCheckingReviews
          recheckEvent =
            PrReviewIndexedEvent "PrReview/WaitingMergeability" "PrReview/CheckingReviews" (PrReviewMergeabilityRecheck recheckReason)
              :: PrReviewIndexedEvent PrReviewIndexedWaitingForMergeability PrReviewIndexedCheckingReviews
          fixObservation =
            PrReviewIndexedObservation
              "PrReview/WaitingMergeability"
              "PrReview/FixingReviews"
              (DaemonPrReviewObservation (ObservedMergeabilityFixRequired fixEvidence))
              :: PrReviewIndexedObservation PrReviewIndexedWaitingForMergeability PrReviewIndexedFixingReviews
          fixEvent =
            PrReviewIndexedEvent "PrReview/WaitingMergeability" "PrReview/FixingReviews" (PrReviewMergeabilityFixRequired fixEvidence)
              :: PrReviewIndexedEvent PrReviewIndexedWaitingForMergeability PrReviewIndexedFixingReviews
      results <-
        sequence
          [ prReviewMergeabilityIndexedSpecMatchesCompatibility
              "indexed workflow PR-review mergeability retry matches compatibility"
              state
              slice.prReviewMergeabilityGoldenPrefix
              slice.prReviewMergeabilityGoldenIndexedPrefix
              (ObservedMergeabilityRetry retryReason)
              retryObservation
              "PrReview/WaitingMergeability"
              (PrReviewMergeabilityWaiting retryReason)
              retryEvent
              sleepPostCommitPlan
          , prReviewMergeabilityIndexedSpecMatchesCompatibility
              "indexed workflow PR-review mergeability recheck matches compatibility"
              state
              slice.prReviewMergeabilityGoldenPrefix
              slice.prReviewMergeabilityGoldenIndexedPrefix
              (ObservedMergeabilityRecheck recheckReason)
              recheckObservation
              "PrReview/CheckingReviews"
              (PrReviewMergeabilityRecheck recheckReason)
              recheckEvent
              (effectTagPlan [ReadReviewThreadsTag])
          , prReviewMergeabilityIndexedSpecMatchesCompatibility
              "indexed workflow PR-review mergeability fix-required matches compatibility"
              state
              slice.prReviewMergeabilityGoldenPrefix
              slice.prReviewMergeabilityGoldenIndexedPrefix
              (ObservedMergeabilityFixRequired fixEvidence)
              fixObservation
              "PrReview/FixingReviews"
              (PrReviewMergeabilityFixRequired fixEvidence)
              fixEvent
              ( \planned ->
                  effectTagPlan [PublishReviewFindingsTag, SleepUntilNextPollTag] planned
                    && planned.plannedPreCommitEffects == [SomeEffect (PublishReviewFindings prConfig fixEvidence)]
                    && planned.plannedPostCommitEffects == [SomeEffect SleepUntilNextPoll]
              )
          ]
      pure (and results)

workflowPrReviewMergeabilityIndexedSpecMatchesCompatibilityForCleanFromGoldenLifecycle :: IO Bool
workflowPrReviewMergeabilityIndexedSpecMatchesCompatibilityForCleanFromGoldenLifecycle = do
  loaded <- loadPrReviewMergeabilityGoldenSlice
  case loaded of
    Left failure -> assert "indexed workflow PR-review mergeability golden lifecycle loads" False <* putStrLn ("FAIL golden lifecycle: " <> failure)
    Right slice -> do
      let state = prReviewMergeabilityGoldenState slice
          commit = prReviewMergeabilityGoldenCommit slice
          expectedEvent = PrReviewMergeabilityClean commit
          observation = DaemonPrReviewObservation (ObservedMergeabilityClean commit)
          indexedState =
            PrReviewIndexedState state
              :: PrReviewIndexedState PrReviewIndexedWaitingForMergeability
          indexedObservation = indexedPrReviewMergeabilityCleanObservation commit
          directReplay = workflowReplayEvents @MoifoldSpec (prReviewMergeabilityGoldenPrefix slice <> [expectedEvent])
          indexedReplay =
            IndexedWorkflow.indexedWorkflowReplayEvents @PrReviewMergeabilityIndexedSpec
              (prReviewMergeabilityGoldenIndexedPrefix slice <> [indexedPrReviewMergeabilityCleanEvent commit])
      assert "indexed workflow PR-review mergeability clean matches compatibility from golden lifecycle" $
        case
          ( workflowObserve @MoifoldSpec state observation
          , workflowPlanObservation @MoifoldSpec state observation
          , IndexedWorkflow.indexedWorkflowObserve @PrReviewMergeabilityIndexedSpec indexedState indexedObservation
          , IndexedWorkflow.indexedWorkflowPlanObservation @PrReviewMergeabilityIndexedSpec indexedState indexedObservation
          , directReplay
          , indexedReplay
          )
          of
          (Right compatibilityObserved, Right compatibilityPlan, Right indexedObserved, Right indexedPlan, Right compatibilityReplay, Right indexedReplayResult) ->
            let PrReviewIndexedState indexedNextState =
                  IndexedWorkflow.indexedWorkflowObservedState @PrReviewMergeabilityIndexedSpec indexedObserved
                indexedReplayResultValue = prReviewIndexedReplayResult indexedReplayResult
                wrappedTransition = IndexedWorkflow.SomeIndexedPlannedTransition indexedPlan
             in compatibilityObserved.observedEvent == expectedEvent
                  && prReviewIndexedTransitionEvent indexedPlan == compatibilityPlan.plannedEvent
                  && prReviewIndexedTransitionEvent indexedPlan == expectedEvent
                  && IndexedWorkflow.someIndexedWorkflowTransitionSourceLabel @PrReviewMergeabilityIndexedSpec wrappedTransition == workflowStateLabel @MoifoldSpec state
                  && IndexedWorkflow.someIndexedWorkflowTransitionTargetLabel @PrReviewMergeabilityIndexedSpec wrappedTransition == "PrReview/Merging"
                  && workflowStateLabel @MoifoldSpec compatibilityObserved.observedState == workflowStateLabel @MoifoldSpec indexedNextState
                  && workflowStateLabel @MoifoldSpec indexedNextState == "PrReview/Merging"
                  && sameWatcherStateShape compatibilityObserved.observedState indexedNextState
                  && prReviewIndexedTransitionPreCommitEffects indexedPlan == compatibilityPlan.plannedPreCommitEffects
                  && prReviewIndexedTransitionPostCommitEffects indexedPlan == compatibilityPlan.plannedPostCommitEffects
                  && compatibilityPlan.plannedPreCommitEffects == compatibilityObserved.observedEffects
                  && compatibilityPlan.plannedPostCommitEffects == []
                  && sameWatcherStateShape compatibilityReplay.replayState indexedReplayResultValue.replayState
                  && workflowStateLabel @MoifoldSpec compatibilityReplay.replayState == workflowStateLabel @MoifoldSpec indexedReplayResultValue.replayState
                  && compatibilityReplay.replayEffects == indexedReplayResultValue.replayEffects
          _ -> False

workflowPrReviewMergeabilityIndexedSpecMatchesCompatibilityForBlockedAndMergeComplete :: IO Bool
workflowPrReviewMergeabilityIndexedSpecMatchesCompatibilityForBlockedAndMergeComplete = do
  loaded <- loadPrReviewMergeabilityGoldenSlice
  case loaded of
    Left failure -> assert "indexed workflow PR-review mergeability golden lifecycle loads for blocked and complete" False <* putStrLn ("FAIL golden lifecycle: " <> failure)
    Right slice -> do
      let waitingState = prReviewMergeabilityGoldenState slice
          commit = prReviewMergeabilityGoldenCommit slice
          mergeCommit = prReviewMergeabilityGoldenMergeCommit slice
          waitingBlockedReason = BlockedReason "mergeability gate blocked"
          mergingBlockedReason = BlockedReason "merge terminal blocked"
          waitingBlockedObservation =
            PrReviewIndexedObservation
              "PrReview/WaitingMergeability"
              "PrReview/Blocked"
              (DaemonPrReviewObservation (ObservedPrReviewBlocked waitingBlockedReason))
              :: PrReviewIndexedObservation PrReviewIndexedWaitingForMergeability PrReviewIndexedBlocked
          waitingBlockedEvent =
            PrReviewIndexedEvent "PrReview/WaitingMergeability" "PrReview/Blocked" (WatcherBlocked waitingBlockedReason)
              :: PrReviewIndexedEvent PrReviewIndexedWaitingForMergeability PrReviewIndexedBlocked
          mergingStateResult = workflowApplyEvent @MoifoldSpec waitingState (PrReviewMergeabilityClean commit)
      case mergingStateResult of
        Left failure -> assert "indexed workflow PR-review mergeability clean reaches merging state for terminal coverage" False <* putStrLn ("FAIL merging state: " <> Text.unpack failure)
        Right (mergingState, _mergeEffects) -> do
          let mergePrefix = slice.prReviewMergeabilityGoldenPrefix <> [PrReviewMergeabilityClean commit]
              indexedMergePrefix =
                slice.prReviewMergeabilityGoldenIndexedPrefix <> [indexedPrReviewMergeabilityCleanEvent commit]
              mergingBlockedObservation =
                PrReviewIndexedObservation
                  "PrReview/Merging"
                  "PrReview/Blocked"
                  (DaemonPrReviewObservation (ObservedPrReviewBlocked mergingBlockedReason))
                  :: PrReviewIndexedObservation PrReviewIndexedMerging PrReviewIndexedBlocked
              mergingBlockedEvent =
                PrReviewIndexedEvent "PrReview/Merging" "PrReview/Blocked" (WatcherBlocked mergingBlockedReason)
                  :: PrReviewIndexedEvent PrReviewIndexedMerging PrReviewIndexedBlocked
              completedObservation =
                PrReviewIndexedObservation
                  "PrReview/Merging"
                  "PrReview/Complete"
                  (DaemonPrReviewObservation (ObservedMergeCompleted mergeCommit))
                  :: PrReviewIndexedObservation PrReviewIndexedMerging PrReviewIndexedComplete
              completedEvent =
                PrReviewIndexedEvent "PrReview/Merging" "PrReview/Complete" (PrReviewMergeCompleted mergeCommit)
                  :: PrReviewIndexedEvent PrReviewIndexedMerging PrReviewIndexedComplete
              completeWriteShape stateValue =
                compatibilityStateWrites "/tmp/state" stateValue
                  == [ CompatibilityWrite
                         "/tmp/state/watcher-state.json"
                         (object ["lastTurnStatus" .= ("merged" :: Text), "mergeCommitSha" .= unCommitSha (unMergeCommit mergeCommit)])
                     ]
              completePlanCheck planned =
                planned.plannedPreCommitEffects == []
                  && planned.plannedPostCommitEffects == [SomeEffect StopDaemon]
          results <-
            sequence
              [ prReviewMergeabilityIndexedSpecMatchesCompatibility
                  "indexed workflow PR-review mergeability blocked matches compatibility"
                  waitingState
                  slice.prReviewMergeabilityGoldenPrefix
                  slice.prReviewMergeabilityGoldenIndexedPrefix
                  (ObservedPrReviewBlocked waitingBlockedReason)
                  waitingBlockedObservation
                  "PrReview/Blocked"
                  (WatcherBlocked waitingBlockedReason)
                  waitingBlockedEvent
                  blockedPostCommitPlan
              , prReviewMergeabilityIndexedSpecMatchesCompatibility
                  "indexed workflow PR-review merging blocked matches compatibility"
                  mergingState
                  mergePrefix
                  indexedMergePrefix
                  (ObservedPrReviewBlocked mergingBlockedReason)
                  mergingBlockedObservation
                  "PrReview/Blocked"
                  (WatcherBlocked mergingBlockedReason)
                  mergingBlockedEvent
                  blockedPostCommitPlan
              , prReviewMergeabilityIndexedSpecMatchesCompatibility
                  "indexed workflow PR-review merge completed matches compatibility"
                  mergingState
                  mergePrefix
                  indexedMergePrefix
                  (ObservedMergeCompleted mergeCommit)
                  completedObservation
                  "PrReview/Complete"
                  (PrReviewMergeCompleted mergeCommit)
                  completedEvent
                  completePlanCheck
              , assert "indexed workflow PR-review merge completed preserves merged compatibility write shape" $
                  case
                    ( workflowObserve @MoifoldSpec mergingState (DaemonPrReviewObservation (ObservedMergeCompleted mergeCommit))
                    , IndexedWorkflow.indexedWorkflowObserve
                        @PrReviewMergeabilityIndexedSpec
                        (PrReviewIndexedState mergingState :: PrReviewIndexedState PrReviewIndexedMerging)
                        completedObservation
                    )
                    of
                    (Right compatibilityObserved, Right indexedObserved) ->
                      let PrReviewIndexedState indexedState =
                            IndexedWorkflow.indexedWorkflowObservedState @PrReviewMergeabilityIndexedSpec indexedObserved
                       in completeWriteShape compatibilityObserved.observedState
                            && completeWriteShape indexedState
                            && case indexedState of
                              SomeWatcherState (CompleteState (PrMerged actualMergeCommit)) -> actualMergeCommit == mergeCommit
                              _ -> False
                    _ -> False
              ]
          pure (and results)

workflowPrReviewMergeabilityIndexedSpecPreservesMergeEffectOrdering :: IO Bool
workflowPrReviewMergeabilityIndexedSpecPreservesMergeEffectOrdering = do
  loaded <- loadPrReviewMergeabilityGoldenSlice
  case loaded of
    Left failure -> assert "indexed workflow PR-review mergeability golden lifecycle loads for effect ordering" False <* putStrLn ("FAIL golden lifecycle: " <> failure)
    Right slice -> do
      let state = prReviewMergeabilityGoldenState slice
          prConfig = prReviewMergeabilityGoldenConfig slice
          cleanEvidence = prReviewMergeabilityGoldenEvidence slice
          commit = prReviewMergeabilityGoldenCommit slice
          expectedEffects = [SomeEffect (MergePullRequest prConfig.prNumber cleanEvidence)]
          runtimeConfig = effectRuntimeConfig prConfig.prRepo "/tmp/work" 742
          indexedState =
            PrReviewIndexedState state
              :: PrReviewIndexedState PrReviewIndexedWaitingForMergeability
          indexedObservation = indexedPrReviewMergeabilityCleanObservation commit
      assert "indexed workflow PR-review mergeability clean keeps merge effect pre-commit" $
        case IndexedWorkflow.indexedWorkflowPlanObservation @PrReviewMergeabilityIndexedSpec indexedState indexedObservation of
          Right indexedPlan ->
            let preCommitEffects = prReviewIndexedTransitionPreCommitEffects indexedPlan
                postCommitEffects = prReviewIndexedTransitionPostCommitEffects indexedPlan
                workflow = WorkflowExecution.compileWorkflowEffectPlanWithMetadata runtimeConfig (preCommitEffects <> postCommitEffects)
                legacy = compileEffectPlan runtimeConfig expectedEffects
                dryRunReports = WorkflowExecution.dryRunWorkflowCompiledEffectPlan workflow
                (preCommitActions, postCommitActions) = WorkflowExecution.partitionWorkflowActions workflow
                expectedAction = PlannedCommand (GhPrCleanReviewAndMerge prConfig.prRepo prConfig.prNumber cleanEvidence runtimeConfig.effectRuntimeMergeMethod)
                expectedDryRunReports =
                  [ ActionExecutionReport
                      { actionExecutionMode = DryRunActions
                      , actionExecutionAction = expectedAction
                      , actionExecutionResult = DryRunActionResult
                      , actionExecutionOutcome = ActionSucceeded
                      }
                  ]
             in preCommitEffects == expectedEffects
                  && postCommitEffects == []
                  && fmap WorkflowExecution.workflowPlannedAction preCommitActions == legacy.compiledActions
                  && legacy.compiledActions == [expectedAction]
                  && postCommitActions == []
                  && dryRunReports == expectedDryRunReports
          Left _ -> False

workflowPrReviewMergeabilityIndexedSpecRejectsMismatchedCleanCommitLikeFacade :: IO Bool
workflowPrReviewMergeabilityIndexedSpecRejectsMismatchedCleanCommitLikeFacade = do
  loaded <- loadPrReviewMergeabilityGoldenSlice
  case loaded of
    Left failure -> assert "indexed workflow PR-review mergeability golden lifecycle loads for mismatch" False <* putStrLn ("FAIL golden lifecycle: " <> failure)
    Right slice -> do
      let state = prReviewMergeabilityGoldenState slice
          mismatchedCommit = CommitSha "not-the-reviewed-commit"
          observation = DaemonPrReviewObservation (ObservedMergeabilityClean mismatchedCommit)
          facadeObservation = WorkflowPrReviewMergeability.MergeabilityObservedClean mismatchedCommit
          indexedState =
            PrReviewIndexedState state
              :: PrReviewIndexedState PrReviewIndexedWaitingForMergeability
          indexedObservation = indexedPrReviewMergeabilityCleanObservation mismatchedCommit
          expectedFailure = "mergeability clean commit does not match reviewed commit"
      assert "indexed workflow PR-review mergeability clean rejects mismatched commit like facade" $
        case
          ( WorkflowPrReviewMergeability.observePrReviewMergeability state facadeObservation
          , workflowObserve @MoifoldSpec state observation
          , workflowPlanObservation @MoifoldSpec state observation
          , IndexedWorkflow.indexedWorkflowObserve @PrReviewMergeabilityIndexedSpec indexedState indexedObservation
          , IndexedWorkflow.indexedWorkflowPlanObservation @PrReviewMergeabilityIndexedSpec indexedState indexedObservation
          )
          of
          (Left facadeFailure, Left compatibilityFailure, Left compatibilityPlanFailure, Left indexedFailure, Left indexedPlanFailure) ->
            facadeFailure == expectedFailure
              && compatibilityFailure == facadeFailure
              && compatibilityPlanFailure == facadeFailure
              && indexedFailure == facadeFailure
              && indexedPlanFailure == facadeFailure
          _ -> False

workflowPrReviewMergeabilityIndexedSpecRejectsInvalidTerminalObservationsLikeCompatibility :: IO Bool
workflowPrReviewMergeabilityIndexedSpecRejectsInvalidTerminalObservationsLikeCompatibility = do
  loaded <- loadPrReviewMergeabilityGoldenSlice
  case loaded of
    Left failure -> assert "indexed workflow PR-review mergeability golden lifecycle loads for invalid terminal observations" False <* putStrLn ("FAIL golden lifecycle: " <> failure)
    Right slice -> do
      let waitingState = prReviewMergeabilityGoldenState slice
          commit = prReviewMergeabilityGoldenCommit slice
          mergeCommit = prReviewMergeabilityGoldenMergeCommit slice
          waitingIndexedState =
            PrReviewIndexedState waitingState
              :: PrReviewIndexedState PrReviewIndexedWaitingForMergeability
          invalidCompletedObservation =
            PrReviewIndexedObservation
              "PrReview/WaitingMergeability"
              "PrReview/Complete"
              (DaemonPrReviewObservation (ObservedMergeCompleted mergeCommit))
              :: PrReviewIndexedObservation PrReviewIndexedWaitingForMergeability PrReviewIndexedComplete
          checkingState =
            SomeWatcherState
              ( PrCheckingReviews
                  slice.prReviewMergeabilityGoldenConfig
                  (WorkerIdle (ThreadId "worker"))
                  (ReviewerIdle (ThreadId "reviewer"))
              )
          invalidWaitingObservation =
            PrReviewIndexedObservation
              "PrReview/CheckingReviews"
              "PrReview/WaitingMergeability"
              (DaemonPrReviewObservation (ObservedMergeabilityRetry "not waiting"))
              :: PrReviewIndexedObservation PrReviewIndexedCheckingReviews PrReviewIndexedWaitingForMergeability
          mergingStateResult = workflowApplyEvent @MoifoldSpec waitingState (PrReviewMergeabilityClean commit)
      case mergingStateResult of
        Left failure -> assert "indexed workflow PR-review mergeability clean reaches merging state for invalid coverage" False <* putStrLn ("FAIL merging state: " <> Text.unpack failure)
        Right (mergingState, _mergeEffects) -> do
          let invalidCleanObservation =
                PrReviewIndexedObservation
                  "PrReview/Merging"
                  "PrReview/Merging"
                  (DaemonPrReviewObservation (ObservedMergeabilityClean commit))
                  :: PrReviewIndexedObservation PrReviewIndexedMerging PrReviewIndexedMerging
          results <-
            sequence
              [ assert "indexed workflow PR-review merge completion outside merging fails like compatibility" $
                  invalidPrReviewIndexedObservationMatchesCompatibility
                    waitingState
                    waitingIndexedState
                    (ObservedMergeCompleted mergeCommit)
                    invalidCompletedObservation
              , assert "indexed workflow PR-review waiting observation outside waiting fails like compatibility" $
                  invalidPrReviewIndexedObservationMatchesCompatibility
                    checkingState
                    (PrReviewIndexedState checkingState :: PrReviewIndexedState PrReviewIndexedCheckingReviews)
                    (ObservedMergeabilityRetry "not waiting")
                    invalidWaitingObservation
              , assert "indexed workflow PR-review mergeability clean outside waiting fails like compatibility" $
                  invalidPrReviewIndexedObservationMatchesCompatibility
                    mergingState
                    (PrReviewIndexedState mergingState :: PrReviewIndexedState PrReviewIndexedMerging)
                    (ObservedMergeabilityClean commit)
                    invalidCleanObservation
              ]
          pure (and results)

invalidPrReviewIndexedObservationMatchesCompatibility
  :: forall (source :: Type) (target :: Type).
     SomeWatcherState
  -> PrReviewIndexedState source
  -> PrReviewObservation
  -> PrReviewIndexedObservation source target
  -> Bool
invalidPrReviewIndexedObservationMatchesCompatibility state indexedState observation indexedObservation =
  case
    ( prReviewObserve state observation
    , workflowObserve @MoifoldSpec state daemonObservation
    , workflowPlanObservation @MoifoldSpec state daemonObservation
    , IndexedWorkflow.indexedWorkflowObserve @PrReviewMergeabilityIndexedSpec indexedState indexedObservation
    , IndexedWorkflow.indexedWorkflowPlanObservation @PrReviewMergeabilityIndexedSpec indexedState indexedObservation
    )
    of
    (Left facadeFailure, Left compatibilityFailure, Left compatibilityPlanFailure, Left indexedFailure, Left indexedPlanFailure) ->
      compatibilityFailure == facadeFailure
        && compatibilityPlanFailure == facadeFailure
        && indexedFailure == facadeFailure
        && indexedPlanFailure == facadeFailure
    _ -> False
 where
  daemonObservation = DaemonPrReviewObservation observation

workflowPrReviewMergeabilityIndexedDaemonDryRunMatchesCompatibility :: IO Bool
workflowPrReviewMergeabilityIndexedDaemonDryRunMatchesCompatibility = do
  loaded <- loadPrReviewMergeabilityGoldenSlice
  case loaded of
    Left failure -> assert "indexed daemon PR-review mergeability golden lifecycle loads for dry-run parity" False <* putStrLn ("FAIL golden lifecycle: " <> failure)
    Right slice -> do
      (executor, getCalls) <- fakeActionExecutor
      let state = slice.prReviewMergeabilityGoldenState
          commit = slice.prReviewMergeabilityGoldenCommit
          prConfig = slice.prReviewMergeabilityGoldenConfig
          cleanEvidence = slice.prReviewMergeabilityGoldenEvidence
          observation = DaemonPrReviewObservation (ObservedMergeabilityClean commit)
          runtimeConfig = effectRuntimeConfig prConfig.prRepo "/tmp/work" 880
          options =
            DaemonOptions
              { daemonEventLogPath = "/tmp/events.jsonl"
              , daemonRuntimeConfig = runtimeConfig
              , daemonExecutionMode = DryRunActions
              }
          expectedEffects = [SomeEffect (MergePullRequest prConfig.prNumber cleanEvidence)]
          expectedCompiled = compileEffectPlan runtimeConfig expectedEffects
          expectedAction = PlannedCommand (GhPrCleanReviewAndMerge prConfig.prRepo prConfig.prNumber cleanEvidence runtimeConfig.effectRuntimeMergeMethod)
          expectedReports =
            [ ActionExecutionReport
                { actionExecutionMode = DryRunActions
                , actionExecutionAction = expectedAction
                , actionExecutionResult = DryRunActionResult
                , actionExecutionOutcome = ActionSucceeded
                }
            ]
      result <- runObservedDaemonTickWithEvents executor options slice.prReviewMergeabilityGoldenPrefix observation
      calls <- getCalls
      case
        ( result
        , workflowPlanObservation @MoifoldSpec state observation
        , projectPrReviewMergeabilityCleanObservation state commit
        )
        of
        (Right tick, Right compatibilityPlan, Right indexedProjection) -> do
          let audit = tick.daemonObservedAudit
              projectedPlan = indexedProjection.prReviewMergeabilityIndexedProjectionPlanned
              projectedEffects = indexedProjection.prReviewMergeabilityIndexedProjectionEffectPlan
          results <-
            sequence
              [ assert "indexed daemon dry-run exposes compatibility event" $
                  tick.daemonObservedEvent == PrReviewMergeabilityClean commit
                    && tick.daemonObservedEvent == compatibilityPlan.plannedEvent
                    && tick.daemonObservedEvent == projectedPlan.plannedEvent
              , assert "indexed daemon dry-run exposes compatibility state and replay" $
                  sameWatcherStateShape tick.daemonObservedState indexedProjection.prReviewMergeabilityIndexedProjectionFinalState
                    && workflowStateLabel @MoifoldSpec tick.daemonObservedState == "PrReview/Merging"
                    && sameWatcherStateShape tick.daemonObservedReplayResult.replayState state
              , assert "indexed daemon dry-run keeps labels and effect plan compatible" $
                  indexedProjection.prReviewMergeabilityIndexedProjectionSourceLabel == workflowStateLabel @MoifoldSpec state
                    && indexedProjection.prReviewMergeabilityIndexedProjectionTargetLabel == "PrReview/Merging"
                    && projectedPlan.plannedPreCommitEffects == compatibilityPlan.plannedPreCommitEffects
                    && projectedPlan.plannedPostCommitEffects == compatibilityPlan.plannedPostCommitEffects
                    && projectedEffects == expectedEffects
                    && workflowValidateEffects @MoifoldSpec state projectedEffects == Right ()
                    && all (isRightUnit . workflowEffectAllowed @MoifoldSpec state) projectedEffects
              , assert "indexed daemon dry-run keeps merge as the only pre-commit command" $
                  tick.daemonObservedCompiledEffects == expectedCompiled
                    && tick.daemonObservedCompiledEffects.compiledNextRequestId == runtimeConfig.effectRuntimeNextRequestId
                    && tick.daemonObservedActionReports == expectedReports
              , assert "indexed daemon dry-run keeps dry-run surfaces stable" $
                  tick.daemonObservedCommittedEvents == []
                    && tick.daemonObservedCompatibilityWrites
                      == compatibilityStateWrites (runtimeStateDirPath runtimeConfig.effectRuntimeStateDir) tick.daemonObservedState
                    && WorkflowAudit.workflowAuditCommittedEventLabel audit == Nothing
                    && WorkflowAudit.workflowAuditPriorStateLabel audit == workflowStateLabel @MoifoldSpec state
                    && WorkflowAudit.workflowAuditFinalStateLabel audit == Just "PrReview/Merging"
                    && WorkflowAudit.workflowAuditPreCommitReports audit == expectedReports
                    && WorkflowAudit.workflowAuditPostCommitReports audit == []
              , assert "indexed daemon dry-run performs no runtime calls" (null calls)
              ]
          pure (and results)
        (Left failure, _, _) -> do
          putStrLn ("FAIL indexed daemon dry-run mergeability clean: " <> Text.unpack (formatDaemonFailure failure))
          pure False
        _ ->
          assert "indexed daemon dry-run mergeability clean prepares compatibility and indexed plans" False

workflowPrReviewMergeabilityIndexedDaemonExecuteMatchesCompatibility :: IO Bool
workflowPrReviewMergeabilityIndexedDaemonExecuteMatchesCompatibility = do
  loaded <- loadPrReviewMergeabilityGoldenSlice
  case loaded of
    Left failure -> assert "indexed daemon PR-review mergeability golden lifecycle loads for execute parity" False <* putStrLn ("FAIL golden lifecycle: " <> failure)
    Right slice -> do
      (executor, getCalls) <- fakeActionExecutor
      let state = slice.prReviewMergeabilityGoldenState
          commit = slice.prReviewMergeabilityGoldenCommit
          prConfig = slice.prReviewMergeabilityGoldenConfig
          cleanEvidence = slice.prReviewMergeabilityGoldenEvidence
          observation = DaemonPrReviewObservation (ObservedMergeabilityClean commit)
          runtimeConfig = effectRuntimeConfig prConfig.prRepo "/tmp/work" 881
          options =
            DaemonOptions
              { daemonEventLogPath = "/tmp/events.jsonl"
              , daemonRuntimeConfig = runtimeConfig
              , daemonExecutionMode = ExecuteActions
              }
          expectedEvent = PrReviewMergeabilityClean commit
          expectedCommand = GhPrCleanReviewAndMerge prConfig.prRepo prConfig.prNumber cleanEvidence runtimeConfig.effectRuntimeMergeMethod
          expectedCompiled = compileEffectPlan runtimeConfig [SomeEffect (MergePullRequest prConfig.prNumber cleanEvidence)]
      result <- runObservedDaemonTickWithEvents executor options slice.prReviewMergeabilityGoldenPrefix observation
      calls <- getCalls
      case
        ( result
        , workflowPlanObservation @MoifoldSpec state observation
        , projectPrReviewMergeabilityCleanObservation state commit
        )
        of
        (Right tick, Right compatibilityPlan, Right indexedProjection) -> do
          let expectedWrites =
                compatibilityStateWrites (runtimeStateDirPath runtimeConfig.effectRuntimeStateDir) tick.daemonObservedState
          results <-
            sequence
              [ assert "indexed daemon execute emits and commits compatibility mergeability event" $
                  tick.daemonObservedEvent == expectedEvent
                    && tick.daemonObservedEvent == compatibilityPlan.plannedEvent
                    && tick.daemonObservedCommittedEvents == [expectedEvent]
              , assert "indexed daemon execute reaches the same merging state" $
                  sameWatcherStateShape tick.daemonObservedState indexedProjection.prReviewMergeabilityIndexedProjectionFinalState
                    && workflowStateLabel @MoifoldSpec tick.daemonObservedState == "PrReview/Merging"
              , assert "indexed daemon execute keeps merge action pre-commit before append" $
                  tick.daemonObservedCompiledEffects == expectedCompiled
                    && tick.daemonObservedCompiledEffects.compiledNextRequestId == runtimeConfig.effectRuntimeNextRequestId
                    && callBefore (FakeCommand expectedCommand) (FakeAppendJsonLine "/tmp/events.jsonl" (toJSON expectedEvent)) calls
              , assert "indexed daemon execute writes compatibility after event append" $
                  tick.daemonObservedCompatibilityWrites == expectedWrites
                    && length [() | FakeWriteJson {} <- calls] == length expectedWrites
                    && all (\write -> FakeWriteJson (compatibilityWritePath write) (compatibilityWriteValue write) `elem` calls) expectedWrites
              , assert "indexed daemon execute keeps audit and post-commit surfaces stable" $
                  WorkflowAudit.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just "pr_review_mergeability_clean"
                    && WorkflowAudit.workflowAuditPreCommitReports tick.daemonObservedAudit == tick.daemonObservedActionReports
                    && WorkflowAudit.workflowAuditPostCommitReports tick.daemonObservedAudit == []
                    && not (any isFakeAppServer calls)
              ]
          pure (and results)
        (Left failure, _, _) -> do
          putStrLn ("FAIL indexed daemon execute mergeability clean: " <> Text.unpack (formatDaemonFailure failure))
          pure False
        _ ->
          assert "indexed daemon execute mergeability clean prepares compatibility and indexed plans" False
 where
  isFakeAppServer = \case
    FakeAppServer {} -> True
    _ -> False

workflowPrReviewMergeabilityIndexedDaemonFailureMatchesCompatibility :: IO Bool
workflowPrReviewMergeabilityIndexedDaemonFailureMatchesCompatibility = do
  loaded <- loadPrReviewMergeabilityGoldenSlice
  case loaded of
    Left failure -> assert "indexed daemon PR-review mergeability golden lifecycle loads for failure parity" False <* putStrLn ("FAIL golden lifecycle: " <> failure)
    Right slice -> do
      let state = slice.prReviewMergeabilityGoldenState
          commit = slice.prReviewMergeabilityGoldenCommit
          prConfig = slice.prReviewMergeabilityGoldenConfig
          cleanEvidence = slice.prReviewMergeabilityGoldenEvidence
          observation = DaemonPrReviewObservation (ObservedMergeabilityClean commit)
          runtimeConfig = effectRuntimeConfig prConfig.prRepo "/tmp/work" 882
          options =
            DaemonOptions
              { daemonEventLogPath = "/tmp/events.jsonl"
              , daemonRuntimeConfig = runtimeConfig
              , daemonExecutionMode = ExecuteActions
              }
          expectedEvent = PrReviewMergeabilityClean commit
          expectedEffects = [SomeEffect (MergePullRequest prConfig.prNumber cleanEvidence)]
          expectedCompiled = WorkflowExecution.compileWorkflowEffectPlanWithMetadata runtimeConfig expectedEffects
      (executor, getCalls) <-
        fakeActionExecutorWith
          ( \case
              GhPrCleanReviewAndMerge {} -> failedCommandReport "merge failed"
              command -> defaultFakeCommand command
          )
          defaultFakeAppServer
      result <- runObservedDaemonTickWithEvents executor options slice.prReviewMergeabilityGoldenPrefix observation
      calls <- getCalls
      case result of
        Left (DaemonObservedTransactionFailed failure) -> do
          let audit = failure.daemonObservedTransactionFailureAudit
              formatted = formatDaemonFailure (DaemonObservedTransactionFailed failure)
          results <-
            sequence
              [ assert "indexed daemon merge failure keeps detailed pre-commit stage" $
                  failure.daemonObservedTransactionFailureStage == WorkflowTransaction.WorkflowTransactionPreCommitActionFailure
                    && failure.daemonObservedTransactionFailurePlannedEvent == Just expectedEvent
                    && failure.daemonObservedTransactionFailureCommittedEvents == []
                    && failure.daemonObservedTransactionFailureCompiledEffects == Just expectedCompiled
                    && failure.daemonObservedTransactionFailurePreCommitReports == []
                    && failure.daemonObservedTransactionFailurePostCommitReports == []
              , assert "indexed daemon merge failure reports existing daemon action failure" $
                  case failure.daemonObservedTransactionFailureReason of
                    DaemonActionFailed (PlannedCommand GhPrCleanReviewAndMerge {}) _report -> True
                    _ -> False
              , assert "indexed daemon merge failure keeps failure audit shape" $
                  (WorkflowAudit.workflowAuditPriorStateLabel <$> audit) == Just (workflowStateLabel @MoifoldSpec state)
                    && (WorkflowAudit.workflowAuditCommittedEventLabel <$> audit) == Just Nothing
                    && (WorkflowAudit.workflowAuditFinalStateLabel <$> audit) == Just Nothing
                    && (WorkflowAudit.workflowAuditNextDaemonRecommendation <$> audit) == Just WorkflowAudit.WorkflowDaemonStop
              , assert "indexed daemon merge failure does not append or write compatibility" $
                  not (any isAppend calls)
                    && not (any isWrite calls)
              , assert "indexed daemon merge failure preserves formatted failure shape" $
                  "observed transaction failed during WorkflowTransactionPreCommitActionFailure" `Text.isInfixOf` formatted
                    && "committed events: 0" `Text.isInfixOf` formatted
              ]
          pure (and results)
        other -> do
          putStrLn ("FAIL indexed daemon merge failure result: " <> show other)
          pure False
 where
  isAppend = \case
    FakeAppendJsonLine {} -> True
    _ -> False
  isWrite = \case
    FakeWriteJson {} -> True
    _ -> False

workflowPrReviewMergeabilityIndexedDaemonRejectsInvalidObservations :: IO Bool
workflowPrReviewMergeabilityIndexedDaemonRejectsInvalidObservations = do
  loaded <- loadPrReviewMergeabilityGoldenSlice
  case loaded of
    Left failure -> assert "indexed daemon PR-review mergeability golden lifecycle loads for invalid parity" False <* putStrLn ("FAIL golden lifecycle: " <> failure)
    Right slice -> do
      (mismatchExecutor, getMismatchCalls) <- fakeActionExecutor
      (wrongStateExecutor, getWrongStateCalls) <- fakeActionExecutor
      let state = slice.prReviewMergeabilityGoldenState
          commit = slice.prReviewMergeabilityGoldenCommit
          mismatchedCommit = CommitSha "not-the-reviewed-commit"
          prConfig = slice.prReviewMergeabilityGoldenConfig
          runtimeConfig = effectRuntimeConfig prConfig.prRepo "/tmp/work" 883
          options =
            DaemonOptions
              { daemonEventLogPath = "/tmp/events.jsonl"
              , daemonRuntimeConfig = runtimeConfig
              , daemonExecutionMode = DryRunActions
              }
          mismatchedObservation = DaemonPrReviewObservation (ObservedMergeabilityClean mismatchedCommit)
          wrongStateEvents = slice.prReviewMergeabilityGoldenPrefix <> [PrReviewMergeabilityClean commit]
          wrongStateObservation = DaemonPrReviewObservation (ObservedMergeabilityClean commit)
          expectedMismatchFailure = "mergeability clean commit does not match reviewed commit"
      mismatchResult <- runObservedDaemonTickWithEvents mismatchExecutor options slice.prReviewMergeabilityGoldenPrefix mismatchedObservation
      wrongStateResult <- runObservedDaemonTickWithEvents wrongStateExecutor options wrongStateEvents wrongStateObservation
      mismatchCalls <- getMismatchCalls
      wrongStateCalls <- getWrongStateCalls
      let directWrongState =
            case workflowReplayEvents @MoifoldSpec wrongStateEvents of
              Right replay -> workflowPlanObservation @MoifoldSpec replay.replayState wrongStateObservation
              Left failure -> Left failure
      results <-
        sequence
          [ assert "indexed daemon clean rejects mismatched commit like compatibility" $
              case mismatchResult of
                Left (DaemonObservationRejected daemonFailure) ->
                  daemonFailure == expectedMismatchFailure
                    && case workflowPlanObservation @MoifoldSpec state mismatchedObservation of
                      Left compatibilityFailure -> compatibilityFailure == expectedMismatchFailure
                      Right _ -> False
                    && case projectPrReviewMergeabilityCleanObservation state mismatchedCommit of
                      Left indexedFailure -> indexedFailure == expectedMismatchFailure
                      Right _ -> False
                    && null mismatchCalls
                _ -> False
          , assert "indexed daemon clean rejects wrong state like compatibility" $
              case (wrongStateResult, directWrongState) of
                (Left (DaemonObservationRejected daemonFailure), Left compatibilityFailure) ->
                  daemonFailure == compatibilityFailure
                    && not (Text.null daemonFailure)
                    && null wrongStateCalls
                _ -> False
          ]
      pure (and results)

prReviewMergeabilityIndexedSpecMatchesCompatibility
  :: forall (source :: Type) (target :: Type).
     String
  -> SomeWatcherState
  -> [WatcherEvent]
  -> [IndexedWorkflow.SomeIndexedWorkflowEvent PrReviewMergeabilityIndexedSpec]
  -> PrReviewObservation
  -> PrReviewIndexedObservation source target
  -> Text
  -> WatcherEvent
  -> PrReviewIndexedEvent source target
  -> (PlannedTransition MoifoldSpec -> Bool)
  -> IO Bool
prReviewMergeabilityIndexedSpecMatchesCompatibility title state replayPrefix indexedReplayPrefix facadeObservation indexedObservation expectedTargetLabel expectedEvent indexedEvent planCheck =
  assert title $
    case
      ( prReviewObserve state facadeObservation
      , workflowObserve @MoifoldSpec state observation
      , workflowPlanObservation @MoifoldSpec state observation
      , IndexedWorkflow.indexedWorkflowObserve @PrReviewMergeabilityIndexedSpec indexedState indexedObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @PrReviewMergeabilityIndexedSpec indexedState indexedObservation
      , workflowApplyEvent @MoifoldSpec state expectedEvent
      , IndexedWorkflow.indexedWorkflowApplyEvent @PrReviewMergeabilityIndexedSpec indexedState indexedEvent
      , workflowReplayEvents @MoifoldSpec (replayPrefix <> [expectedEvent])
      , IndexedWorkflow.indexedWorkflowReplayEvents @PrReviewMergeabilityIndexedSpec
          (indexedReplayPrefix <> [IndexedWorkflow.SomeIndexedWorkflowEvent indexedEvent])
      )
      of
      ( Right facadeObserved
        , Right compatibilityObserved
        , Right compatibilityPlan
        , Right indexedObserved
        , Right indexedPlan
        , Right (appliedState, appliedEffects)
        , Right (PrReviewIndexedState indexedAppliedState, PrReviewIndexedEffectPlan indexedAppliedEffects)
        , Right compatibilityReplay
        , Right indexedReplay
        ) ->
          let PrReviewIndexedState indexedNextState =
                IndexedWorkflow.indexedWorkflowObservedState @PrReviewMergeabilityIndexedSpec indexedObserved
              indexedReplayResultValue = prReviewIndexedReplayResult indexedReplay
              wrappedTransition = IndexedWorkflow.SomeIndexedPlannedTransition indexedPlan
              fullCompatibilityPlan = compatibilityPlan.plannedPreCommitEffects <> compatibilityPlan.plannedPostCommitEffects
              indexedFullPlan =
                PrReviewIndexedEffectPlan fullCompatibilityPlan
                  :: PrReviewIndexedEffectPlan source target
              runtimeConfig = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 900
              workflowCompiled = WorkflowExecution.compileWorkflowEffectPlanWithMetadata runtimeConfig fullCompatibilityPlan
              legacyCompiled = compileEffectPlan runtimeConfig fullCompatibilityPlan
           in facadeObserved.prReviewTickEvent == compatibilityObserved.observedEvent
                && facadeObserved.prReviewTickEffects == compatibilityObserved.observedEffects
                && sameWatcherStateShape facadeObserved.prReviewTickState compatibilityObserved.observedState
                && compatibilityObserved.observedEvent == expectedEvent
                && prReviewIndexedTransitionEvent indexedPlan == compatibilityPlan.plannedEvent
                && prReviewIndexedTransitionEvent indexedPlan == expectedEvent
                && IndexedWorkflow.someIndexedWorkflowTransitionSourceLabel @PrReviewMergeabilityIndexedSpec wrappedTransition == workflowStateLabel @MoifoldSpec state
                && IndexedWorkflow.someIndexedWorkflowTransitionTargetLabel @PrReviewMergeabilityIndexedSpec wrappedTransition == expectedTargetLabel
                && workflowStateLabel @MoifoldSpec indexedNextState == workflowStateLabel @MoifoldSpec compatibilityObserved.observedState
                && sameWatcherStateShape compatibilityObserved.observedState indexedNextState
                && sameWatcherStateShape compatibilityObserved.observedState appliedState
                && sameWatcherStateShape appliedState indexedAppliedState
                && prReviewIndexedTransitionPreCommitEffects indexedPlan == compatibilityPlan.plannedPreCommitEffects
                && prReviewIndexedTransitionPostCommitEffects indexedPlan == compatibilityPlan.plannedPostCommitEffects
                && fullCompatibilityPlan == compatibilityObserved.observedEffects
                && appliedEffects == fullCompatibilityPlan
                && indexedAppliedEffects == fullCompatibilityPlan
                && planCheck compatibilityPlan
                && IndexedWorkflow.indexedWorkflowPlannedTransitionPreCommitEffectLabels @PrReviewMergeabilityIndexedSpec indexedPlan
                  == fmap (workflowEffectLabel @MoifoldSpec) compatibilityPlan.plannedPreCommitEffects
                && IndexedWorkflow.indexedWorkflowPlannedTransitionPostCommitEffectLabels @PrReviewMergeabilityIndexedSpec indexedPlan
                  == fmap (workflowEffectLabel @MoifoldSpec) compatibilityPlan.plannedPostCommitEffects
                && workflowValidateEffects @MoifoldSpec state fullCompatibilityPlan
                  == IndexedWorkflow.indexedWorkflowValidateEffects @PrReviewMergeabilityIndexedSpec indexedState indexedFullPlan
                && all
                  ( \effect ->
                      workflowEffectAllowed @MoifoldSpec state effect
                        == IndexedWorkflow.indexedWorkflowEffectAllowed @PrReviewMergeabilityIndexedSpec indexedState (PrReviewIndexedEffect effect)
                  )
                  fullCompatibilityPlan
                && fmap WorkflowExecution.workflowPlannedAction workflowCompiled.workflowCompiledActions == legacyCompiled.compiledActions
                && WorkflowExecution.workflowCompiledNextRequestId workflowCompiled == legacyCompiled.compiledNextRequestId
                && WorkflowExecution.workflowCompiledNextRequestId workflowCompiled == RequestId 900
                && all ((== Nothing) . appServerRequestId . WorkflowExecution.workflowPlannedAction) workflowCompiled.workflowCompiledActions
                && WorkflowExecution.dryRunWorkflowCompiledEffectPlan workflowCompiled == dryRunCompiledEffectPlan legacyCompiled
                && sameWatcherStateShape compatibilityReplay.replayState indexedReplayResultValue.replayState
                && workflowStateLabel @MoifoldSpec compatibilityReplay.replayState == workflowStateLabel @MoifoldSpec indexedReplayResultValue.replayState
                && compatibilityReplay.replayEffects == indexedReplayResultValue.replayEffects
      _ -> False
 where
  indexedState =
    PrReviewIndexedState state
      :: PrReviewIndexedState source
  observation = DaemonPrReviewObservation facadeObservation

data IssueImplementIndexedPolicyCase where
  IssueImplementIndexedPolicyCase
    :: forall (source :: Type) (target :: Type).
       String
    -> [WatcherEvent]
    -> SomeWatcherState
    -> IssueImplementObservation
    -> IssueImplementIndexed.IssueImplementIndexedState source
    -> IssueImplementIndexed.IssueImplementIndexedObservation source target
    -> IssueImplementIndexed.IssueImplementIndexedEvent source target
    -> Either Text IssueImplementIndexed.IssueImplementIndexedProjection
    -> [EffectTag]
    -> IssueImplementIndexedPolicyCase

workflowIssueImplementIndexedSpecMatchesCompatibilityForPolicyTransitions :: IO Bool
workflowIssueImplementIndexedSpecMatchesCompatibilityForPolicyTransitions = do
  results <- traverse issueImplementIndexedSpecMatchesCompatibility issueImplementIndexedPolicyCases
  pure (and results)

workflowIssueImplementIndexedSpecCoversInvalidObservationsLikeCompatibility :: IO Bool
workflowIssueImplementIndexedSpecCoversInvalidObservationsLikeCompatibility =
  sequenceAnd
    [ blockingCase
        "indexed workflow issue implement wrong pull request body update blocks observation like compatibility"
        implementationReadyPrState
        (ObservedPullRequestBodyUpdated stalePr)
        (IssueImplementIndexed.IssueImplementIndexedState implementationReadyPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementationReady)
        ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedPullRequestBodyUpdated stalePr)
            :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedBlocked
        )
        (IssueImplementIndexed.projectIssueImplementPullRequestBodyUpdatedImplementationReadyObservation implementationReadyPrState stalePr)
    , invalidCase
        "indexed workflow issue implement rejects duplicate plan start like compatibility"
        readyToPlanPrefix
        inPlanModeState
        (ObservedPlanTurnStarted planTurn2)
        (IssueImplementIndexed.IssueImplementIndexedState inPlanModeState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedInPlanMode)
        ( issueImplementIndexedObservation "IssueImplement/PlanMode" "IssueImplement/PlanMode" (ObservedPlanTurnStarted planTurn2)
            :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedInPlanMode IssueImplementIndexed.IssueImplementIndexedInPlanMode
        )
    , invalidCase
        "indexed workflow issue implement rejects completion before implementation turn like compatibility"
        implementationReadyPrPrefix
        implementationReadyPrState
        (ObservedImplementationCompleted prNumber Nothing)
        (IssueImplementIndexed.IssueImplementIndexedState implementationReadyPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementationReady)
        ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationCompleted prNumber Nothing)
            :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedHandoffReady
        )
    , invalidCase
        "indexed workflow issue implement rejects post-merge review start without reviewer like compatibility"
        postMergePendingPrefix
        postMergePendingState
        (ObservedPostMergeReviewStarted reviewedCommit finalReviewTurn)
        (IssueImplementIndexed.IssueImplementIndexedState postMergePendingState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer)
        ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPostMergeReviewStarted reviewedCommit finalReviewTurn)
            :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing
        )
    , invalidCase
        "indexed workflow issue implement rejects terminal observations like compatibility"
        completePrefix
        completeState
        (ObservedIssueClosed prNumber)
        (IssueImplementIndexed.IssueImplementIndexedState completeState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedComplete)
        ( issueImplementIndexedObservation "IssueImplement/Complete" "IssueImplement/Complete" (ObservedIssueClosed prNumber)
            :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedComplete IssueImplementIndexed.IssueImplementIndexedComplete
        )
    , invalidCase
        "indexed workflow issue implement rejects wrong-domain observations like compatibility"
        []
        wrongDomainState
        (ObservedIssueImplementBlocked blockedReason)
        (IssueImplementIndexed.IssueImplementIndexedState wrongDomainState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedReadyToPlan)
        ( issueImplementIndexedObservation "IssuePlanning/Initialized" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason)
            :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedReadyToPlan IssueImplementIndexed.IssueImplementIndexedBlocked
        )
    ]
 where
  invalidCase title _prefix state issueObservation indexedState indexedObservation =
    assert title $
      case
        ( issueImplementObserve state issueObservation
        , workflowObserve @MoifoldSpec state (DaemonIssueImplementObservation issueObservation)
        , workflowPlanObservation @MoifoldSpec state (DaemonIssueImplementObservation issueObservation)
        , IndexedWorkflow.indexedWorkflowObserve @IssueImplementIndexed.IssueImplementIndexedSpec indexedState indexedObservation
        , IndexedWorkflow.indexedWorkflowPlanObservation @IssueImplementIndexed.IssueImplementIndexedSpec indexedState indexedObservation
        )
        of
        (Left facadeFailure, Left compatibilityFailure, Left compatibilityPlanFailure, Left indexedFailure, Left indexedPlanFailure) ->
          facadeFailure == compatibilityFailure
            && facadeFailure == compatibilityPlanFailure
            && facadeFailure == indexedFailure
            && facadeFailure == indexedPlanFailure
        _ -> False
  blockingCase title state issueObservation indexedState indexedObservation projection =
    assert title $
      case
        ( issueImplementObserve state issueObservation
        , workflowObserve @MoifoldSpec state (DaemonIssueImplementObservation issueObservation)
        , workflowPlanObservation @MoifoldSpec state (DaemonIssueImplementObservation issueObservation)
        , IndexedWorkflow.indexedWorkflowObserve @IssueImplementIndexed.IssueImplementIndexedSpec indexedState indexedObservation
        , IndexedWorkflow.indexedWorkflowPlanObservation @IssueImplementIndexed.IssueImplementIndexedSpec indexedState indexedObservation
        , projection
        )
        of
        ( Right facadeObserved
          , Right compatibilityObserved
          , Right compatibilityPlan
          , Right indexedObserved
          , Right indexedPlan
          , Right projected
          ) ->
            let IssueImplementIndexed.IssueImplementIndexedState indexedNextState =
                  IndexedWorkflow.indexedWorkflowObservedState @IssueImplementIndexed.IssueImplementIndexedSpec indexedObserved
                projectedPlan = IssueImplementIndexed.issueImplementIndexedProjectionPlanned projected
                fullCompatibilityPlan = compatibilityPlan.plannedPreCommitEffects <> compatibilityPlan.plannedPostCommitEffects
             in facadeObserved.issueImplementTickEvent == compatibilityObserved.observedEvent
                  && facadeObserved.issueImplementTickEffects == compatibilityObserved.observedEffects
                  && sameWatcherStateShape facadeObserved.issueImplementTickState compatibilityObserved.observedState
                  && workflowStateLabel @MoifoldSpec compatibilityObserved.observedState == "IssueImplement/Blocked"
                  && workflowStateLabel @MoifoldSpec indexedNextState == "IssueImplement/Blocked"
                  && sameWatcherStateShape compatibilityObserved.observedState indexedNextState
                  && projectedPlan.plannedEvent == compatibilityPlan.plannedEvent
                  && projectedPlan.plannedPreCommitEffects == compatibilityPlan.plannedPreCommitEffects
                  && projectedPlan.plannedPostCommitEffects == compatibilityPlan.plannedPostCommitEffects
                  && issueImplementIndexedTransitionEvent indexedPlan == compatibilityPlan.plannedEvent
                  && issueImplementIndexedTransitionPreCommitEffects indexedPlan == compatibilityPlan.plannedPreCommitEffects
                  && issueImplementIndexedTransitionPostCommitEffects indexedPlan == compatibilityPlan.plannedPostCommitEffects
                  && IssueImplementIndexed.issueImplementIndexedProjectionSourceLabel projected == workflowStateLabel @MoifoldSpec state
                  && IssueImplementIndexed.issueImplementIndexedProjectionTargetLabel projected == "IssueImplement/Blocked"
                  && workflowStateLabel @MoifoldSpec (IssueImplementIndexed.issueImplementIndexedProjectionFinalState projected) == "IssueImplement/Blocked"
                  && IssueImplementIndexed.issueImplementIndexedProjectionEffectPlan projected == fullCompatibilityPlan
                  && fmap effectTag fullCompatibilityPlan == [RecordBlockedTag, StopDaemonTag]
        _ -> False
  issueConfig = issueImplementIndexedConfig
  prNumber = PrNumber 7
  stalePr = PrNumber 8
  workerThread = ThreadId "worker-thread"
  planTurn = TurnId "turn-plan"
  planTurn2 = TurnId "turn-plan-2"
  implementationTurn = TurnId "turn-impl"
  reviewerThread = ThreadId "reviewer-thread"
  reviewedCommit = CommitSha "0123456789abcdef"
  finalReviewTurn = TurnId "turn-final-review"
  blockedReason = BlockedReason "blocked"
  readyToPlanPrefix =
    [ IssueImplementInitialized issueConfig workerThread
    , IssuePullRequestReusedEvent prNumber
    ]
  inPlanModeState =
    SomeWatcherState (IssueInPlanMode issueConfig prNumber (WorkerActive (ActiveTurn workerThread planTurn)))
  implementationReadyPrPrefix =
    readyToPlanPrefix
      <> [ IssuePlanTurnStartedEvent planTurn
         , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
         , IssuePullRequestBodyUpdatedEvent prNumber
         ]
  implementationReadyPrState =
    SomeWatcherState (IssueImplementationReady issueConfig (Just prNumber) (WorkerIdle workerThread))
  postMergePendingPrefix =
    implementationReadyPrPrefix
      <> [ IssueImplementationTurnStartedEvent implementationTurn
         , IssueImplementationCompletedEvent prNumber Nothing
         , IssueReviewHandoffInitializedEvent prNumber
         , IssueReviewHandoffStartedEvent prNumber
         , IssuePullRequestMergedEvent prNumber
         ]
  postMergePendingState =
    SomeWatcherState (IssuePostMergeReviewPendingReviewer issueConfig prNumber (WorkerIdle workerThread))
  completePrefix =
    postMergePendingPrefix
      <> [ IssueReviewerThreadReadyEvent reviewerThread
         , IssuePostMergeReviewStartedEvent reviewedCommit finalReviewTurn
         , IssuePostMergeReviewCleanEvent (CleanReviewEvidence reviewedCommit "LGTM")
         , IssueClosedEvent prNumber
         ]
  completeState =
    SomeWatcherState (CompleteState (IssueComplete prNumber) :: WatcherState 'IssueImplement 'Complete)
  wrongDomainState =
    SomeWatcherState (PlanningReady (PlannerConfig issueConfig.issueRepo (maxParallelForTest 1) []))

workflowIssueImplementIndexedDaemonRoutingIsLimitedToDaemonProjectionOnly :: IO Bool
workflowIssueImplementIndexedDaemonRoutingIsLimitedToDaemonProjectionOnly = do
  let routingPaths =
        [ "src" </> "CodexWatcher" </> "Domain" </> "IssueImplement" </> "Loop.hs"
        , "src" </> "CodexWatcher" </> "DaemonLoop.hs"
        , "src" </> "CodexWatcher" </> "DaemonLoop" </> "ActiveTurn.hs"
        , "src" </> "CodexWatcher" </> "DaemonLoop" </> "Runtime.hs"
        , "src" </> "CodexWatcher" </> "AutomaticLoop" </> "Runner.hs"
        , "src" </> "CodexWatcher" </> "AutomaticLoop" </> "Output.hs"
        ]
  sources <- traverse (\path -> (\source -> (path, Text.pack source)) <$> readFile path) routingPaths
  let forbiddenNeedles =
        [ "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed"
        , "projectIssueImplement"
        , "IssueImplementIndexedSpec"
        ]
      violations =
        [ path <> ": " <> Text.unpack needle
        | (path, source) <- sources
        , needle <- forbiddenNeedles
        , needle `Text.isInfixOf` source
        ]
  assert "indexed workflow issue implement daemon routing stays out of loop modules" (null violations)

workflowIssueImplementIndexedDaemonDoesNotRouteLaterProjectors :: IO Bool
workflowIssueImplementIndexedDaemonDoesNotRouteLaterProjectors = do
  source <- Text.pack <$> readFile ("src" </> "CodexWatcher" </> "Daemon.hs")
  let requiredNeedles =
        [ "projectIssueImplementWorkerThreadRefreshedImplementationReadyObservation"
        , "projectIssueImplementationTurnStartedObservation"
        , "projectIssueImplementationIncompleteObservation"
        , "projectIssueImplementationBlockedImplementationReadyObservation"
        , "projectIssueImplementationBlockedImplementingObservation"
        , "projectIssueImplementationCompletedImplementingObservation"
        , "projectIssueImplementReviewHandoffInitializedHandoffReadyObservation"
        , "projectIssueImplementReviewHandoffInitializedHandoffInitializedObservation"
        , "projectIssueImplementReviewHandoffInitializedWaitingForPrMergeObservation"
        , "projectIssueImplementReviewHandoffStartedHandoffInitializedObservation"
        , "projectIssueImplementReviewHandoffStartedWaitingForPrMergeObservation"
        , "projectIssueImplementationCompletedHandoffReadyObservation"
        , "projectIssueImplementationCompletedHandoffInitializedObservation"
        , "projectIssueImplementationCompletedWaitingForPrMergeObservation"
        , "projectIssueImplementReviewerThreadReadyHandoffReadyObservation"
        , "projectIssueImplementReviewerThreadReadyHandoffInitializedObservation"
        , "projectIssueImplementReviewerThreadReadyWaitingForPrMergeObservation"
        , "projectIssueImplementReviewerThreadReadyPostMergeReviewPendingReviewerObservation"
        , "projectIssueImplementReviewerThreadReadyPostMergeReviewReadyObservation"
        , "projectIssueImplementPullRequestMergedWaitingForPrMergeObservation"
        , "projectIssueImplementPostMergeReviewStartedObservation"
        , "projectIssueImplementPostMergeReviewerOutcomeCleanObservation"
        , "projectIssueImplementPostMergeReviewerOutcomeReworkObservation"
        , "projectIssueImplementPostMergeReviewerOutcomeIncompleteObservation"
        , "projectIssueImplementPostMergeReviewerOutcomeBlockedObservation"
        , "projectIssueImplementIssueClosedObservation"
        , "ObservedIssueClosed"
        ]
      forbiddenNeedles =
        [ "projectIssueImplementBlocked"
        , "ObservedIssueImplementBlocked"
        ]
      missingRequired =
        [ Text.unpack needle
        | needle <- requiredNeedles
        , not (needle `Text.isInfixOf` source)
        ]
      violations =
        [ Text.unpack needle
        | needle <- forbiddenNeedles
        , needle `Text.isInfixOf` source
        ]
  sequenceAnd
    [ assert "indexed workflow issue implement daemon routes required item-020 through item-023 projectors" (null missingRequired)
    , assert "indexed workflow issue implement daemon does not route item-024 projectors" (null violations)
    ]

data IssueImplementDaemonProjectionCase = IssueImplementDaemonProjectionCase
  { issueImplementDaemonProjectionCaseName :: String
  , issueImplementDaemonProjectionCaseEvents :: [WatcherEvent]
  , issueImplementDaemonProjectionCaseState :: SomeWatcherState
  , issueImplementDaemonProjectionCaseObservation :: DaemonObservation
  , issueImplementDaemonProjectionCaseProjection :: Either Text IssueImplementIndexed.IssueImplementIndexedProjection
  }

workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPlanPrSetupAndImplementationWorkerProjections :: IO Bool
workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPlanPrSetupAndImplementationWorkerProjections = do
  dryRunResults <- traverse (runIssueImplementDaemonProjectionCase DryRunActions) issueImplementDaemonPlanPrSetupAndImplementationWorkerProjectionCases
  executeResults <- traverse (runIssueImplementDaemonProjectionCase ExecuteActions) issueImplementDaemonPlanPrSetupAndImplementationWorkerProjectionCases
  pure (and dryRunResults && and executeResults)

workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchHandoffAndMergeWaitProjections :: IO Bool
workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchHandoffAndMergeWaitProjections = do
  dryRunResults <- traverse (runIssueImplementDaemonProjectionCase DryRunActions) issueImplementDaemonHandoffAndMergeWaitProjectionCases
  executeResults <- traverse (runIssueImplementDaemonProjectionCase ExecuteActions) issueImplementDaemonHandoffAndMergeWaitProjectionCases
  pure (and dryRunResults && and executeResults)

workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPostMergeReviewProjections :: IO Bool
workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPostMergeReviewProjections = do
  dryRunResults <- traverse (runIssueImplementDaemonProjectionCase DryRunActions) issueImplementDaemonPostMergeReviewProjectionCases
  executeResults <- traverse (runIssueImplementDaemonProjectionCase ExecuteActions) issueImplementDaemonPostMergeReviewProjectionCases
  pure (and dryRunResults && and executeResults)

workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchIssueCloseProjections :: IO Bool
workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchIssueCloseProjections = do
  dryRunResults <- traverse (runIssueImplementDaemonProjectionCase DryRunActions) issueImplementDaemonIssueCloseProjectionCases
  executeResults <- traverse (runIssueImplementDaemonProjectionCase ExecuteActions) issueImplementDaemonIssueCloseProjectionCases
  pure (and dryRunResults && and executeResults)

runIssueImplementDaemonProjectionCase :: ActionExecutionMode -> IssueImplementDaemonProjectionCase -> IO Bool
runIssueImplementDaemonProjectionCase executionMode testCase = do
  (executor, getCalls) <- fakeActionExecutor
  let runtimeConfig = effectRuntimeConfig issueImplementIndexedConfig.issueRepo "/tmp/work" 1200
      options = DaemonOptions "/tmp/events.jsonl" runtimeConfig executionMode
      modeName =
        case executionMode of
          DryRunActions -> "dry-run"
          ExecuteActions -> "execute"
      title suffix =
        "indexed workflow issue implement daemon "
          <> modeName
          <> " "
          <> issueImplementDaemonProjectionCaseName testCase
          <> " "
          <> suffix
  result <-
    runObservedDaemonTickWithEvents
      executor
      options
      testCase.issueImplementDaemonProjectionCaseEvents
      testCase.issueImplementDaemonProjectionCaseObservation
  calls <- getCalls
  case
    ( result
    , workflowPlanObservation @MoifoldSpec testCase.issueImplementDaemonProjectionCaseState testCase.issueImplementDaemonProjectionCaseObservation
    , testCase.issueImplementDaemonProjectionCaseProjection
    )
    of
    (Right tick, Right compatibilityPlan, Right projection) -> do
      let projectedPlan = projection.issueImplementIndexedProjectionPlanned
          projectedEffects = projection.issueImplementIndexedProjectionEffectPlan
          expectedCompiled = compileEffectPlan runtimeConfig projectedEffects
          expectedWrites =
            compatibilityStateWrites
              (runtimeStateDirPath runtimeConfig.effectRuntimeStateDir)
              tick.daemonObservedState
          expectedAppend =
            FakeAppendJsonLine "/tmp/events.jsonl" (toJSON tick.daemonObservedEvent)
          expectedWriteCalls =
            [ FakeWriteJson (compatibilityWritePath write) (compatibilityWriteValue write)
            | write <- expectedWrites
            ]
      modeResults <-
        case executionMode of
          DryRunActions ->
            sequence
              [ assert (title "does not commit or mutate") $
                  tick.daemonObservedCommittedEvents == []
                    && tick.daemonObservedActionReports == dryRunCompiledEffectPlan expectedCompiled
                    && WorkflowAudit.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Nothing
                    && null calls
              ]
          ExecuteActions ->
            sequence
              [ assert (title "commits event and compatibility writes") $
                  tick.daemonObservedCommittedEvents == [tick.daemonObservedEvent]
                    && expectedAppend `elem` calls
                    && all (`elem` calls) expectedWriteCalls
                    && all (\writeCall -> callBefore expectedAppend writeCall calls) expectedWriteCalls
                    && WorkflowAudit.workflowAuditCommittedEventLabel tick.daemonObservedAudit /= Nothing
              ]
      commonResults <-
        sequence
          [ assert (title "emits compatibility and indexed event") $
              tick.daemonObservedEvent == compatibilityPlan.plannedEvent
                && tick.daemonObservedEvent == projectedPlan.plannedEvent
          , assert (title "preserves planned effects and compiled request ids") $
              projectedPlan.plannedPreCommitEffects == compatibilityPlan.plannedPreCommitEffects
                && projectedPlan.plannedPostCommitEffects == compatibilityPlan.plannedPostCommitEffects
                && tick.daemonObservedCompiledEffects == expectedCompiled
          , assert (title "reaches indexed final state") $
              sameWatcherStateShape tick.daemonObservedState projection.issueImplementIndexedProjectionFinalState
                && workflowStateLabel @MoifoldSpec tick.daemonObservedState
                  == workflowStateLabel @MoifoldSpec projection.issueImplementIndexedProjectionFinalState
          , assert (title "keeps labels and compatibility writes stable") $
              projection.issueImplementIndexedProjectionSourceLabel
                == workflowStateLabel @MoifoldSpec testCase.issueImplementDaemonProjectionCaseState
                && projection.issueImplementIndexedProjectionTargetLabel
                  == workflowStateLabel @MoifoldSpec tick.daemonObservedState
                && tick.daemonObservedCompatibilityWrites == expectedWrites
          , assert (title "replays from expected source state") $
              sameWatcherStateShape
                tick.daemonObservedReplayResult.replayState
                testCase.issueImplementDaemonProjectionCaseState
          ]
      pure (and modeResults && and commonResults)
    (Left failure, _, _) -> do
      putStrLn ("FAIL indexed issue-implement daemon " <> modeName <> " " <> issueImplementDaemonProjectionCaseName testCase <> ": " <> Text.unpack (formatDaemonFailure failure))
      pure False
    _ ->
      assert (title "prepares compatibility and indexed plans") False

issueImplementDaemonPlanPrSetupAndImplementationWorkerProjectionCases :: [IssueImplementDaemonProjectionCase]
issueImplementDaemonPlanPrSetupAndImplementationWorkerProjectionCases =
  [ IssueImplementDaemonProjectionCase
      "plan turn start"
      readyToPlanPrefix
      readyToPlanState
      (DaemonIssueImplementObservation (ObservedPlanTurnStarted planTurn))
      (IssueImplementIndexed.projectIssueImplementPlanTurnStartedObservation readyToPlanState planTurn)
  , IssueImplementDaemonProjectionCase
      "plan completion"
      inPlanModePrefix
      inPlanModeState
      (DaemonIssueImplementObservation (ObservedPlanCompleted sampleIssuePlanMarkdown (Just implementationTurn)))
      (IssueImplementIndexed.projectIssueImplementPlanCompletedObservation inPlanModeState sampleIssuePlanMarkdown (Just implementationTurn))
  , IssueImplementDaemonProjectionCase
      "follow-up worker refresh"
      readyToPlanPrefix
      readyToPlanState
      (DaemonIssueImplementObservation (ObservedIssueWorkerThreadRefreshed refreshedWorker))
      (IssueImplementIndexed.projectIssueImplementWorkerThreadRefreshedReadyToPlanObservation readyToPlanState refreshedWorker)
  , IssueImplementDaemonProjectionCase
      "attempt branch advance"
      implementationReadyNoPrPrefix
      implementationReadyNoPrState
      (DaemonIssueImplementObservation (ObservedIssueAttemptBranchAdvanced followUpBranch))
      (IssueImplementIndexed.projectIssueImplementAttemptBranchAdvancedObservation implementationReadyNoPrState followUpBranch)
  , IssueImplementDaemonProjectionCase
      "pull request created"
      implementationReadyNoPrPrefix
      implementationReadyNoPrState
      (DaemonIssueImplementObservation (ObservedPullRequestCreated prNumber))
      (IssueImplementIndexed.projectIssueImplementPullRequestCreatedImplementationReadyObservation implementationReadyNoPrState prNumber)
  , IssueImplementDaemonProjectionCase
      "pull request reused"
      implementationReadyNoPrPrefix
      implementationReadyNoPrState
      (DaemonIssueImplementObservation (ObservedPullRequestReused prNumber))
      (IssueImplementIndexed.projectIssueImplementPullRequestReusedImplementationReadyObservation implementationReadyNoPrState prNumber)
  , IssueImplementDaemonProjectionCase
      "pull request body update"
      planReadyPrefix
      planReadyState
      (DaemonIssueImplementObservation (ObservedPullRequestBodyUpdated prNumber))
      (IssueImplementIndexed.projectIssueImplementPullRequestBodyUpdatedPlanReadyObservation planReadyState prNumber)
  , IssueImplementDaemonProjectionCase
      "implementation-ready worker refresh"
      implementationReadyPrPrefix
      implementationReadyPrState
      (DaemonIssueImplementObservation (ObservedIssueWorkerThreadRefreshed refreshedWorker))
      (IssueImplementIndexed.projectIssueImplementWorkerThreadRefreshedImplementationReadyObservation implementationReadyPrState refreshedWorker)
  , IssueImplementDaemonProjectionCase
      "implementation turn start"
      implementationReadyPrPrefix
      implementationReadyPrState
      (DaemonIssueImplementObservation (ObservedImplementationTurnStarted implementationTurn))
      (IssueImplementIndexed.projectIssueImplementationTurnStartedObservation implementationReadyPrState implementationTurn)
  , IssueImplementDaemonProjectionCase
      "implementation incomplete restart"
      implementingPrPrefix
      implementingPrState
      (DaemonIssueImplementObservation (ObservedImplementationIncomplete incompleteReason))
      (IssueImplementIndexed.projectIssueImplementationIncompleteObservation implementingPrState incompleteReason)
  , IssueImplementDaemonProjectionCase
      "implementation blocked from ready"
      implementationReadyPrPrefix
      implementationReadyPrState
      (DaemonIssueImplementObservation (ObservedImplementationBlocked blockedReason))
      (IssueImplementIndexed.projectIssueImplementationBlockedImplementationReadyObservation implementationReadyPrState blockedReason)
  , IssueImplementDaemonProjectionCase
      "implementation blocked from implementing"
      implementingPrPrefix
      implementingPrState
      (DaemonIssueImplementObservation (ObservedImplementationBlocked blockedReason))
      (IssueImplementIndexed.projectIssueImplementationBlockedImplementingObservation implementingPrState blockedReason)
  , IssueImplementDaemonProjectionCase
      "implementation completed with reviewer thread"
      implementingPrPrefix
      implementingPrState
      (DaemonIssueImplementObservation (ObservedImplementationCompleted prNumber (Just reviewerThread)))
      (IssueImplementIndexed.projectIssueImplementationCompletedImplementingObservation implementingPrState prNumber (Just reviewerThread))
  , IssueImplementDaemonProjectionCase
      "implementation completed without reviewer thread"
      implementingPrPrefix
      implementingPrState
      (DaemonIssueImplementObservation (ObservedImplementationCompleted prNumber Nothing))
      (IssueImplementIndexed.projectIssueImplementationCompletedImplementingObservation implementingPrState prNumber Nothing)
  , IssueImplementDaemonProjectionCase
      "implementation completed before known PR remains incomplete"
      implementingNoPrPrefix
      implementingNoPrState
      (DaemonIssueImplementObservation (ObservedImplementationIncomplete completedBeforeKnownPrReason))
      (IssueImplementIndexed.projectIssueImplementationIncompleteObservation implementingNoPrState completedBeforeKnownPrReason)
  , IssueImplementDaemonProjectionCase
      "implementation stale PR completion blocks"
      implementingPrPrefix
      implementingPrState
      (DaemonIssueImplementObservation (ObservedImplementationCompleted stalePr Nothing))
      (IssueImplementIndexed.projectIssueImplementationCompletedImplementingObservation implementingPrState stalePr Nothing)
  ]
 where
  issueConfig = issueImplementIndexedConfig
  prNumber = PrNumber 7
  stalePr = PrNumber 8
  workerThread = ThreadId "worker-thread"
  refreshedWorker = ThreadId "worker-thread-refreshed"
  reviewerThread = ThreadId "reviewer-thread"
  planTurn = TurnId "turn-plan"
  implementationTurn = TurnId "turn-impl"
  followUpBranch = BranchName "codex/issue-42-2"
  incompleteReason = "incomplete"
  completedBeforeKnownPrReason = "implementation completed before a pull request was known"
  blockedReason = BlockedReason "blocked"
  readyToPlanPrefix =
    [ IssueImplementInitialized issueConfig workerThread
    , IssuePullRequestReusedEvent prNumber
    ]
  inPlanModePrefix =
    readyToPlanPrefix <> [IssuePlanTurnStartedEvent planTurn]
  planReadyPrefix =
    inPlanModePrefix <> [IssuePlanCompletedEvent sampleIssuePlanMarkdown (Just implementationTurn)]
  implementationReadyPrPrefix =
    planReadyPrefix <> [IssuePullRequestBodyUpdatedEvent prNumber]
  implementationReadyNoPrPrefix =
    [IssueImplementInitialized issueConfig workerThread]
  implementingPrPrefix =
    implementationReadyPrPrefix <> [IssueImplementationTurnStartedEvent implementationTurn]
  implementingNoPrPrefix =
    implementationReadyNoPrPrefix <> [IssueImplementationTurnStartedEvent implementationTurn]
  readyToPlanState =
    SomeWatcherState (IssueReadyToPlan issueConfig prNumber (WorkerIdle workerThread))
  inPlanModeState =
    SomeWatcherState (IssueInPlanMode issueConfig prNumber (WorkerActive (ActiveTurn workerThread planTurn)))
  planReadyState =
    SomeWatcherState (IssuePlanReady issueConfig prNumber (WorkerIdle workerThread))
  implementationReadyPrState =
    SomeWatcherState (IssueImplementationReady issueConfig (Just prNumber) (WorkerIdle workerThread))
  implementationReadyNoPrState =
    SomeWatcherState (IssueImplementationReady issueConfig Nothing (WorkerIdle workerThread))
  implementingPrState =
    SomeWatcherState (IssueImplementing issueConfig (Just prNumber) (WorkerActive (ActiveTurn workerThread implementationTurn)))
  implementingNoPrState =
    SomeWatcherState (IssueImplementing issueConfig Nothing (WorkerActive (ActiveTurn workerThread implementationTurn)))

issueImplementDaemonHandoffAndMergeWaitProjectionCases :: [IssueImplementDaemonProjectionCase]
issueImplementDaemonHandoffAndMergeWaitProjectionCases =
  [ IssueImplementDaemonProjectionCase
      "handoff initialization from ready"
      handoffReadyPrefix
      handoffReadyState
      (DaemonIssueImplementObservation (ObservedReviewHandoffInitialized prNumber))
      (IssueImplementIndexed.projectIssueImplementReviewHandoffInitializedHandoffReadyObservation handoffReadyState prNumber)
  , IssueImplementDaemonProjectionCase
      "duplicate handoff initialization from initialized"
      handoffInitializedPrefix
      handoffInitializedState
      (DaemonIssueImplementObservation (ObservedReviewHandoffInitialized prNumber))
      (IssueImplementIndexed.projectIssueImplementReviewHandoffInitializedHandoffInitializedObservation handoffInitializedState prNumber)
  , IssueImplementDaemonProjectionCase
      "duplicate handoff initialization while waiting merge"
      waitingMergeWithReviewerPrefix
      waitingMergeWithReviewerState
      (DaemonIssueImplementObservation (ObservedReviewHandoffInitialized prNumber))
      (IssueImplementIndexed.projectIssueImplementReviewHandoffInitializedWaitingForPrMergeObservation waitingMergeWithReviewerState prNumber)
  , IssueImplementDaemonProjectionCase
      "handoff initialization wrong PR blocks"
      handoffReadyPrefix
      handoffReadyState
      (DaemonIssueImplementObservation (ObservedReviewHandoffInitialized stalePr))
      (IssueImplementIndexed.projectIssueImplementReviewHandoffInitializedHandoffReadyObservation handoffReadyState stalePr)
  , IssueImplementDaemonProjectionCase
      "handoff start from initialized"
      handoffInitializedPrefix
      handoffInitializedState
      (DaemonIssueImplementObservation (ObservedReviewHandoffStarted prNumber))
      (IssueImplementIndexed.projectIssueImplementReviewHandoffStartedHandoffInitializedObservation handoffInitializedState prNumber)
  , IssueImplementDaemonProjectionCase
      "duplicate handoff start while waiting merge"
      waitingMergeWithReviewerPrefix
      waitingMergeWithReviewerState
      (DaemonIssueImplementObservation (ObservedReviewHandoffStarted prNumber))
      (IssueImplementIndexed.projectIssueImplementReviewHandoffStartedWaitingForPrMergeObservation waitingMergeWithReviewerState prNumber)
  , IssueImplementDaemonProjectionCase
      "handoff start wrong PR blocks"
      handoffInitializedPrefix
      handoffInitializedState
      (DaemonIssueImplementObservation (ObservedReviewHandoffStarted stalePr))
      (IssueImplementIndexed.projectIssueImplementReviewHandoffStartedHandoffInitializedObservation handoffInitializedState stalePr)
  , IssueImplementDaemonProjectionCase
      "implementation completion idempotent from handoff ready"
      handoffReadyPrefix
      handoffReadyState
      (DaemonIssueImplementObservation (ObservedImplementationCompleted prNumber (Just reviewerThread)))
      (IssueImplementIndexed.projectIssueImplementationCompletedHandoffReadyObservation handoffReadyState prNumber (Just reviewerThread))
  , IssueImplementDaemonProjectionCase
      "implementation completion idempotent from handoff initialized"
      handoffInitializedPrefix
      handoffInitializedState
      (DaemonIssueImplementObservation (ObservedImplementationCompleted prNumber (Just reviewerThread)))
      (IssueImplementIndexed.projectIssueImplementationCompletedHandoffInitializedObservation handoffInitializedState prNumber (Just reviewerThread))
  , IssueImplementDaemonProjectionCase
      "implementation completion idempotent while waiting merge"
      waitingMergeWithReviewerPrefix
      waitingMergeWithReviewerState
      (DaemonIssueImplementObservation (ObservedImplementationCompleted prNumber (Just reviewerThread)))
      (IssueImplementIndexed.projectIssueImplementationCompletedWaitingForPrMergeObservation waitingMergeWithReviewerState prNumber (Just reviewerThread))
  , IssueImplementDaemonProjectionCase
      "implementation completion wrong PR blocks after handoff"
      handoffReadyPrefix
      handoffReadyState
      (DaemonIssueImplementObservation (ObservedImplementationCompleted stalePr Nothing))
      (IssueImplementIndexed.projectIssueImplementationCompletedHandoffReadyObservation handoffReadyState stalePr Nothing)
  , IssueImplementDaemonProjectionCase
      "reviewer thread ready from handoff ready"
      handoffReadyNoReviewerPrefix
      handoffReadyNoReviewerState
      (DaemonIssueImplementObservation (ObservedIssueReviewerThreadReady reviewerThread))
      (IssueImplementIndexed.projectIssueImplementReviewerThreadReadyHandoffReadyObservation handoffReadyNoReviewerState reviewerThread)
  , IssueImplementDaemonProjectionCase
      "reviewer thread ready from handoff initialized"
      handoffInitializedNoReviewerPrefix
      handoffInitializedNoReviewerState
      (DaemonIssueImplementObservation (ObservedIssueReviewerThreadReady reviewerThread))
      (IssueImplementIndexed.projectIssueImplementReviewerThreadReadyHandoffInitializedObservation handoffInitializedNoReviewerState reviewerThread)
  , IssueImplementDaemonProjectionCase
      "reviewer thread ready while waiting merge"
      waitingMergeNoReviewerPrefix
      waitingMergeState
      (DaemonIssueImplementObservation (ObservedIssueReviewerThreadReady reviewerThread))
      (IssueImplementIndexed.projectIssueImplementReviewerThreadReadyWaitingForPrMergeObservation waitingMergeState reviewerThread)
  , IssueImplementDaemonProjectionCase
      "reviewer thread ready from post-merge pending"
      postMergePendingPrefix
      postMergePendingState
      (DaemonIssueImplementObservation (ObservedIssueReviewerThreadReady reviewerThread))
      (IssueImplementIndexed.projectIssueImplementReviewerThreadReadyPostMergeReviewPendingReviewerObservation postMergePendingState reviewerThread)
  , IssueImplementDaemonProjectionCase
      "reviewer thread ready refreshes post-merge ready"
      postMergeReadyPrefix
      postMergeReadyState
      (DaemonIssueImplementObservation (ObservedIssueReviewerThreadReady refreshedReviewer))
      (IssueImplementIndexed.projectIssueImplementReviewerThreadReadyPostMergeReviewReadyObservation postMergeReadyState refreshedReviewer)
  , IssueImplementDaemonProjectionCase
      "pull request merged without reviewer enters pending"
      waitingMergeNoReviewerPrefix
      waitingMergeState
      (DaemonIssueImplementObservation (ObservedPullRequestMerged prNumber))
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedWaitingForPrMergeObservation waitingMergeState prNumber)
  , IssueImplementDaemonProjectionCase
      "pull request merged with reviewer enters review ready"
      waitingMergeWithReviewerPrefix
      waitingMergeWithReviewerState
      (DaemonIssueImplementObservation (ObservedPullRequestMerged prNumber))
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedWaitingForPrMergeObservation waitingMergeWithReviewerState prNumber)
  , IssueImplementDaemonProjectionCase
      "pull request merged wrong PR blocks"
      waitingMergeWithReviewerPrefix
      waitingMergeWithReviewerState
      (DaemonIssueImplementObservation (ObservedPullRequestMerged stalePr))
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedWaitingForPrMergeObservation waitingMergeWithReviewerState stalePr)
  ]
 where
  issueConfig = issueImplementIndexedConfig
  prNumber = PrNumber 7
  stalePr = PrNumber 8
  workerThread = ThreadId "worker-thread"
  reviewerThread = ThreadId "reviewer-thread"
  refreshedReviewer = ThreadId "reviewer-thread-refreshed"
  planTurn = TurnId "turn-plan"
  implementationTurn = TurnId "turn-impl"
  readyToPlanPrefix =
    [ IssueImplementInitialized issueConfig workerThread
    , IssuePullRequestReusedEvent prNumber
    ]
  inPlanModePrefix =
    readyToPlanPrefix <> [IssuePlanTurnStartedEvent planTurn]
  planReadyPrefix =
    inPlanModePrefix <> [IssuePlanCompletedEvent sampleIssuePlanMarkdown (Just implementationTurn)]
  implementationReadyPrPrefix =
    planReadyPrefix <> [IssuePullRequestBodyUpdatedEvent prNumber]
  implementingPrPrefix =
    implementationReadyPrPrefix <> [IssueImplementationTurnStartedEvent implementationTurn]
  handoffReadyPrefix =
    implementingPrPrefix <> [IssueImplementationCompletedEvent prNumber (Just reviewerThread)]
  handoffReadyNoReviewerPrefix =
    implementingPrPrefix <> [IssueImplementationCompletedEvent prNumber Nothing]
  handoffInitializedPrefix =
    handoffReadyPrefix <> [IssueReviewHandoffInitializedEvent prNumber]
  handoffInitializedNoReviewerPrefix =
    handoffReadyNoReviewerPrefix <> [IssueReviewHandoffInitializedEvent prNumber]
  waitingMergeWithReviewerPrefix =
    handoffInitializedPrefix <> [IssueReviewHandoffStartedEvent prNumber]
  waitingMergeNoReviewerPrefix =
    handoffInitializedNoReviewerPrefix <> [IssueReviewHandoffStartedEvent prNumber]
  postMergePendingPrefix =
    waitingMergeNoReviewerPrefix <> [IssuePullRequestMergedEvent prNumber]
  postMergeReadyPrefix =
    waitingMergeWithReviewerPrefix <> [IssuePullRequestMergedEvent prNumber]
  handoffReadyState =
    SomeWatcherState (IssueHandoffReady issueConfig prNumber (WorkerIdle workerThread) (Just (ReviewerIdle reviewerThread)))
  handoffReadyNoReviewerState =
    SomeWatcherState (IssueHandoffReady issueConfig prNumber (WorkerIdle workerThread) Nothing)
  handoffInitializedState =
    SomeWatcherState (IssueHandoffInitialized issueConfig prNumber (WorkerIdle workerThread) (Just (ReviewerIdle reviewerThread)))
  handoffInitializedNoReviewerState =
    SomeWatcherState (IssueHandoffInitialized issueConfig prNumber (WorkerIdle workerThread) Nothing)
  waitingMergeState =
    SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber (WorkerIdle workerThread) Nothing)
  waitingMergeWithReviewerState =
    SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber (WorkerIdle workerThread) (Just (ReviewerIdle reviewerThread)))
  postMergePendingState =
    SomeWatcherState (IssuePostMergeReviewPendingReviewer issueConfig prNumber (WorkerIdle workerThread))
  postMergeReadyState =
    SomeWatcherState (IssuePostMergeReviewReady issueConfig prNumber (WorkerIdle workerThread) (ReviewerIdle reviewerThread))

issueImplementDaemonPostMergeReviewProjectionCases :: [IssueImplementDaemonProjectionCase]
issueImplementDaemonPostMergeReviewProjectionCases =
  [ IssueImplementDaemonProjectionCase
      "post-merge final review turn start"
      postMergeReadyPrefix
      postMergeReadyState
      (DaemonIssueImplementObservation (ObservedPostMergeReviewStarted reviewedCommit finalReviewTurn))
      (IssueImplementIndexed.projectIssueImplementPostMergeReviewStartedObservation postMergeReadyState reviewedCommit finalReviewTurn)
  , IssueImplementDaemonProjectionCase
      "post-merge clean final review closes issue"
      postMergeReviewingPrefix
      postMergeReviewingState
      (DaemonIssueImplementObservation (ObservedPostMergeReviewerOutcome (IssueFinalReviewClean cleanEvidence)))
      (IssueImplementIndexed.projectIssueImplementPostMergeReviewerOutcomeCleanObservation postMergeReviewingState cleanEvidence)
  , IssueImplementDaemonProjectionCase
      "post-merge rework final review starts follow-up"
      postMergeReviewingPrefix
      postMergeReviewingState
      (DaemonIssueImplementObservation (ObservedPostMergeReviewerOutcome (IssueFinalReviewRework reviewEvidence)))
      (IssueImplementIndexed.projectIssueImplementPostMergeReviewerOutcomeReworkObservation postMergeReviewingState reviewEvidence)
  , IssueImplementDaemonProjectionCase
      "post-merge incomplete final review retries"
      postMergeReviewingPrefix
      postMergeReviewingState
      (DaemonIssueImplementObservation (ObservedPostMergeReviewerOutcome (IssueFinalReviewIncomplete incompleteReason)))
      (IssueImplementIndexed.projectIssueImplementPostMergeReviewerOutcomeIncompleteObservation postMergeReviewingState incompleteReason)
  , IssueImplementDaemonProjectionCase
      "post-merge blocked final review stops"
      postMergeReviewingPrefix
      postMergeReviewingState
      (DaemonIssueImplementObservation (ObservedPostMergeReviewerOutcome (IssueFinalReviewBlocked blockedReason)))
      (IssueImplementIndexed.projectIssueImplementPostMergeReviewerOutcomeBlockedObservation postMergeReviewingState blockedReason)
  ]
 where
  issueConfig = issueImplementIndexedConfig
  prNumber = PrNumber 7
  workerThread = ThreadId "worker-thread"
  reviewerThread = ThreadId "reviewer-thread"
  planTurn = TurnId "turn-plan"
  implementationTurn = TurnId "turn-impl"
  finalReviewTurn = TurnId "turn-final-review"
  reviewedCommit = CommitSha "0123456789abcdef"
  incompleteReason = "incomplete"
  blockedReason = BlockedReason "blocked"
  cleanEvidence = CleanReviewEvidence reviewedCommit "LGTM"
  reviewEvidence = reviewEvidenceFromSummaries ("needs follow-up" :| []) reviewedCommit
  readyToPlanPrefix =
    [ IssueImplementInitialized issueConfig workerThread
    , IssuePullRequestReusedEvent prNumber
    ]
  inPlanModePrefix =
    readyToPlanPrefix <> [IssuePlanTurnStartedEvent planTurn]
  planReadyPrefix =
    inPlanModePrefix <> [IssuePlanCompletedEvent sampleIssuePlanMarkdown (Just implementationTurn)]
  implementationReadyPrPrefix =
    planReadyPrefix <> [IssuePullRequestBodyUpdatedEvent prNumber]
  implementingPrPrefix =
    implementationReadyPrPrefix <> [IssueImplementationTurnStartedEvent implementationTurn]
  handoffReadyPrefix =
    implementingPrPrefix <> [IssueImplementationCompletedEvent prNumber (Just reviewerThread)]
  handoffInitializedPrefix =
    handoffReadyPrefix <> [IssueReviewHandoffInitializedEvent prNumber]
  waitingMergePrefix =
    handoffInitializedPrefix <> [IssueReviewHandoffStartedEvent prNumber]
  postMergeReadyPrefix =
    waitingMergePrefix <> [IssuePullRequestMergedEvent prNumber]
  postMergeReviewingPrefix =
    postMergeReadyPrefix <> [IssuePostMergeReviewStartedEvent reviewedCommit finalReviewTurn]
  postMergeReadyState =
    SomeWatcherState (IssuePostMergeReviewReady issueConfig prNumber (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
  postMergeReviewingState =
    SomeWatcherState (IssuePostMergeReviewing issueConfig prNumber (WorkerIdle workerThread) reviewedCommit (ReviewerActive (ActiveTurn reviewerThread finalReviewTurn)))

issueImplementDaemonIssueCloseProjectionCases :: [IssueImplementDaemonProjectionCase]
issueImplementDaemonIssueCloseProjectionCases =
  [ IssueImplementDaemonProjectionCase
      "issue close completes"
      waitingClosePrefix
      waitingCloseState
      (DaemonIssueImplementObservation (ObservedIssueClosed prNumber))
      (IssueImplementIndexed.projectIssueImplementIssueClosedObservation waitingCloseState prNumber)
  , IssueImplementDaemonProjectionCase
      "wrong issue close blocks"
      waitingClosePrefix
      waitingCloseState
      (DaemonIssueImplementObservation (ObservedIssueClosed stalePr))
      (IssueImplementIndexed.projectIssueImplementIssueClosedObservation waitingCloseState stalePr)
  ]
 where
  issueConfig = issueImplementIndexedConfig
  prNumber = PrNumber 7
  stalePr = PrNumber 8
  workerThread = ThreadId "worker-thread"
  reviewerThread = ThreadId "reviewer-thread"
  planTurn = TurnId "turn-plan"
  implementationTurn = TurnId "turn-impl"
  finalReviewTurn = TurnId "turn-final-review"
  reviewedCommit = CommitSha "0123456789abcdef"
  cleanEvidence = CleanReviewEvidence reviewedCommit "LGTM"
  readyToPlanPrefix =
    [ IssueImplementInitialized issueConfig workerThread
    , IssuePullRequestReusedEvent prNumber
    ]
  inPlanModePrefix =
    readyToPlanPrefix <> [IssuePlanTurnStartedEvent planTurn]
  planReadyPrefix =
    inPlanModePrefix <> [IssuePlanCompletedEvent sampleIssuePlanMarkdown (Just implementationTurn)]
  implementationReadyPrPrefix =
    planReadyPrefix <> [IssuePullRequestBodyUpdatedEvent prNumber]
  implementingPrPrefix =
    implementationReadyPrPrefix <> [IssueImplementationTurnStartedEvent implementationTurn]
  handoffReadyPrefix =
    implementingPrPrefix <> [IssueImplementationCompletedEvent prNumber (Just reviewerThread)]
  handoffInitializedPrefix =
    handoffReadyPrefix <> [IssueReviewHandoffInitializedEvent prNumber]
  waitingMergePrefix =
    handoffInitializedPrefix <> [IssueReviewHandoffStartedEvent prNumber]
  postMergeReadyPrefix =
    waitingMergePrefix <> [IssuePullRequestMergedEvent prNumber]
  postMergeReviewingPrefix =
    postMergeReadyPrefix <> [IssuePostMergeReviewStartedEvent reviewedCommit finalReviewTurn]
  waitingClosePrefix =
    postMergeReviewingPrefix <> [IssuePostMergeReviewCleanEvent cleanEvidence]
  waitingCloseState =
    SomeWatcherState (IssueWaitingForIssueClose issueConfig prNumber)

issueImplementIndexedSpecMatchesCompatibility :: IssueImplementIndexedPolicyCase -> IO Bool
issueImplementIndexedSpecMatchesCompatibility (IssueImplementIndexedPolicyCase title prefix state issueObservation indexedState indexedObservation indexedEvent projection expectedTags) =
  assert title $
    case
      ( issueImplementObserve state issueObservation
      , workflowObserve @MoifoldSpec state daemonObservation
      , workflowPlanObservation @MoifoldSpec state daemonObservation
      , IndexedWorkflow.indexedWorkflowObserve @IssueImplementIndexed.IssueImplementIndexedSpec indexedState indexedObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @IssueImplementIndexed.IssueImplementIndexedSpec indexedState indexedObservation
      , IndexedWorkflow.indexedWorkflowApplyEvent @IssueImplementIndexed.IssueImplementIndexedSpec indexedState indexedEvent
      , workflowApplyEvent @MoifoldSpec state expectedEvent
      , workflowReplayEvents @MoifoldSpec (prefix <> [expectedEvent])
      , IndexedWorkflow.indexedWorkflowReplayEvents @IssueImplementIndexed.IssueImplementIndexedSpec (issueImplementIndexedSomePrefix prefix <> [IndexedWorkflow.SomeIndexedWorkflowEvent indexedEvent])
      , projection
      )
      of
      ( Right facadeObserved
        , Right compatibilityObserved
        , Right compatibilityPlan
        , Right indexedObserved
        , Right indexedPlan
        , Right (IssueImplementIndexed.IssueImplementIndexedState indexedAppliedState, IssueImplementIndexed.IssueImplementIndexedEffectPlan indexedAppliedEffects)
        , Right (compatibilityAppliedState, compatibilityAppliedEffects)
        , Right compatibilityReplay
        , Right indexedReplay
        , Right projected
        ) ->
          let IssueImplementIndexed.IssueImplementIndexedState indexedNextState =
                IndexedWorkflow.indexedWorkflowObservedState @IssueImplementIndexed.IssueImplementIndexedSpec indexedObserved
              projectedPlan = IssueImplementIndexed.issueImplementIndexedProjectionPlanned projected
              fullCompatibilityPlan = compatibilityPlan.plannedPreCommitEffects <> compatibilityPlan.plannedPostCommitEffects
              indexedFullPlan =
                IssueImplementIndexed.IssueImplementIndexedEffectPlan fullCompatibilityPlan
                  :: IssueImplementIndexed.IssueImplementIndexedEffectPlan source target
              indexedReplayValue = issueImplementIndexedReplayResult indexedReplay
              runtimeConfig = effectRuntimeConfig issueImplementIndexedConfig.issueRepo "/tmp/work" 1700
              workflowCompiled = WorkflowExecution.compileWorkflowEffectPlanWithMetadata runtimeConfig fullCompatibilityPlan
              legacyCompiled = compileEffectPlan runtimeConfig fullCompatibilityPlan
              compatibilityWrites = compatibilityStateWrites "/tmp/state" compatibilityObserved.observedState
              indexedWrites = compatibilityStateWrites "/tmp/state" (IssueImplementIndexed.issueImplementIndexedProjectionFinalState projected)
           in facadeObserved.issueImplementTickEvent == compatibilityObserved.observedEvent
                && facadeObserved.issueImplementTickEffects == compatibilityObserved.observedEffects
                && sameWatcherStateShape facadeObserved.issueImplementTickState compatibilityObserved.observedState
                && projectedPlan.plannedEvent == compatibilityPlan.plannedEvent
                && projectedPlan.plannedPreCommitEffects == compatibilityPlan.plannedPreCommitEffects
                && projectedPlan.plannedPostCommitEffects == compatibilityPlan.plannedPostCommitEffects
                && issueImplementIndexedTransitionEvent indexedPlan == compatibilityPlan.plannedEvent
                && issueImplementIndexedTransitionPreCommitEffects indexedPlan == compatibilityPlan.plannedPreCommitEffects
                && issueImplementIndexedTransitionPostCommitEffects indexedPlan == compatibilityPlan.plannedPostCommitEffects
                && fullCompatibilityPlan == compatibilityObserved.observedEffects
                && fmap effectTag fullCompatibilityPlan == expectedTags
                && workflowStateLabel @MoifoldSpec indexedNextState == workflowStateLabel @MoifoldSpec compatibilityObserved.observedState
                && sameWatcherStateShape compatibilityObserved.observedState indexedNextState
                && sameWatcherStateShape compatibilityObserved.observedState indexedAppliedState
                && sameWatcherStateShape compatibilityObserved.observedState compatibilityAppliedState
                && indexedAppliedEffects == compatibilityAppliedEffects
                && IssueImplementIndexed.issueImplementIndexedProjectionSourceLabel projected == workflowStateLabel @MoifoldSpec state
                && IssueImplementIndexed.issueImplementIndexedProjectionTargetLabel projected == workflowStateLabel @MoifoldSpec compatibilityObserved.observedState
                && workflowStateLabel @MoifoldSpec (IssueImplementIndexed.issueImplementIndexedProjectionFinalState projected) == workflowStateLabel @MoifoldSpec compatibilityObserved.observedState
                && IssueImplementIndexed.issueImplementIndexedProjectionEffectPlan projected == fullCompatibilityPlan
                && compatibilityWrites == indexedWrites
                && workflowValidateEffects @MoifoldSpec state fullCompatibilityPlan
                  == IndexedWorkflow.indexedWorkflowValidateEffects @IssueImplementIndexed.IssueImplementIndexedSpec indexedState indexedFullPlan
                && and
                  [ workflowEffectAllowed @MoifoldSpec state effect
                      == IndexedWorkflow.indexedWorkflowEffectAllowed @IssueImplementIndexed.IssueImplementIndexedSpec indexedState (IssueImplementIndexed.IssueImplementIndexedEffect effect)
                  | effect <- fullCompatibilityPlan
                  ]
                && sameWatcherStateShape compatibilityReplay.replayState indexedReplayValue.replayState
                && workflowStateLabel @MoifoldSpec compatibilityReplay.replayState == workflowStateLabel @MoifoldSpec indexedReplayValue.replayState
                && compatibilityReplay.replayEffects == indexedReplayValue.replayEffects
                && fmap WorkflowExecution.workflowPlannedAction workflowCompiled.workflowCompiledActions == legacyCompiled.compiledActions
                && WorkflowExecution.workflowCompiledNextRequestId workflowCompiled == legacyCompiled.compiledNextRequestId
                && WorkflowExecution.dryRunWorkflowCompiledEffectPlan workflowCompiled == dryRunCompiledEffectPlan legacyCompiled
      _ -> False
 where
  daemonObservation = DaemonIssueImplementObservation issueObservation
  expectedEvent =
    case indexedEvent of
      IssueImplementIndexed.IssueImplementIndexedEvent _sourceLabel _targetLabel event -> event

issueImplementIndexedTransitionEvent
  :: IndexedWorkflow.IndexedPlannedTransition IssueImplementIndexed.IssueImplementIndexedSpec source target
  -> WatcherEvent
issueImplementIndexedTransitionEvent transition =
  case IndexedWorkflow.indexedPlannedEvent transition of
    IssueImplementIndexed.IssueImplementIndexedEvent _sourceLabel _targetLabel event -> event

issueImplementIndexedTransitionPreCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition IssueImplementIndexed.IssueImplementIndexedSpec source target
  -> EffectPlan
issueImplementIndexedTransitionPreCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPreCommitEffects transition of
    IssueImplementIndexed.IssueImplementIndexedEffectPlan effects -> effects

issueImplementIndexedTransitionPostCommitEffects
  :: IndexedWorkflow.IndexedPlannedTransition IssueImplementIndexed.IssueImplementIndexedSpec source target
  -> EffectPlan
issueImplementIndexedTransitionPostCommitEffects transition =
  case IndexedWorkflow.indexedPlannedPostCommitEffects transition of
    IssueImplementIndexed.IssueImplementIndexedEffectPlan effects -> effects

issueImplementIndexedReplayResult :: IndexedWorkflow.SomeIndexedWorkflowReplayResult IssueImplementIndexed.IssueImplementIndexedSpec -> EventReplayResult
issueImplementIndexedReplayResult (IndexedWorkflow.SomeIndexedWorkflowReplayResult (IssueImplementIndexed.IssueImplementIndexedReplayResult replay)) =
  replay

issueImplementIndexedSomePrefix :: [WatcherEvent] -> [IndexedWorkflow.SomeIndexedWorkflowEvent IssueImplementIndexed.IssueImplementIndexedSpec]
issueImplementIndexedSomePrefix =
  fmap (issueImplementIndexedSomeEvent "IssueImplement/Implementing" "IssueImplement/Implementing")

issueImplementIndexedSomeEvent :: Text -> Text -> WatcherEvent -> IndexedWorkflow.SomeIndexedWorkflowEvent IssueImplementIndexed.IssueImplementIndexedSpec
issueImplementIndexedSomeEvent sourceLabel targetLabel event =
  IndexedWorkflow.SomeIndexedWorkflowEvent
    ( IssueImplementIndexed.IssueImplementIndexedEvent sourceLabel targetLabel event
        :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedImplementing
    )

issueImplementIndexedObservation
  :: Text
  -> Text
  -> IssueImplementObservation
  -> IssueImplementIndexed.IssueImplementIndexedObservation source target
issueImplementIndexedObservation sourceLabel targetLabel =
  IssueImplementIndexed.IssueImplementIndexedObservation sourceLabel targetLabel . DaemonIssueImplementObservation

issueImplementIndexedConfig :: IssueConfig
issueImplementIndexedConfig =
  IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")

issueImplementIndexedPolicyCases :: [IssueImplementIndexedPolicyCase]
issueImplementIndexedPolicyCases =
  [ c "indexed workflow issue implement plan turn start matches compatibility" readyToPlanPrefix readyToPlanState (ObservedPlanTurnStarted planTurn)
      (IssueImplementIndexed.IssueImplementIndexedState readyToPlanState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedReadyToPlan)
      (obs "IssueImplement/PlanMode" "IssueImplement/PlanMode" (ObservedPlanTurnStarted planTurn) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedReadyToPlan IssueImplementIndexed.IssueImplementIndexedInPlanMode)
      (ev "IssueImplement/PlanMode" "IssueImplement/PlanMode" (IssuePlanTurnStartedEvent planTurn) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedReadyToPlan IssueImplementIndexed.IssueImplementIndexedInPlanMode)
      (IssueImplementIndexed.projectIssueImplementPlanTurnStartedObservation readyToPlanState planTurn)
      [StartIssuePlanWorkerTurnTag]
  , c "indexed workflow issue implement plan completion matches compatibility" inPlanModePrefix inPlanModeState (ObservedPlanCompleted sampleIssuePlanMarkdown (Just implementationTurn))
      (IssueImplementIndexed.IssueImplementIndexedState inPlanModeState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedInPlanMode)
      (obs "IssueImplement/PlanMode" "IssueImplement/Implementing" (ObservedPlanCompleted sampleIssuePlanMarkdown (Just implementationTurn)) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedInPlanMode IssueImplementIndexed.IssueImplementIndexedPlanReady)
      (ev "IssueImplement/PlanMode" "IssueImplement/Implementing" (IssuePlanCompletedEvent sampleIssuePlanMarkdown (Just implementationTurn)) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedInPlanMode IssueImplementIndexed.IssueImplementIndexedPlanReady)
      (IssueImplementIndexed.projectIssueImplementPlanCompletedObservation inPlanModeState sampleIssuePlanMarkdown (Just implementationTurn))
      [RecordIssuePlanTag, SleepUntilNextPollTag]
  , c "indexed workflow issue implement attempt branch advance matches compatibility" implementationReadyNoPrPrefix implementationReadyNoPrState (ObservedIssueAttemptBranchAdvanced followUpBranch)
      (IssueImplementIndexed.IssueImplementIndexedState implementationReadyNoPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueAttemptBranchAdvanced followUpBranch) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueAttemptBranchAdvancedEvent followUpBranch) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (IssueImplementIndexed.projectIssueImplementAttemptBranchAdvancedObservation implementationReadyNoPrState followUpBranch)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement worker refresh ready-to-plan matches compatibility" readyToPlanPrefix readyToPlanState (ObservedIssueWorkerThreadRefreshed refreshedWorker)
      (IssueImplementIndexed.IssueImplementIndexedState readyToPlanState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedReadyToPlan)
      (obs "IssueImplement/PlanMode" "IssueImplement/PlanMode" (ObservedIssueWorkerThreadRefreshed refreshedWorker) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedReadyToPlan IssueImplementIndexed.IssueImplementIndexedReadyToPlan)
      (ev "IssueImplement/PlanMode" "IssueImplement/PlanMode" (IssueWorkerThreadRefreshed refreshedWorker) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedReadyToPlan IssueImplementIndexed.IssueImplementIndexedReadyToPlan)
      (IssueImplementIndexed.projectIssueImplementWorkerThreadRefreshedReadyToPlanObservation readyToPlanState refreshedWorker)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement worker refresh plan-ready matches compatibility" planReadyPrefix planReadyState (ObservedIssueWorkerThreadRefreshed refreshedWorker)
      (IssueImplementIndexed.IssueImplementIndexedState planReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPlanReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueWorkerThreadRefreshed refreshedWorker) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPlanReady IssueImplementIndexed.IssueImplementIndexedPlanReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueWorkerThreadRefreshed refreshedWorker) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPlanReady IssueImplementIndexed.IssueImplementIndexedPlanReady)
      (IssueImplementIndexed.projectIssueImplementWorkerThreadRefreshedPlanReadyObservation planReadyState refreshedWorker)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement worker refresh implementation-ready matches compatibility" implementationReadyPrPrefix implementationReadyPrState (ObservedIssueWorkerThreadRefreshed refreshedWorker)
      (IssueImplementIndexed.IssueImplementIndexedState implementationReadyPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueWorkerThreadRefreshed refreshedWorker) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueWorkerThreadRefreshed refreshedWorker) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (IssueImplementIndexed.projectIssueImplementWorkerThreadRefreshedImplementationReadyObservation implementationReadyPrState refreshedWorker)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement pull request created from ready matches compatibility" implementationReadyNoPrPrefix implementationReadyNoPrState (ObservedPullRequestCreated prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState implementationReadyNoPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (obs "IssueImplement/Implementing" "IssueImplement/PlanMode" (ObservedPullRequestCreated prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedReadyToPlan)
      (ev "IssueImplement/Implementing" "IssueImplement/PlanMode" (IssuePullRequestCreatedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedReadyToPlan)
      (IssueImplementIndexed.projectIssueImplementPullRequestCreatedImplementationReadyObservation implementationReadyNoPrState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement pull request created from implementing matches compatibility" implementingNoPrPrefix implementingNoPrState (ObservedPullRequestCreated prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState implementingNoPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementing)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestCreated prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedImplementing)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestCreatedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedImplementing)
      (IssueImplementIndexed.projectIssueImplementPullRequestCreatedImplementingObservation implementingNoPrState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement pull request reused from ready matches compatibility" implementationReadyNoPrPrefix implementationReadyNoPrState (ObservedPullRequestReused prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState implementationReadyNoPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (obs "IssueImplement/Implementing" "IssueImplement/PlanMode" (ObservedPullRequestReused prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedReadyToPlan)
      (ev "IssueImplement/Implementing" "IssueImplement/PlanMode" (IssuePullRequestReusedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedReadyToPlan)
      (IssueImplementIndexed.projectIssueImplementPullRequestReusedImplementationReadyObservation implementationReadyNoPrState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement pull request reused from implementing matches compatibility" implementingNoPrPrefix implementingNoPrState (ObservedPullRequestReused prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState implementingNoPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementing)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestReused prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedImplementing)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestReusedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedImplementing)
      (IssueImplementIndexed.projectIssueImplementPullRequestReusedImplementingObservation implementingNoPrState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement pull request body update plan-ready matches compatibility writes" planReadyPrefix planReadyState (ObservedPullRequestBodyUpdated prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState planReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPlanReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestBodyUpdated prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPlanReady IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestBodyUpdatedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPlanReady IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (IssueImplementIndexed.projectIssueImplementPullRequestBodyUpdatedPlanReadyObservation planReadyState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement pull request body update implementation-ready matches compatibility writes" implementationReadyPrPrefix implementationReadyPrState (ObservedPullRequestBodyUpdated prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState implementationReadyPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestBodyUpdated prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestBodyUpdatedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (IssueImplementIndexed.projectIssueImplementPullRequestBodyUpdatedImplementationReadyObservation implementationReadyPrState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement pull request body update implementing matches compatibility writes" implementingPrPrefix implementingPrState (ObservedPullRequestBodyUpdated prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState implementingPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementing)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestBodyUpdated prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedImplementing)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestBodyUpdatedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedImplementing)
      (IssueImplementIndexed.projectIssueImplementPullRequestBodyUpdatedImplementingObservation implementingPrState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement implementation turn start matches compatibility request id" implementationReadyPrPrefix implementationReadyPrState (ObservedImplementationTurnStarted implementationTurn)
      (IssueImplementIndexed.IssueImplementIndexedState implementationReadyPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationTurnStarted implementationTurn) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedImplementing)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueImplementationTurnStartedEvent implementationTurn) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedImplementing)
      (IssueImplementIndexed.projectIssueImplementationTurnStartedObservation implementationReadyPrState implementationTurn)
      [StartIssueImplementationWorkerTurnTag]
  , c "indexed workflow issue implement incomplete restarts worker" implementingPrPrefix implementingPrState (ObservedImplementationIncomplete incompleteReason)
      (IssueImplementIndexed.IssueImplementIndexedState implementingPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementing)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationIncomplete incompleteReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueImplementationIncompleteEvent incompleteReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (IssueImplementIndexed.projectIssueImplementationIncompleteObservation implementingPrState incompleteReason)
      [StartIssueImplementationWorkerTurnTag]
  , c "indexed workflow issue implement implementation blocked stops from active turn" implementingPrPrefix implementingPrState (ObservedImplementationBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState implementingPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementing)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedImplementationBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (IssueImplementationBlockedEvent blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementationBlockedImplementingObservation implementingPrState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement implementation blocked stops from ready state" implementationReadyPrPrefix implementationReadyPrState (ObservedImplementationBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState implementationReadyPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedImplementationBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (IssueImplementationBlockedEvent blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementationBlockedImplementationReadyObservation implementationReadyPrState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement completion initializes handoff" implementingPrPrefix implementingPrState (ObservedImplementationCompleted prNumber (Just reviewerThread))
      (IssueImplementIndexed.IssueImplementIndexedState implementingPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementing)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationCompleted prNumber (Just reviewerThread)) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueImplementationCompletedEvent prNumber (Just reviewerThread)) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (IssueImplementIndexed.projectIssueImplementationCompletedImplementingObservation implementingPrState prNumber (Just reviewerThread))
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement completion from handoff ready is idempotent" handoffReadyPrefix handoffReadyState (ObservedImplementationCompleted prNumber (Just reviewerThread))
      (IssueImplementIndexed.IssueImplementIndexedState handoffReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationCompleted prNumber (Just reviewerThread)) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueImplementationCompletedEvent prNumber (Just reviewerThread)) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (IssueImplementIndexed.projectIssueImplementationCompletedHandoffReadyObservation handoffReadyState prNumber (Just reviewerThread))
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement completion from handoff initialized is idempotent" handoffInitializedPrefix handoffInitializedState (ObservedImplementationCompleted prNumber (Just reviewerThread))
      (IssueImplementIndexed.IssueImplementIndexedState handoffInitializedState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationCompleted prNumber (Just reviewerThread)) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueImplementationCompletedEvent prNumber (Just reviewerThread)) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (IssueImplementIndexed.projectIssueImplementationCompletedHandoffInitializedObservation handoffInitializedState prNumber (Just reviewerThread))
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement completion while waiting for merge is idempotent" waitingMergeWithReviewerPrefix waitingMergeWithReviewerState (ObservedImplementationCompleted prNumber (Just reviewerThread))
      (IssueImplementIndexed.IssueImplementIndexedState waitingMergeWithReviewerState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationCompleted prNumber (Just reviewerThread)) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueImplementationCompletedEvent prNumber (Just reviewerThread)) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (IssueImplementIndexed.projectIssueImplementationCompletedWaitingForPrMergeObservation waitingMergeWithReviewerState prNumber (Just reviewerThread))
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement stale completion blocks like compatibility" handoffReadyPrefix handoffReadyState (ObservedImplementationCompleted stalePr Nothing)
      (IssueImplementIndexed.IssueImplementIndexedState handoffReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedImplementationCompleted stalePr Nothing) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (IssueImplementationCompletedEvent stalePr Nothing) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementationCompletedHandoffReadyObservation handoffReadyState stalePr Nothing)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement handoff initialization matches compatibility" handoffReadyPrefix handoffReadyState (ObservedReviewHandoffInitialized prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState handoffReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedReviewHandoffInitialized prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueReviewHandoffInitializedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (IssueImplementIndexed.projectIssueImplementReviewHandoffInitializedHandoffReadyObservation handoffReadyState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement handoff initialization from initialized is idempotent" handoffInitializedPrefix handoffInitializedState (ObservedReviewHandoffInitialized prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState handoffInitializedState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedReviewHandoffInitialized prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueReviewHandoffInitializedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (IssueImplementIndexed.projectIssueImplementReviewHandoffInitializedHandoffInitializedObservation handoffInitializedState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement handoff initialization while waiting merge is idempotent" waitingMergeWithReviewerPrefix waitingMergeWithReviewerState (ObservedReviewHandoffInitialized prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState waitingMergeWithReviewerState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedReviewHandoffInitialized prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueReviewHandoffInitializedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (IssueImplementIndexed.projectIssueImplementReviewHandoffInitializedWaitingForPrMergeObservation waitingMergeWithReviewerState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement wrong handoff initialization blocks like compatibility" handoffReadyPrefix handoffReadyState (ObservedReviewHandoffInitialized stalePr)
      (IssueImplementIndexed.IssueImplementIndexedState handoffReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedReviewHandoffInitialized stalePr) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (IssueReviewHandoffInitializedEvent stalePr) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementReviewHandoffInitializedHandoffReadyObservation handoffReadyState stalePr)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement handoff start matches compatibility" handoffInitializedPrefix handoffInitializedState (ObservedReviewHandoffStarted prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState handoffInitializedState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedReviewHandoffStarted prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueReviewHandoffStartedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (IssueImplementIndexed.projectIssueImplementReviewHandoffStartedHandoffInitializedObservation handoffInitializedState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement handoff start while waiting merge is idempotent" waitingMergeWithReviewerPrefix waitingMergeWithReviewerState (ObservedReviewHandoffStarted prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState waitingMergeWithReviewerState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedReviewHandoffStarted prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueReviewHandoffStartedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (IssueImplementIndexed.projectIssueImplementReviewHandoffStartedWaitingForPrMergeObservation waitingMergeWithReviewerState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement wrong handoff start blocks like compatibility" handoffInitializedPrefix handoffInitializedState (ObservedReviewHandoffStarted stalePr)
      (IssueImplementIndexed.IssueImplementIndexedState handoffInitializedState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedReviewHandoffStarted stalePr) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (IssueReviewHandoffStartedEvent stalePr) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementReviewHandoffStartedHandoffInitializedObservation handoffInitializedState stalePr)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement reviewer ready from handoff ready matches compatibility" handoffReadyNoReviewerPrefix handoffReadyNoReviewerState (ObservedIssueReviewerThreadReady reviewerThread)
      (IssueImplementIndexed.IssueImplementIndexedState handoffReadyNoReviewerState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueReviewerThreadReady reviewerThread) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueReviewerThreadReadyEvent reviewerThread) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (IssueImplementIndexed.projectIssueImplementReviewerThreadReadyHandoffReadyObservation handoffReadyNoReviewerState reviewerThread)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement reviewer ready from handoff initialized matches compatibility" handoffInitializedNoReviewerPrefix handoffInitializedNoReviewerState (ObservedIssueReviewerThreadReady reviewerThread)
      (IssueImplementIndexed.IssueImplementIndexedState handoffInitializedNoReviewerState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueReviewerThreadReady reviewerThread) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueReviewerThreadReadyEvent reviewerThread) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (IssueImplementIndexed.projectIssueImplementReviewerThreadReadyHandoffInitializedObservation handoffInitializedNoReviewerState reviewerThread)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement reviewer ready while waiting merge matches compatibility" waitingMergePrefix waitingMergeState (ObservedIssueReviewerThreadReady reviewerThread)
      (IssueImplementIndexed.IssueImplementIndexedState waitingMergeState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueReviewerThreadReady reviewerThread) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueReviewerThreadReadyEvent reviewerThread) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (IssueImplementIndexed.projectIssueImplementReviewerThreadReadyWaitingForPrMergeObservation waitingMergeState reviewerThread)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement reviewer ready from post-merge pending enters ready" postMergePendingPrefix postMergePendingState (ObservedIssueReviewerThreadReady reviewerThread)
      (IssueImplementIndexed.IssueImplementIndexedState postMergePendingState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueReviewerThreadReady reviewerThread) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueReviewerThreadReadyEvent reviewerThread) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (IssueImplementIndexed.projectIssueImplementReviewerThreadReadyPostMergeReviewPendingReviewerObservation postMergePendingState reviewerThread)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement reviewer ready from post-merge ready refreshes reviewer" postMergeReadyPrefix postMergeReadyState (ObservedIssueReviewerThreadReady refreshedReviewer)
      (IssueImplementIndexed.IssueImplementIndexedState postMergeReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueReviewerThreadReady refreshedReviewer) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssueReviewerThreadReadyEvent refreshedReviewer) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (IssueImplementIndexed.projectIssueImplementReviewerThreadReadyPostMergeReviewReadyObservation postMergeReadyState refreshedReviewer)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement pull request merge without reviewer enters pending review" waitingMergeNoReviewerPrefix waitingMergeState (ObservedPullRequestMerged prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState waitingMergeState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestMergedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer)
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedWaitingForPrMergeObservation waitingMergeState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement pull request merge enters post-merge review" waitingMergeWithReviewerPrefix waitingMergeWithReviewerState (ObservedPullRequestMerged prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState waitingMergeWithReviewerState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestMergedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedWaitingForPrMergeObservation waitingMergeWithReviewerState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement ignored merged PR while implementation-ready sleeps" implementationReadyPrPrefix implementationReadyPrState (ObservedPullRequestMerged prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState implementationReadyPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestMergedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedImplementationReadyObservation implementationReadyPrState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement ignored merged PR while implementing sleeps" implementingPrPrefix implementingPrState (ObservedPullRequestMerged prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState implementingPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementing)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedImplementing)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestMergedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedImplementing)
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedImplementingObservation implementingPrState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement ignored merged PR from handoff ready sleeps" handoffReadyPrefix handoffReadyState (ObservedPullRequestMerged prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState handoffReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestMergedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedHandoffReadyObservation handoffReadyState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement ignored merged PR from handoff initialized sleeps" handoffInitializedPrefix handoffInitializedState (ObservedPullRequestMerged prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState handoffInitializedState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestMergedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedHandoffInitializedObservation handoffInitializedState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement ignored merged PR from post-merge pending sleeps" postMergePendingPrefix postMergePendingState (ObservedPullRequestMerged prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState postMergePendingState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestMergedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer)
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedPostMergeReviewPendingReviewerObservation postMergePendingState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement ignored merged PR from post-merge ready sleeps" postMergeReadyPrefix postMergeReadyState (ObservedPullRequestMerged prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState postMergeReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestMergedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedPostMergeReviewReadyObservation postMergeReadyState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement ignored merged PR from post-merge reviewing sleeps" postMergeReviewingPrefix postMergeReviewingState (ObservedPullRequestMerged prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState postMergeReviewingState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestMergedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing)
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedPostMergeReviewingObservation postMergeReviewingState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement ignored merged PR while waiting for issue close sleeps" waitingClosePrefix waitingCloseState (ObservedPullRequestMerged prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState waitingCloseState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePullRequestMergedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose)
      (IssueImplementIndexed.projectIssueImplementPullRequestMergedWaitingForIssueCloseObservation waitingCloseState prNumber)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement post-merge review start matches compatibility" postMergeReadyPrefix postMergeReadyState (ObservedPostMergeReviewStarted reviewedCommit finalReviewTurn)
      (IssueImplementIndexed.IssueImplementIndexedState postMergeReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPostMergeReviewStarted reviewedCommit finalReviewTurn) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePostMergeReviewStartedEvent reviewedCommit finalReviewTurn) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing)
      (IssueImplementIndexed.projectIssueImplementPostMergeReviewStartedObservation postMergeReadyState reviewedCommit finalReviewTurn)
      [StartIssueFinalReviewTurnTag]
  , c "indexed workflow issue implement clean final review closes issue" postMergeReviewingPrefix postMergeReviewingState (ObservedPostMergeReviewerOutcome (IssueFinalReviewClean cleanEvidence))
      (IssueImplementIndexed.IssueImplementIndexedState postMergeReviewingState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPostMergeReviewerOutcome (IssueFinalReviewClean cleanEvidence)) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePostMergeReviewCleanEvent cleanEvidence) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose)
      (IssueImplementIndexed.projectIssueImplementPostMergeReviewerOutcomeCleanObservation postMergeReviewingState cleanEvidence)
      [CloseIssueTag, SleepUntilNextPollTag]
  , c "indexed workflow issue implement rework final review starts follow-up" postMergeReviewingPrefix postMergeReviewingState (ObservedPostMergeReviewerOutcome (IssueFinalReviewRework reviewEvidence))
      (IssueImplementIndexed.IssueImplementIndexedState postMergeReviewingState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPostMergeReviewerOutcome (IssueFinalReviewRework reviewEvidence)) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePostMergeReviewFollowUpEvent reviewEvidence) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (IssueImplementIndexed.projectIssueImplementPostMergeReviewerOutcomeReworkObservation postMergeReviewingState reviewEvidence)
      [UpdateIssueFollowUpTag, SleepUntilNextPollTag]
  , c "indexed workflow issue implement incomplete final review retries" postMergeReviewingPrefix postMergeReviewingState (ObservedPostMergeReviewerOutcome (IssueFinalReviewIncomplete incompleteReason))
      (IssueImplementIndexed.IssueImplementIndexedState postMergeReviewingState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing)
      (obs "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPostMergeReviewerOutcome (IssueFinalReviewIncomplete incompleteReason)) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (ev "IssueImplement/Implementing" "IssueImplement/Implementing" (IssuePostMergeReviewIncompleteEvent incompleteReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (IssueImplementIndexed.projectIssueImplementPostMergeReviewerOutcomeIncompleteObservation postMergeReviewingState incompleteReason)
      [SleepUntilNextPollTag]
  , c "indexed workflow issue implement blocked final review stops" postMergeReviewingPrefix postMergeReviewingState (ObservedPostMergeReviewerOutcome (IssueFinalReviewBlocked blockedReason))
      (IssueImplementIndexed.IssueImplementIndexedState postMergeReviewingState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedPostMergeReviewerOutcome (IssueFinalReviewBlocked blockedReason)) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementPostMergeReviewerOutcomeBlockedObservation postMergeReviewingState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement issue close completes" waitingClosePrefix waitingCloseState (ObservedIssueClosed prNumber)
      (IssueImplementIndexed.IssueImplementIndexedState waitingCloseState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose)
      (obs "IssueImplement/Implementing" "IssueImplement/Complete" (ObservedIssueClosed prNumber) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose IssueImplementIndexed.IssueImplementIndexedComplete)
      (ev "IssueImplement/Implementing" "IssueImplement/Complete" (IssueClosedEvent prNumber) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose IssueImplementIndexed.IssueImplementIndexedComplete)
      (IssueImplementIndexed.projectIssueImplementIssueClosedObservation waitingCloseState prNumber)
      [StopDaemonTag]
  , c "indexed workflow issue implement wrong issue close blocks like compatibility" waitingClosePrefix waitingCloseState (ObservedIssueClosed stalePr)
      (IssueImplementIndexed.IssueImplementIndexedState waitingCloseState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedIssueClosed stalePr) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (IssueClosedEvent stalePr) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementIssueClosedObservation waitingCloseState stalePr)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement generic blocked works from ready to plan" readyToPlanPrefix readyToPlanState (ObservedIssueImplementBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState readyToPlanState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedReadyToPlan)
      (obs "IssueImplement/PlanMode" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedReadyToPlan IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/PlanMode" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedReadyToPlan IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementBlockedReadyToPlanObservation readyToPlanState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement generic blocked works from plan mode" inPlanModePrefix inPlanModeState (ObservedIssueImplementBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState inPlanModeState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedInPlanMode)
      (obs "IssueImplement/PlanMode" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedInPlanMode IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/PlanMode" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedInPlanMode IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementBlockedInPlanModeObservation inPlanModeState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement generic blocked works from plan ready" planReadyPrefix planReadyState (ObservedIssueImplementBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState planReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPlanReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPlanReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPlanReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementBlockedPlanReadyObservation planReadyState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement generic blocked works from implementation ready" implementationReadyPrPrefix implementationReadyPrState (ObservedIssueImplementBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState implementationReadyPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementationReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementationReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementBlockedImplementationReadyObservation implementationReadyPrState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement generic blocked works from implementing" implementingPrPrefix implementingPrState (ObservedIssueImplementBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState implementingPrState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedImplementing)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedImplementing IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementBlockedImplementingObservation implementingPrState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement generic blocked works from handoff ready" handoffReadyPrefix handoffReadyState (ObservedIssueImplementBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState handoffReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementBlockedHandoffReadyObservation handoffReadyState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement generic blocked works from handoff initialized" handoffInitializedPrefix handoffInitializedState (ObservedIssueImplementBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState handoffInitializedState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedHandoffInitialized)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedHandoffInitialized IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementBlockedHandoffInitializedObservation handoffInitializedState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement generic blocked works from waiting merge" waitingMergeWithReviewerPrefix waitingMergeWithReviewerState (ObservedIssueImplementBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState waitingMergeWithReviewerState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedWaitingForPrMerge IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementBlockedWaitingForPrMergeObservation waitingMergeWithReviewerState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement generic blocked works from post-merge pending" postMergePendingPrefix postMergePendingState (ObservedIssueImplementBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState postMergePendingState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewPendingReviewer IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementBlockedPostMergeReviewPendingReviewerObservation postMergePendingState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement generic blocked works from post-merge ready" postMergeReadyPrefix postMergeReadyState (ObservedIssueImplementBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState postMergeReadyState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewReady IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementBlockedPostMergeReviewReadyObservation postMergeReadyState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement generic blocked works from post-merge reviewing" postMergeReviewingPrefix postMergeReviewingState (ObservedIssueImplementBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState postMergeReviewingState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedPostMergeReviewing IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementBlockedPostMergeReviewingObservation postMergeReviewingState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  , c "indexed workflow issue implement generic blocked works from waiting close" waitingClosePrefix waitingCloseState (ObservedIssueImplementBlocked blockedReason)
      (IssueImplementIndexed.IssueImplementIndexedState waitingCloseState :: IssueImplementIndexed.IssueImplementIndexedState IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose)
      (obs "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedIssueImplementBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedObservation IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose IssueImplementIndexed.IssueImplementIndexedBlocked)
      (ev "IssueImplement/Implementing" "IssueImplement/Blocked" (WatcherBlocked blockedReason) :: IssueImplementIndexed.IssueImplementIndexedEvent IssueImplementIndexed.IssueImplementIndexedWaitingForIssueClose IssueImplementIndexed.IssueImplementIndexedBlocked)
      (IssueImplementIndexed.projectIssueImplementBlockedWaitingForIssueCloseObservation waitingCloseState blockedReason)
      [RecordBlockedTag, StopDaemonTag]
  ]
 where
  c = IssueImplementIndexedPolicyCase
  obs = issueImplementIndexedObservation
  ev = IssueImplementIndexed.IssueImplementIndexedEvent
  issueConfig = issueImplementIndexedConfig
  prNumber = PrNumber 7
  stalePr = PrNumber 8
  workerThread = ThreadId "worker-thread"
  refreshedWorker = ThreadId "worker-thread-refreshed"
  reviewerThread = ThreadId "reviewer-thread"
  refreshedReviewer = ThreadId "reviewer-thread-refreshed"
  planTurn = TurnId "turn-plan"
  implementationTurn = TurnId "turn-impl"
  finalReviewTurn = TurnId "turn-final-review"
  reviewedCommit = CommitSha "0123456789abcdef"
  followUpBranch = BranchName "codex/issue-42-2"
  incompleteReason = "incomplete"
  blockedReason = BlockedReason "blocked"
  cleanEvidence = CleanReviewEvidence reviewedCommit "LGTM"
  reviewEvidence = reviewEvidenceFromSummaries ("needs follow-up" :| []) reviewedCommit
  readyToPlanPrefix =
    [ IssueImplementInitialized issueConfig workerThread
    , IssuePullRequestReusedEvent prNumber
    ]
  inPlanModePrefix = readyToPlanPrefix <> [IssuePlanTurnStartedEvent planTurn]
  planReadyPrefix = inPlanModePrefix <> [IssuePlanCompletedEvent sampleIssuePlanMarkdown (Just implementationTurn)]
  implementationReadyPrPrefix = planReadyPrefix <> [IssuePullRequestBodyUpdatedEvent prNumber]
  implementationReadyNoPrPrefix = [IssueImplementInitialized issueConfig workerThread]
  implementingPrPrefix = implementationReadyPrPrefix <> [IssueImplementationTurnStartedEvent implementationTurn]
  implementingNoPrPrefix = implementationReadyNoPrPrefix <> [IssueImplementationTurnStartedEvent implementationTurn]
  handoffReadyPrefix = implementingPrPrefix <> [IssueImplementationCompletedEvent prNumber (Just reviewerThread)]
  handoffReadyNoReviewerPrefix = implementingPrPrefix <> [IssueImplementationCompletedEvent prNumber Nothing]
  handoffInitializedPrefix = handoffReadyPrefix <> [IssueReviewHandoffInitializedEvent prNumber]
  handoffInitializedNoReviewerPrefix = handoffReadyNoReviewerPrefix <> [IssueReviewHandoffInitializedEvent prNumber]
  waitingMergePrefix = handoffInitializedPrefix <> [IssueReviewHandoffStartedEvent prNumber]
  waitingMergeNoReviewerPrefix = handoffInitializedNoReviewerPrefix <> [IssueReviewHandoffStartedEvent prNumber]
  waitingMergeWithReviewerPrefix = waitingMergePrefix
  postMergePendingPrefix = waitingMergeNoReviewerPrefix <> [IssuePullRequestMergedEvent prNumber]
  postMergeReadyPrefix = waitingMergeWithReviewerPrefix <> [IssuePullRequestMergedEvent prNumber]
  postMergeReviewingPrefix = postMergeReadyPrefix <> [IssuePostMergeReviewStartedEvent reviewedCommit finalReviewTurn]
  waitingClosePrefix = postMergeReviewingPrefix <> [IssuePostMergeReviewCleanEvent cleanEvidence]
  readyToPlanState =
    SomeWatcherState (IssueReadyToPlan issueConfig prNumber (WorkerIdle workerThread))
  inPlanModeState =
    SomeWatcherState (IssueInPlanMode issueConfig prNumber (WorkerActive (ActiveTurn workerThread planTurn)))
  planReadyState =
    SomeWatcherState (IssuePlanReady issueConfig prNumber (WorkerIdle workerThread))
  implementationReadyPrState =
    SomeWatcherState (IssueImplementationReady issueConfig (Just prNumber) (WorkerIdle workerThread))
  implementationReadyNoPrState =
    SomeWatcherState (IssueImplementationReady issueConfig Nothing (WorkerIdle workerThread))
  implementingPrState =
    SomeWatcherState (IssueImplementing issueConfig (Just prNumber) (WorkerActive (ActiveTurn workerThread implementationTurn)))
  implementingNoPrState =
    SomeWatcherState (IssueImplementing issueConfig Nothing (WorkerActive (ActiveTurn workerThread implementationTurn)))
  handoffReadyState =
    SomeWatcherState (IssueHandoffReady issueConfig prNumber (WorkerIdle workerThread) (Just (ReviewerIdle reviewerThread)))
  handoffReadyNoReviewerState =
    SomeWatcherState (IssueHandoffReady issueConfig prNumber (WorkerIdle workerThread) Nothing)
  handoffInitializedState =
    SomeWatcherState (IssueHandoffInitialized issueConfig prNumber (WorkerIdle workerThread) (Just (ReviewerIdle reviewerThread)))
  handoffInitializedNoReviewerState =
    SomeWatcherState (IssueHandoffInitialized issueConfig prNumber (WorkerIdle workerThread) Nothing)
  waitingMergeState =
    SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber (WorkerIdle workerThread) Nothing)
  waitingMergeWithReviewerState =
    SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber (WorkerIdle workerThread) (Just (ReviewerIdle reviewerThread)))
  postMergePendingState =
    SomeWatcherState (IssuePostMergeReviewPendingReviewer issueConfig prNumber (WorkerIdle workerThread))
  postMergeReadyState =
    SomeWatcherState (IssuePostMergeReviewReady issueConfig prNumber (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
  postMergeReviewingState =
    SomeWatcherState (IssuePostMergeReviewing issueConfig prNumber (WorkerIdle workerThread) reviewedCommit (ReviewerActive (ActiveTurn reviewerThread finalReviewTurn)))
  waitingCloseState =
    SomeWatcherState (IssueWaitingForIssueClose issueConfig prNumber)

workflowPrReviewCheckingIndexedSpecMatchesCompatibilityForReviewThreads :: IO Bool
workflowPrReviewCheckingIndexedSpecMatchesCompatibilityForReviewThreads = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      commit = CommitSha "abc123"
      workerTurn = TurnId "worker-turn"
      reviewerTurn = TurnId "reviewer-turn"
      initialized = PrReviewInitialized prConfig workerThread reviewerThread
      initializedIndexed =
        IndexedWorkflow.SomeIndexedWorkflowEvent
          ( PrReviewCheckingIndexedEvent "PrReview/Uninitialized" "PrReview/CheckingReviews" initialized
              :: PrReviewCheckingIndexedEvent PrReviewCheckingIndexedUninitialized PrReviewCheckingIndexedCheckingReviews
          )
      checkingState =
        SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      indexedState =
        PrReviewCheckingIndexedState checkingState
          :: PrReviewCheckingIndexedState PrReviewCheckingIndexedCheckingReviews
      reviewThreadId = ReviewThreadId "thread-1"
      unresolvedReport = reviewThreadsReport [reviewThreadId]
      cleanReport = reviewThreadsReport []
      unresolvedEvent = PrReviewUnresolvedFound (reviewThreadId :| []) commit workerTurn
      cleanEvent = PrReviewNoUnresolvedFound commit reviewerTurn
  results <-
    sequence
      [ prReviewCheckingIndexedSpecMatchesCompatibility
          "indexed workflow PR-review checking unresolved threads match compatibility"
          checkingState
          (WorkflowPrReview.CheckingObservedReviewThreads unresolvedReport commit workerTurn)
          (DaemonPrReviewObservation (ObservedReviewThreads unresolvedReport commit workerTurn))
          indexedState
          ( PrReviewCheckingIndexedObservation
              "PrReview/CheckingReviews"
              "PrReview/FixingReviews"
              (DaemonPrReviewObservation (ObservedReviewThreads unresolvedReport commit workerTurn))
              :: PrReviewCheckingIndexedObservation PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedFixingReviews
          )
          unresolvedEvent
          [initialized]
          [initializedIndexed]
          ( PrReviewCheckingIndexedEvent "PrReview/CheckingReviews" "PrReview/FixingReviews" unresolvedEvent
              :: PrReviewCheckingIndexedEvent PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedFixingReviews
          )
      , prReviewCheckingIndexedSpecMatchesCompatibility
          "indexed workflow PR-review checking clean threads match compatibility"
          checkingState
          (WorkflowPrReview.CheckingObservedReviewThreads cleanReport commit reviewerTurn)
          (DaemonPrReviewObservation (ObservedReviewThreads cleanReport commit reviewerTurn))
          indexedState
          ( PrReviewCheckingIndexedObservation
              "PrReview/CheckingReviews"
              "PrReview/ReviewingClean"
              (DaemonPrReviewObservation (ObservedReviewThreads cleanReport commit reviewerTurn))
              :: PrReviewCheckingIndexedObservation PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedReviewingClean
          )
          cleanEvent
          [initialized]
          [initializedIndexed]
          ( PrReviewCheckingIndexedEvent "PrReview/CheckingReviews" "PrReview/ReviewingClean" cleanEvent
              :: PrReviewCheckingIndexedEvent PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedReviewingClean
          )
      ]
  pure (and results)

workflowPrReviewCheckingIndexedSpecMatchesCompatibilityForFeedbackSources :: IO Bool
workflowPrReviewCheckingIndexedSpecMatchesCompatibilityForFeedbackSources = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      commit = CommitSha "abc123"
      firstTurn = TurnId "worker-turn-1"
      secondTurn = TurnId "worker-turn-2"
      initialized = PrReviewInitialized prConfig workerThread reviewerThread
      initializedIndexed =
        IndexedWorkflow.SomeIndexedWorkflowEvent
          ( PrReviewCheckingIndexedEvent "PrReview/Uninitialized" "PrReview/CheckingReviews" initialized
              :: PrReviewCheckingIndexedEvent PrReviewCheckingIndexedUninitialized PrReviewCheckingIndexedCheckingReviews
          )
      queuedEvidence = reviewEvidenceFromSummaries ("queued review feedback" :| []) commit
      feedbackEvidence = reviewEvidenceFromSummaries ("new review feedback" :| []) commit
      checkingEvent = PrReviewFeedbackFound feedbackEvidence secondTurn
      queuedPrefix = [initialized, PrReviewFeedbackFound queuedEvidence firstTurn, PrReviewFixIncomplete "worker needs more time"]
      queuedIndexedPrefix =
        [ initializedIndexed
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewCheckingIndexedEvent "PrReview/CheckingReviews" "PrReview/FixingReviews" (PrReviewFeedbackFound queuedEvidence firstTurn)
                :: PrReviewCheckingIndexedEvent PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedFixingReviews
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewCheckingIndexedEvent "PrReview/FixingReviews" "PrReview/CheckingReviews" (PrReviewFixIncomplete "worker needs more time")
                :: PrReviewCheckingIndexedEvent PrReviewCheckingIndexedFixingReviews PrReviewCheckingIndexedCheckingReviews
            )
        ]
      checkingState =
        SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      queuedState =
        SomeWatcherState (PrReviewFixQueued prConfig queuedEvidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      checkingObservation =
        PrReviewCheckingIndexedObservation
          "PrReview/CheckingReviews"
          "PrReview/FixingReviews"
          (DaemonPrReviewObservation (ObservedReviewFeedback feedbackEvidence secondTurn))
          :: PrReviewCheckingIndexedObservation PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedFixingReviews
      checkingIndexedEvent =
        PrReviewCheckingIndexedEvent "PrReview/CheckingReviews" "PrReview/FixingReviews" checkingEvent
          :: PrReviewCheckingIndexedEvent PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedFixingReviews
  verifyingLoaded <- loadPrReviewCheckingVerificationGoldenSlice
  feedbackFromChecking <-
    prReviewCheckingIndexedSpecMatchesCompatibility
      "indexed workflow PR-review feedback from checking matches compatibility"
      checkingState
      (WorkflowPrReview.CheckingObservedReviewFeedback feedbackEvidence secondTurn)
      (DaemonPrReviewObservation (ObservedReviewFeedback feedbackEvidence secondTurn))
      (PrReviewCheckingIndexedState checkingState :: PrReviewCheckingIndexedState PrReviewCheckingIndexedCheckingReviews)
      checkingObservation
      checkingEvent
      [initialized]
      [initializedIndexed]
      checkingIndexedEvent
  feedbackFromQueued <-
    prReviewCheckingIndexedSpecMatchesCompatibility
      "indexed workflow PR-review feedback from queued fix matches compatibility"
      queuedState
      (WorkflowPrReview.CheckingObservedReviewFeedback feedbackEvidence secondTurn)
      (DaemonPrReviewObservation (ObservedReviewFeedback feedbackEvidence secondTurn))
      (PrReviewCheckingIndexedState queuedState :: PrReviewCheckingIndexedState PrReviewCheckingIndexedCheckingReviews)
      checkingObservation
      checkingEvent
      queuedPrefix
      queuedIndexedPrefix
      checkingIndexedEvent
  feedbackFromVerifying <-
    case verifyingLoaded of
      Left failure -> assert "indexed workflow PR-review verification golden lifecycle loads for feedback" False <* putStrLn ("FAIL golden lifecycle: " <> failure)
      Right slice ->
        let event = PrReviewFeedbackFound feedbackEvidence secondTurn
            indexedEvent =
              PrReviewCheckingIndexedEvent "PrReview/CheckingReviews" "PrReview/FixingReviews" event
                :: PrReviewCheckingIndexedEvent PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedFixingReviews
         in prReviewCheckingIndexedSpecMatchesCompatibility
              "indexed workflow PR-review feedback from verification checking matches compatibility"
              slice.prReviewCheckingVerificationState
              (WorkflowPrReview.CheckingObservedReviewFeedback feedbackEvidence secondTurn)
              (DaemonPrReviewObservation (ObservedReviewFeedback feedbackEvidence secondTurn))
              (PrReviewCheckingIndexedState slice.prReviewCheckingVerificationState :: PrReviewCheckingIndexedState PrReviewCheckingIndexedCheckingReviews)
              checkingObservation
              event
              slice.prReviewCheckingVerificationPrefix
              slice.prReviewCheckingVerificationIndexedPrefix
              indexedEvent
  pure (feedbackFromChecking && feedbackFromQueued && feedbackFromVerifying)

data PrReviewCheckingVerificationGoldenSlice = PrReviewCheckingVerificationGoldenSlice
  { prReviewCheckingVerificationPrefix :: [WatcherEvent]
  , prReviewCheckingVerificationIndexedPrefix :: [IndexedWorkflow.SomeIndexedWorkflowEvent PrReviewCheckingIndexedSpec]
  , prReviewCheckingVerificationState :: SomeWatcherState
  , prReviewCheckingVerificationEvidence :: ReviewEvidence
  , prReviewCheckingVerificationTarget :: CommitSha
  , prReviewCheckingVerificationTurn :: TurnId
  }

loadPrReviewCheckingVerificationGoldenSlice :: IO (Either String PrReviewCheckingVerificationGoldenSlice)
loadPrReviewCheckingVerificationGoldenSlice = do
  loaded <- loadEventLogFile "golden/event-log/pr-review/mlf2-pr6-merged/events.jsonl"
  pure $ do
    events <- loaded
    case events of
      [ initialized@PrReviewInitialized {}
        , unresolved@PrReviewUnresolvedFound {}
        , fixCompleted@PrReviewFixCompleted
        , PrReviewFixVerificationStarted evidence reviewTarget turnId
        , _cleanFoundBeforeFinalCheck
        , _noUnresolved
        , _cleanFound
        , _mergeability
        , _merged
        ] -> do
          let prefix = [initialized, unresolved, fixCompleted]
          replay <-
            case workflowReplayEvents @MoifoldSpec prefix of
              Right replayResult -> Right replayResult
              Left failure -> Left (Text.unpack failure)
          case replay.replayState of
            SomeWatcherState (PrVerifyingReviewFix {}) ->
              Right
                PrReviewCheckingVerificationGoldenSlice
                  { prReviewCheckingVerificationPrefix = prefix
                  , prReviewCheckingVerificationIndexedPrefix =
                      [ IndexedWorkflow.SomeIndexedWorkflowEvent
                          ( PrReviewCheckingIndexedEvent "PrReview/Uninitialized" "PrReview/CheckingReviews" initialized
                              :: PrReviewCheckingIndexedEvent PrReviewCheckingIndexedUninitialized PrReviewCheckingIndexedCheckingReviews
                          )
                      , IndexedWorkflow.SomeIndexedWorkflowEvent
                          ( PrReviewCheckingIndexedEvent "PrReview/CheckingReviews" "PrReview/FixingReviews" unresolved
                              :: PrReviewCheckingIndexedEvent PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedFixingReviews
                          )
                      , IndexedWorkflow.SomeIndexedWorkflowEvent
                          ( PrReviewCheckingIndexedEvent "PrReview/FixingReviews" "PrReview/CheckingReviews" fixCompleted
                              :: PrReviewCheckingIndexedEvent PrReviewCheckingIndexedFixingReviews PrReviewCheckingIndexedCheckingReviews
                          )
                      ]
                  , prReviewCheckingVerificationState = replay.replayState
                  , prReviewCheckingVerificationEvidence = evidence
                  , prReviewCheckingVerificationTarget = reviewTarget
                  , prReviewCheckingVerificationTurn = turnId
                  }
            _ -> Left "golden PR-review lifecycle prefix does not replay to PrVerifyingReviewFix"
      _ -> Left "golden PR-review lifecycle shape changed before review-fix verification"

workflowPrReviewCheckingIndexedSpecMatchesCompatibilityForVerificationStart :: IO Bool
workflowPrReviewCheckingIndexedSpecMatchesCompatibilityForVerificationStart = do
  loaded <- loadPrReviewCheckingVerificationGoldenSlice
  case loaded of
    Left failure -> assert "indexed workflow PR-review verification golden lifecycle loads" False <* putStrLn ("FAIL golden lifecycle: " <> failure)
    Right slice -> do
      let event =
            PrReviewFixVerificationStarted
              slice.prReviewCheckingVerificationEvidence
              slice.prReviewCheckingVerificationTarget
              slice.prReviewCheckingVerificationTurn
          observation =
            DaemonPrReviewObservation
              (ObservedReviewFixVerificationStarted slice.prReviewCheckingVerificationTarget slice.prReviewCheckingVerificationTurn)
          indexedObservation =
            PrReviewCheckingIndexedObservation "PrReview/CheckingReviews" "PrReview/ReviewingClean" observation
              :: PrReviewCheckingIndexedObservation PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedReviewingClean
          indexedEvent =
            PrReviewCheckingIndexedEvent "PrReview/CheckingReviews" "PrReview/ReviewingClean" event
              :: PrReviewCheckingIndexedEvent PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedReviewingClean
      prReviewCheckingIndexedSpecMatchesCompatibility
        "indexed workflow PR-review verification start matches compatibility from golden lifecycle"
        slice.prReviewCheckingVerificationState
        ( WorkflowPrReview.CheckingObservedReviewFixVerificationStarted
            slice.prReviewCheckingVerificationTarget
            slice.prReviewCheckingVerificationTurn
        )
        observation
        (PrReviewCheckingIndexedState slice.prReviewCheckingVerificationState :: PrReviewCheckingIndexedState PrReviewCheckingIndexedCheckingReviews)
        indexedObservation
        event
        slice.prReviewCheckingVerificationPrefix
        slice.prReviewCheckingVerificationIndexedPrefix
        indexedEvent

workflowPrReviewCheckingIndexedSpecRejectsInvalidObservationLikeFacade :: IO Bool
workflowPrReviewCheckingIndexedSpecRejectsInvalidObservationLikeFacade = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      commit = CommitSha "abc123"
      cleanEvidence = CleanReviewEvidence commit "LGTM"
      feedbackEvidence = reviewEvidenceFromSummaries ("new review feedback" :| []) commit
      turnId = TurnId "worker-turn"
      state =
        SomeWatcherState
          (PrWaitingForMergeability prConfig cleanEvidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      daemonObservation = DaemonPrReviewObservation (ObservedReviewFeedback feedbackEvidence turnId)
      indexedState =
        PrReviewCheckingIndexedState state
          :: PrReviewCheckingIndexedState PrReviewCheckingIndexedCheckingReviews
      indexedObservation =
        PrReviewCheckingIndexedObservation "PrReview/CheckingReviews" "PrReview/FixingReviews" daemonObservation
          :: PrReviewCheckingIndexedObservation PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedFixingReviews
  assert "indexed workflow PR-review checking rejects invalid observation like facade" $
    case
      ( WorkflowPrReview.observePrReviewChecking state (WorkflowPrReview.CheckingObservedReviewFeedback feedbackEvidence turnId)
      , workflowObserve @MoifoldSpec state daemonObservation
      , workflowPlanObservation @MoifoldSpec state daemonObservation
      , IndexedWorkflow.indexedWorkflowObserve @PrReviewCheckingIndexedSpec indexedState indexedObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @PrReviewCheckingIndexedSpec indexedState indexedObservation
      )
      of
      (Left facadeFailure, Left compatibilityFailure, Left compatibilityPlanFailure, Left indexedFailure, Left indexedPlanFailure) ->
        compatibilityFailure == facadeFailure
          && compatibilityPlanFailure == facadeFailure
          && indexedFailure == facadeFailure
          && indexedPlanFailure == facadeFailure
      _ -> False

workflowPrReviewCheckingIndexedSpecPreservesTerminalAndPermissionLaws :: IO Bool
workflowPrReviewCheckingIndexedSpecPreservesTerminalAndPermissionLaws = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      commit = CommitSha "abc123"
      evidence = reviewEvidenceFromSummaries ("fix review" :| []) commit
      cleanEvidence = CleanReviewEvidence commit "LGTM"
      checkingState =
        SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      wrongPhaseState =
        SomeWatcherState (PrWaitingForMergeability prConfig cleanEvidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      blockedState =
        SomeWatcherState (BlockedState (BlockedReason "review blocked") :: WatcherState 'PrReview 'Blocked)
      completeState =
        SomeWatcherState (CompleteState (PrMerged (MergeCommit (CommitSha "def456"))) :: WatcherState 'PrReview 'Complete)
      checkingIndexedState =
        PrReviewCheckingIndexedState checkingState
          :: PrReviewCheckingIndexedState PrReviewCheckingIndexedCheckingReviews
      wrongPhaseIndexedState =
        PrReviewCheckingIndexedState wrongPhaseState
          :: PrReviewCheckingIndexedState PrReviewCheckingIndexedCheckingReviews
      blockedIndexedState =
        PrReviewCheckingIndexedState blockedState
          :: PrReviewCheckingIndexedState PrReviewCheckingIndexedCheckingReviews
      completeIndexedState =
        PrReviewCheckingIndexedState completeState
          :: PrReviewCheckingIndexedState PrReviewCheckingIndexedCheckingReviews
      checkingEffects = [SomeEffect (StartWorkerTurn evidence workerThread)]
      wrongPhasePlan =
        PrReviewCheckingIndexedEffectPlan checkingEffects
          :: PrReviewCheckingIndexedEffectPlan PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedFixingReviews
      wrongPhaseEffect =
        PrReviewCheckingIndexedEffect (SomeEffect (StartWorkerTurn evidence workerThread))
          :: PrReviewCheckingIndexedEffect PrReviewCheckingIndexedCheckingReviews PrReviewCheckingIndexedFixingReviews
  results <-
    sequence
      [ assert "indexed workflow PR-review checking terminal law delegates to compatibility state" $
          not (workflowIsTerminal @MoifoldSpec checkingState)
            && not (IndexedWorkflow.indexedWorkflowIsTerminal @PrReviewCheckingIndexedSpec checkingIndexedState)
            && workflowIsTerminal @MoifoldSpec blockedState
            && IndexedWorkflow.indexedWorkflowIsTerminal @PrReviewCheckingIndexedSpec blockedIndexedState
            && workflowIsTerminal @MoifoldSpec completeState
            && IndexedWorkflow.indexedWorkflowIsTerminal @PrReviewCheckingIndexedSpec completeIndexedState
      , assert "indexed workflow PR-review checking permission rejects wrong phase like compatibility" $
          case
            ( workflowValidateEffects @MoifoldSpec wrongPhaseState checkingEffects
            , IndexedWorkflow.indexedWorkflowValidateEffects @PrReviewCheckingIndexedSpec wrongPhaseIndexedState wrongPhasePlan
            , workflowEffectAllowed @MoifoldSpec wrongPhaseState (SomeEffect (StartWorkerTurn evidence workerThread))
            , IndexedWorkflow.indexedWorkflowEffectAllowed @PrReviewCheckingIndexedSpec wrongPhaseIndexedState wrongPhaseEffect
            , WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec wrongPhaseState checkingEffects
            )
            of
            (Left compatibilityPlanError, Left indexedPlanError, Left compatibilityEffectError, Left indexedEffectError, Left coreError) ->
              indexedPlanError == compatibilityPlanError
                && indexedEffectError == compatibilityEffectError
                && coreError.workflowPermissionEffectLabel == "StartWorkerTurn"
                && "effect is not allowed" `Text.isInfixOf` coreError.workflowPermissionReason
            _ -> False
      ]
  pure (and results)

prReviewCheckingIndexedSpecMatchesCompatibility
  :: forall (source :: Type) (target :: Type).
     String
  -> SomeWatcherState
  -> WorkflowPrReview.PrReviewCheckingObservation
  -> DaemonObservation
  -> PrReviewCheckingIndexedState source
  -> PrReviewCheckingIndexedObservation source target
  -> WatcherEvent
  -> [WatcherEvent]
  -> [IndexedWorkflow.SomeIndexedWorkflowEvent PrReviewCheckingIndexedSpec]
  -> PrReviewCheckingIndexedEvent source target
  -> IO Bool
prReviewCheckingIndexedSpecMatchesCompatibility title state facadeObservation observation indexedState indexedObservation expectedEvent replayPrefix indexedReplayPrefix indexedEvent =
  assert title $
    case
      ( WorkflowPrReview.observePrReviewChecking state facadeObservation
      , workflowObserve @MoifoldSpec state observation
      , workflowPlanObservation @MoifoldSpec state observation
      , IndexedWorkflow.indexedWorkflowObserve @PrReviewCheckingIndexedSpec indexedState indexedObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @PrReviewCheckingIndexedSpec indexedState indexedObservation
      , workflowApplyEvent @MoifoldSpec state expectedEvent
      , IndexedWorkflow.indexedWorkflowApplyEvent @PrReviewCheckingIndexedSpec indexedState indexedEvent
      , workflowReplayEvents @MoifoldSpec (replayPrefix <> [expectedEvent])
      , workflowReplayEvents @MoifoldSpec (replayPrefix <> [expectedEvent])
      , IndexedWorkflow.indexedWorkflowReplayEvents @PrReviewCheckingIndexedSpec
          (indexedReplayPrefix <> [IndexedWorkflow.SomeIndexedWorkflowEvent indexedEvent])
      , IndexedWorkflow.indexedWorkflowReplayEvents @PrReviewCheckingIndexedSpec
          (indexedReplayPrefix <> [IndexedWorkflow.SomeIndexedWorkflowEvent indexedEvent])
      )
      of
      ( Right facadeObserved
        , Right compatibilityObserved
        , Right compatibilityPlan
        , Right indexedObserved
        , Right indexedPlan
        , Right (appliedState, appliedEffects)
        , Right (PrReviewCheckingIndexedState indexedAppliedState, PrReviewCheckingIndexedEffectPlan indexedAppliedEffects)
        , Right compatibilityReplay
        , Right compatibilityReplayAgain
        , Right indexedReplay
        , Right indexedReplayAgain
        ) ->
        let PrReviewCheckingIndexedState indexedNextState =
              IndexedWorkflow.indexedWorkflowObservedState @PrReviewCheckingIndexedSpec indexedObserved
            indexedReplayResultValue = prReviewCheckingIndexedReplayResult indexedReplay
            indexedReplayAgainValue = prReviewCheckingIndexedReplayResult indexedReplayAgain
            wrappedTransition = IndexedWorkflow.SomeIndexedPlannedTransition indexedPlan
            fullCompatibilityPlan = compatibilityPlan.plannedPreCommitEffects <> compatibilityPlan.plannedPostCommitEffects
            indexedFullPlan =
              PrReviewCheckingIndexedEffectPlan fullCompatibilityPlan
                :: PrReviewCheckingIndexedEffectPlan source target
         in facadeObserved.observedEvent == compatibilityObserved.observedEvent
              && facadeObserved.observedEffects == compatibilityObserved.observedEffects
              && sameWatcherStateShape facadeObserved.observedState compatibilityObserved.observedState
              && compatibilityObserved.observedEvent == expectedEvent
              && prReviewCheckingIndexedTransitionEvent indexedPlan == compatibilityPlan.plannedEvent
              && prReviewCheckingIndexedTransitionEvent indexedPlan == expectedEvent
              && IndexedWorkflow.someIndexedWorkflowTransitionSourceLabel @PrReviewCheckingIndexedSpec wrappedTransition == workflowStateLabel @MoifoldSpec state
              && IndexedWorkflow.someIndexedWorkflowTransitionTargetLabel @PrReviewCheckingIndexedSpec wrappedTransition == workflowStateLabel @MoifoldSpec compatibilityObserved.observedState
              && workflowStateLabel @MoifoldSpec indexedNextState == workflowStateLabel @MoifoldSpec compatibilityObserved.observedState
              && sameWatcherStateShape compatibilityObserved.observedState indexedNextState
              && sameWatcherStateShape compatibilityObserved.observedState appliedState
              && sameWatcherStateShape appliedState indexedAppliedState
              && prReviewCheckingIndexedTransitionPreCommitEffects indexedPlan == compatibilityPlan.plannedPreCommitEffects
              && prReviewCheckingIndexedTransitionPostCommitEffects indexedPlan == compatibilityPlan.plannedPostCommitEffects
              && fullCompatibilityPlan == compatibilityObserved.observedEffects
              && prReviewCheckingAppliedEffectsMatch expectedEvent fullCompatibilityPlan appliedEffects
              && prReviewCheckingAppliedEffectsMatch expectedEvent fullCompatibilityPlan indexedAppliedEffects
              && prReviewCheckingEffectLabels appliedEffects == prReviewCheckingEffectLabels indexedAppliedEffects
              && lastEffectPlanLabelsAre appliedEffects compatibilityReplay.replayEffects
              && lastEffectPlanLabelsAre indexedAppliedEffects indexedReplayResultValue.replayEffects
              && IndexedWorkflow.indexedWorkflowPlannedTransitionPreCommitEffectLabels @PrReviewCheckingIndexedSpec indexedPlan
                == fmap (workflowEffectLabel @MoifoldSpec) compatibilityPlan.plannedPreCommitEffects
              && IndexedWorkflow.indexedWorkflowPlannedTransitionPostCommitEffectLabels @PrReviewCheckingIndexedSpec indexedPlan
                == fmap (workflowEffectLabel @MoifoldSpec) compatibilityPlan.plannedPostCommitEffects
              && workflowValidateEffects @MoifoldSpec state fullCompatibilityPlan
                == IndexedWorkflow.indexedWorkflowValidateEffects @PrReviewCheckingIndexedSpec indexedState indexedFullPlan
              && all
                ( \effect ->
                    workflowEffectAllowed @MoifoldSpec state effect
                      == IndexedWorkflow.indexedWorkflowEffectAllowed @PrReviewCheckingIndexedSpec indexedState (PrReviewCheckingIndexedEffect effect)
                )
                fullCompatibilityPlan
              && sameWatcherStateShape compatibilityReplay.replayState indexedReplayResultValue.replayState
              && workflowStateLabel @MoifoldSpec compatibilityReplay.replayState == workflowStateLabel @MoifoldSpec indexedReplayResultValue.replayState
              && compatibilityReplay.replayEffects == indexedReplayResultValue.replayEffects
              && sameWatcherStateShape compatibilityReplay.replayState compatibilityReplayAgain.replayState
              && compatibilityReplay.replayEffects == compatibilityReplayAgain.replayEffects
              && sameWatcherStateShape indexedReplayResultValue.replayState indexedReplayAgainValue.replayState
              && indexedReplayResultValue.replayEffects == indexedReplayAgainValue.replayEffects
      _ -> False

prReviewCheckingAppliedEffectsMatch :: WatcherEvent -> EffectPlan -> EffectPlan -> Bool
prReviewCheckingAppliedEffectsMatch expectedEvent planned applied =
  case expectedEvent of
    PrReviewUnresolvedFound {} ->
      prReviewCheckingEffectLabels applied == prReviewCheckingEffectLabels planned
    _ ->
      applied == planned

prReviewCheckingEffectLabels :: EffectPlan -> [Text]
prReviewCheckingEffectLabels =
  fmap (workflowEffectLabel @MoifoldSpec)

lastEffectPlanLabelsAre :: EffectPlan -> [EffectPlan] -> Bool
lastEffectPlanLabelsAre expected plans =
  case reverse plans of
    actual : _ -> prReviewCheckingEffectLabels actual == prReviewCheckingEffectLabels expected
    [] -> False

data PrReviewWorkerIndexedFixture = PrReviewWorkerIndexedFixture
  { prReviewWorkerIndexedPrefix :: [WatcherEvent]
  , prReviewWorkerIndexedTypedPrefix :: [IndexedWorkflow.SomeIndexedWorkflowEvent PrReviewWorkerIndexedSpec]
  , prReviewWorkerIndexedStateValue :: SomeWatcherState
  }

prReviewWorkerIndexedFixture :: PrReviewWorkerIndexedFixture
prReviewWorkerIndexedFixture =
  PrReviewWorkerIndexedFixture
    { prReviewWorkerIndexedPrefix = [initialized, unresolved]
    , prReviewWorkerIndexedTypedPrefix =
        [ IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewWorkerIndexedEvent "PrReview/Uninitialized" "PrReview/CheckingReviews" initialized
                :: PrReviewWorkerIndexedEvent PrReviewWorkerIndexedUninitialized PrReviewWorkerIndexedCheckingReviews
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewWorkerIndexedEvent "PrReview/CheckingReviews" "PrReview/FixingReviews" unresolved
                :: PrReviewWorkerIndexedEvent PrReviewWorkerIndexedCheckingReviews PrReviewWorkerIndexedFixingReviews
            )
        ]
    , prReviewWorkerIndexedStateValue =
        SomeWatcherState
          ( PrFixingReviews
              prConfig
              evidence
              (WorkerActive (ActiveTurn workerThread workerTurn))
              (ReviewerIdle reviewerThread)
          )
    }
 where
  repo = RepoName "soulomoon/mlf2"
  prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
  workerThread = ThreadId "worker"
  reviewerThread = ThreadId "reviewer"
  commit = CommitSha "abc123"
  workerTurn = TurnId "worker-turn"
  reviewThreadId = ReviewThreadId "thread-1"
  evidence = reviewEvidenceFromThreads (reviewThreadId :| []) commit
  initialized = PrReviewInitialized prConfig workerThread reviewerThread
  unresolved = PrReviewUnresolvedFound (reviewThreadId :| []) commit workerTurn

workflowPrReviewWorkerIndexedSpecMatchesCompatibilityForOutcomes :: IO Bool
workflowPrReviewWorkerIndexedSpecMatchesCompatibilityForOutcomes = do
  let completedObservation =
        PrReviewWorkerIndexedObservation
          "PrReview/FixingReviews"
          "PrReview/CheckingReviews"
          (DaemonPrReviewObservation (ObservedWorkerOutcome WorkerCompleted))
          :: PrReviewWorkerIndexedObservation PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedCheckingReviews
      completedEvent =
        PrReviewWorkerIndexedEvent "PrReview/FixingReviews" "PrReview/CheckingReviews" PrReviewFixCompleted
          :: PrReviewWorkerIndexedEvent PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedCheckingReviews
      incompleteReason = "worker needs another pass"
      incompleteObservation =
        PrReviewWorkerIndexedObservation
          "PrReview/FixingReviews"
          "PrReview/CheckingReviews"
          (DaemonPrReviewObservation (ObservedWorkerOutcome (WorkerIncomplete incompleteReason)))
          :: PrReviewWorkerIndexedObservation PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedCheckingReviews
      incompleteEvent =
        PrReviewWorkerIndexedEvent "PrReview/FixingReviews" "PrReview/CheckingReviews" (PrReviewFixIncomplete incompleteReason)
          :: PrReviewWorkerIndexedEvent PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedCheckingReviews
      blockedReason = BlockedReason "worker blocked on failing command"
      blockedObservation =
        PrReviewWorkerIndexedObservation
          "PrReview/FixingReviews"
          "PrReview/Blocked"
          (DaemonPrReviewObservation (ObservedWorkerOutcome (WorkerBlocked blockedReason)))
          :: PrReviewWorkerIndexedObservation PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedBlocked
      blockedEvent =
        PrReviewWorkerIndexedEvent "PrReview/FixingReviews" "PrReview/Blocked" (WatcherBlocked blockedReason)
          :: PrReviewWorkerIndexedEvent PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedBlocked
  results <-
    sequence
      [ prReviewWorkerIndexedSpecMatchesCompatibility
          "indexed workflow PR-review worker complete outcome matches compatibility"
          (ObservedWorkerOutcome WorkerCompleted)
          completedObservation
          PrReviewFixCompleted
          completedEvent
          sleepPostCommitPlan
      , prReviewWorkerIndexedSpecMatchesCompatibility
          "indexed workflow PR-review worker incomplete outcome matches compatibility"
          (ObservedWorkerOutcome (WorkerIncomplete incompleteReason))
          incompleteObservation
          (PrReviewFixIncomplete incompleteReason)
          incompleteEvent
          sleepPostCommitPlan
      , prReviewWorkerIndexedSpecMatchesCompatibility
          "indexed workflow PR-review worker blocked outcome matches compatibility"
          (ObservedWorkerOutcome (WorkerBlocked blockedReason))
          blockedObservation
          (WatcherBlocked blockedReason)
          blockedEvent
          blockedPostCommitPlan
      ]
  pure (and results)

workflowPrReviewWorkerIndexedSpecMatchesClassifierBackedOutcomes :: IO Bool
workflowPrReviewWorkerIndexedSpecMatchesClassifierBackedOutcomes = do
  let incompleteReason = "tests still failing"
      malformedReason = "worker turn completed without structured outcome"
      missingOutputReason = BlockedReason "worker turn completed without output"
      completeObservation =
        PrReviewWorkerIndexedObservation
          "PrReview/FixingReviews"
          "PrReview/CheckingReviews"
          (DaemonPrReviewObservation (ObservedWorkerOutcome WorkerCompleted))
          :: PrReviewWorkerIndexedObservation PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedCheckingReviews
      completeEvent =
        PrReviewWorkerIndexedEvent "PrReview/FixingReviews" "PrReview/CheckingReviews" PrReviewFixCompleted
          :: PrReviewWorkerIndexedEvent PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedCheckingReviews
      incompleteObservation =
        PrReviewWorkerIndexedObservation
          "PrReview/FixingReviews"
          "PrReview/CheckingReviews"
          (DaemonPrReviewObservation (ObservedWorkerOutcome (WorkerIncomplete incompleteReason)))
          :: PrReviewWorkerIndexedObservation PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedCheckingReviews
      incompleteEvent =
        PrReviewWorkerIndexedEvent "PrReview/FixingReviews" "PrReview/CheckingReviews" (PrReviewFixIncomplete incompleteReason)
          :: PrReviewWorkerIndexedEvent PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedCheckingReviews
      malformedObservation =
        PrReviewWorkerIndexedObservation
          "PrReview/FixingReviews"
          "PrReview/CheckingReviews"
          (DaemonPrReviewObservation (ObservedWorkerOutcome (WorkerIncomplete malformedReason)))
          :: PrReviewWorkerIndexedObservation PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedCheckingReviews
      malformedEvent =
        PrReviewWorkerIndexedEvent "PrReview/FixingReviews" "PrReview/CheckingReviews" (PrReviewFixIncomplete malformedReason)
          :: PrReviewWorkerIndexedEvent PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedCheckingReviews
      missingOutputObservation =
        PrReviewWorkerIndexedObservation
          "PrReview/FixingReviews"
          "PrReview/Blocked"
          (DaemonPrReviewObservation (ObservedWorkerOutcome (WorkerBlocked missingOutputReason)))
          :: PrReviewWorkerIndexedObservation PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedBlocked
      missingOutputEvent =
        PrReviewWorkerIndexedEvent "PrReview/FixingReviews" "PrReview/Blocked" (WatcherBlocked missingOutputReason)
          :: PrReviewWorkerIndexedEvent PrReviewWorkerIndexedFixingReviews PrReviewWorkerIndexedBlocked
  results <-
    sequence
      [ prReviewWorkerIndexedClassifierCase
          "indexed workflow PR-review worker structured complete classifier backs indexed planning"
          (AppServerTurn (TurnId "worker-complete") "completed" (Just "{\"outcome\":\"complete\",\"summary\":\"done\"}"))
          WorkflowAgent.AgentComplete
          WorkerCompleted
          completeObservation
          PrReviewFixCompleted
          completeEvent
          sleepPostCommitPlan
      , prReviewWorkerIndexedClassifierCase
          "indexed workflow PR-review worker structured incomplete classifier backs indexed planning"
          (AppServerTurn (TurnId "worker-incomplete") "completed" (Just "{\"outcome\":\"incomplete\",\"reason\":\"tests still failing\"}"))
          WorkflowAgent.AgentIncomplete
          (WorkerIncomplete incompleteReason)
          incompleteObservation
          (PrReviewFixIncomplete incompleteReason)
          incompleteEvent
          sleepPostCommitPlan
      , prReviewWorkerIndexedClassifierCase
          "indexed workflow PR-review worker missing output classifier backs indexed planning"
          (AppServerTurn (TurnId "worker-blocked") "completed" Nothing)
          WorkflowAgent.AgentBlocked
          (WorkerBlocked missingOutputReason)
          missingOutputObservation
          (WatcherBlocked missingOutputReason)
          missingOutputEvent
          blockedPostCommitPlan
      , prReviewWorkerIndexedClassifierCase
          "indexed workflow PR-review worker failed structured complete classifier backs indexed planning"
          (AppServerTurn (TurnId "worker-failed-complete") "failed" (Just "{\"outcome\":\"complete\",\"summary\":\"fixed\"}"))
          WorkflowAgent.AgentComplete
          WorkerCompleted
          completeObservation
          PrReviewFixCompleted
          completeEvent
          sleepPostCommitPlan
      , prReviewWorkerIndexedClassifierCase
          "indexed workflow PR-review worker failed structured incomplete classifier backs indexed planning"
          (AppServerTurn (TurnId "worker-failed-incomplete") "failed" (Just "{\"outcome\":\"incomplete\",\"reason\":\"tests still failing\"}"))
          WorkflowAgent.AgentIncomplete
          (WorkerIncomplete incompleteReason)
          incompleteObservation
          (PrReviewFixIncomplete incompleteReason)
          incompleteEvent
          sleepPostCommitPlan
      , prReviewWorkerIndexedClassifierCase
          "indexed workflow PR-review worker malformed completed output classifier backs indexed planning"
          (AppServerTurn (TurnId "worker-malformed-complete") "completed" (Just "{\"outcome\":\"complete\"}"))
          WorkflowAgent.AgentMalformed
          (WorkerIncomplete malformedReason)
          malformedObservation
          (PrReviewFixIncomplete malformedReason)
          malformedEvent
          sleepPostCommitPlan
      ]
  pure (and results)

workflowPrReviewWorkerIndexedSpecRejectsInvalidObservationLikeFacade :: IO Bool
workflowPrReviewWorkerIndexedSpecRejectsInvalidObservationLikeFacade = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      state = SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      facadeObservation = ObservedWorkerOutcome WorkerCompleted
      daemonObservation = DaemonPrReviewObservation facadeObservation
      indexedState =
        PrReviewWorkerIndexedState state
          :: PrReviewWorkerIndexedState PrReviewWorkerIndexedCheckingReviews
      indexedObservation =
        PrReviewWorkerIndexedObservation "PrReview/CheckingReviews" "PrReview/CheckingReviews" daemonObservation
          :: PrReviewWorkerIndexedObservation PrReviewWorkerIndexedCheckingReviews PrReviewWorkerIndexedCheckingReviews
  assert "indexed workflow PR-review worker rejects invalid observation like facade" $
    case
      ( prReviewObserve state facadeObservation
      , workflowObserve @MoifoldSpec state daemonObservation
      , workflowPlanObservation @MoifoldSpec state daemonObservation
      , IndexedWorkflow.indexedWorkflowObserve @PrReviewWorkerIndexedSpec indexedState indexedObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @PrReviewWorkerIndexedSpec indexedState indexedObservation
      )
      of
      (Left facadeFailure, Left compatibilityFailure, Left compatibilityPlanFailure, Left indexedFailure, Left indexedPlanFailure) ->
        compatibilityFailure == facadeFailure
          && compatibilityPlanFailure == facadeFailure
          && indexedFailure == facadeFailure
          && indexedPlanFailure == facadeFailure
      _ -> False

prReviewWorkerIndexedClassifierCase
  :: forall (target :: Type).
     String
  -> AppServerTurn
  -> WorkflowAgent.AgentOutputClass
  -> WorkerOutcome
  -> PrReviewWorkerIndexedObservation PrReviewWorkerIndexedFixingReviews target
  -> WatcherEvent
  -> PrReviewWorkerIndexedEvent PrReviewWorkerIndexedFixingReviews target
  -> (PlannedTransition MoifoldSpec -> Bool)
  -> IO Bool
prReviewWorkerIndexedClassifierCase title turn expectedClass expectedOutcome indexedObservation expectedEvent indexedEvent planCheck =
  case WorkflowAgent.classifyAgentRoleTurn WorkflowPrReviewAgent.prReviewWorkerAgentRole turn of
    Right classified
      | classified.classifiedOutputClass == expectedClass
          && classified.classifiedOutputPayload == ObservedWorkerOutcome expectedOutcome ->
          prReviewWorkerIndexedSpecMatchesCompatibility
            title
            (ObservedWorkerOutcome expectedOutcome)
            indexedObservation
            expectedEvent
            indexedEvent
            planCheck
    _ ->
      assert title False

prReviewWorkerIndexedSpecMatchesCompatibility
  :: forall (source :: Type) (target :: Type).
     String
  -> PrReviewObservation
  -> PrReviewWorkerIndexedObservation source target
  -> WatcherEvent
  -> PrReviewWorkerIndexedEvent source target
  -> (PlannedTransition MoifoldSpec -> Bool)
  -> IO Bool
prReviewWorkerIndexedSpecMatchesCompatibility title facadeObservation indexedObservation expectedEvent indexedEvent planCheck =
  assert title $
    case
      ( prReviewObserve state facadeObservation
      , workflowObserve @MoifoldSpec state observation
      , workflowPlanObservation @MoifoldSpec state observation
      , IndexedWorkflow.indexedWorkflowObserve @PrReviewWorkerIndexedSpec indexedState indexedObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @PrReviewWorkerIndexedSpec indexedState indexedObservation
      , workflowApplyEvent @MoifoldSpec state expectedEvent
      , IndexedWorkflow.indexedWorkflowApplyEvent @PrReviewWorkerIndexedSpec indexedState indexedEvent
      , workflowReplayEvents @MoifoldSpec (fixture.prReviewWorkerIndexedPrefix <> [expectedEvent])
      , IndexedWorkflow.indexedWorkflowReplayEvents @PrReviewWorkerIndexedSpec
          (fixture.prReviewWorkerIndexedTypedPrefix <> [IndexedWorkflow.SomeIndexedWorkflowEvent indexedEvent])
      )
      of
      ( Right facadeObserved
        , Right compatibilityObserved
        , Right compatibilityPlan
        , Right indexedObserved
        , Right indexedPlan
        , Right (appliedState, appliedEffects)
        , Right (PrReviewWorkerIndexedState indexedAppliedState, PrReviewWorkerIndexedEffectPlan indexedAppliedEffects)
        , Right compatibilityReplay
        , Right indexedReplay
        ) ->
          let PrReviewWorkerIndexedState indexedNextState =
                IndexedWorkflow.indexedWorkflowObservedState @PrReviewWorkerIndexedSpec indexedObserved
              indexedReplayResultValue = prReviewWorkerIndexedReplayResult indexedReplay
              wrappedTransition = IndexedWorkflow.SomeIndexedPlannedTransition indexedPlan
              fullCompatibilityPlan = compatibilityPlan.plannedPreCommitEffects <> compatibilityPlan.plannedPostCommitEffects
              indexedFullPlan =
                PrReviewWorkerIndexedEffectPlan fullCompatibilityPlan
                  :: PrReviewWorkerIndexedEffectPlan source target
           in facadeObserved.prReviewTickEvent == compatibilityObserved.observedEvent
                && facadeObserved.prReviewTickEffects == compatibilityObserved.observedEffects
                && sameWatcherStateShape facadeObserved.prReviewTickState compatibilityObserved.observedState
                && compatibilityObserved.observedEvent == expectedEvent
                && prReviewWorkerIndexedTransitionEvent indexedPlan == compatibilityPlan.plannedEvent
                && prReviewWorkerIndexedTransitionEvent indexedPlan == expectedEvent
                && IndexedWorkflow.someIndexedWorkflowTransitionSourceLabel @PrReviewWorkerIndexedSpec wrappedTransition == workflowStateLabel @MoifoldSpec state
                && IndexedWorkflow.someIndexedWorkflowTransitionTargetLabel @PrReviewWorkerIndexedSpec wrappedTransition == workflowStateLabel @MoifoldSpec compatibilityObserved.observedState
                && workflowStateLabel @MoifoldSpec indexedNextState == workflowStateLabel @MoifoldSpec compatibilityObserved.observedState
                && sameWatcherStateShape compatibilityObserved.observedState indexedNextState
                && sameWatcherStateShape compatibilityObserved.observedState appliedState
                && sameWatcherStateShape appliedState indexedAppliedState
                && prReviewWorkerIndexedTransitionPreCommitEffects indexedPlan == compatibilityPlan.plannedPreCommitEffects
                && prReviewWorkerIndexedTransitionPostCommitEffects indexedPlan == compatibilityPlan.plannedPostCommitEffects
                && fullCompatibilityPlan == compatibilityObserved.observedEffects
                && appliedEffects == fullCompatibilityPlan
                && indexedAppliedEffects == fullCompatibilityPlan
                && planCheck compatibilityPlan
                && IndexedWorkflow.indexedWorkflowPlannedTransitionPreCommitEffectLabels @PrReviewWorkerIndexedSpec indexedPlan
                  == fmap (workflowEffectLabel @MoifoldSpec) compatibilityPlan.plannedPreCommitEffects
                && IndexedWorkflow.indexedWorkflowPlannedTransitionPostCommitEffectLabels @PrReviewWorkerIndexedSpec indexedPlan
                  == fmap (workflowEffectLabel @MoifoldSpec) compatibilityPlan.plannedPostCommitEffects
                && workflowValidateEffects @MoifoldSpec state fullCompatibilityPlan
                  == IndexedWorkflow.indexedWorkflowValidateEffects @PrReviewWorkerIndexedSpec indexedState indexedFullPlan
                && all
                  ( \effect ->
                      workflowEffectAllowed @MoifoldSpec state effect
                        == IndexedWorkflow.indexedWorkflowEffectAllowed @PrReviewWorkerIndexedSpec indexedState (PrReviewWorkerIndexedEffect effect)
                  )
                  fullCompatibilityPlan
                && sameWatcherStateShape compatibilityReplay.replayState indexedReplayResultValue.replayState
                && workflowStateLabel @MoifoldSpec compatibilityReplay.replayState == workflowStateLabel @MoifoldSpec indexedReplayResultValue.replayState
                && compatibilityReplay.replayEffects == indexedReplayResultValue.replayEffects
      _ -> False
 where
  fixture = prReviewWorkerIndexedFixture
  state = fixture.prReviewWorkerIndexedStateValue
  indexedState =
    PrReviewWorkerIndexedState state
      :: PrReviewWorkerIndexedState source
  observation = DaemonPrReviewObservation facadeObservation

sleepPostCommitPlan :: PlannedTransition MoifoldSpec -> Bool
sleepPostCommitPlan planned =
  hasEffect SleepUntilNextPollTag planned.plannedPostCommitEffects
    && lacksEffect SleepUntilNextPollTag planned.plannedPreCommitEffects
    && lacksEffect RecordBlockedTag planned.plannedPreCommitEffects
    && lacksEffect RecordBlockedTag planned.plannedPostCommitEffects

blockedPostCommitPlan :: PlannedTransition MoifoldSpec -> Bool
blockedPostCommitPlan planned =
  hasEffect RecordBlockedTag planned.plannedPostCommitEffects
    && hasEffect StopDaemonTag planned.plannedPostCommitEffects
    && lacksEffect RecordBlockedTag planned.plannedPreCommitEffects
    && lacksEffect StopDaemonTag planned.plannedPreCommitEffects

data PrReviewReviewerIndexedFixture = PrReviewReviewerIndexedFixture
  { prReviewReviewerIndexedPrefix :: [WatcherEvent]
  , prReviewReviewerIndexedTypedPrefix :: [IndexedWorkflow.SomeIndexedWorkflowEvent PrReviewReviewerIndexedSpec]
  , prReviewReviewerIndexedStateValue :: SomeWatcherState
  }

prReviewReviewerNormalFixture :: PrReviewReviewerIndexedFixture
prReviewReviewerNormalFixture =
  PrReviewReviewerIndexedFixture
    { prReviewReviewerIndexedPrefix = [initialized, noUnresolved]
    , prReviewReviewerIndexedTypedPrefix =
        [ IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewReviewerIndexedEvent "PrReview/Uninitialized" "PrReview/CheckingReviews" initialized
                :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedUninitialized PrReviewReviewerIndexedCheckingReviews
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewReviewerIndexedEvent "PrReview/CheckingReviews" "PrReview/ReviewingClean" noUnresolved
                :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedCheckingReviews PrReviewReviewerIndexedReviewingClean
            )
        ]
    , prReviewReviewerIndexedStateValue =
        SomeWatcherState
          ( PrReviewingClean
              prConfig
              commit
              normalReviewContext
              (WorkerIdle workerThread)
              (ReviewerActive (ActiveTurn reviewerThread reviewerTurn))
          )
    }
 where
  repo = RepoName "soulomoon/mlf2"
  prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
  workerThread = ThreadId "worker"
  reviewerThread = ThreadId "reviewer"
  commit = CommitSha "abc123"
  reviewerTurn = TurnId "reviewer-turn"
  initialized = PrReviewInitialized prConfig workerThread reviewerThread
  noUnresolved = PrReviewNoUnresolvedFound commit reviewerTurn

prReviewReviewerVerificationFixture :: PrReviewReviewerIndexedFixture
prReviewReviewerVerificationFixture =
  PrReviewReviewerIndexedFixture
    { prReviewReviewerIndexedPrefix = [initialized, unresolved, fixCompleted, verificationStarted]
    , prReviewReviewerIndexedTypedPrefix =
        [ IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewReviewerIndexedEvent "PrReview/Uninitialized" "PrReview/CheckingReviews" initialized
                :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedUninitialized PrReviewReviewerIndexedCheckingReviews
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewReviewerIndexedEvent "PrReview/CheckingReviews" "PrReview/FixingReviews" unresolved
                :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedCheckingReviews PrReviewReviewerIndexedFixingReviews
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewReviewerIndexedEvent "PrReview/FixingReviews" "PrReview/VerifyingReviewFix" fixCompleted
                :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedFixingReviews PrReviewReviewerIndexedVerifyingReviewFix
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( PrReviewReviewerIndexedEvent "PrReview/VerifyingReviewFix" "PrReview/ReviewingClean" verificationStarted
                :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedVerifyingReviewFix PrReviewReviewerIndexedReviewingClean
            )
        ]
    , prReviewReviewerIndexedStateValue =
        SomeWatcherState
          ( PrReviewingClean
              prConfig
              reviewTarget
              (verificationReviewContext evidence)
              (WorkerIdle workerThread)
              (ReviewerActive (ActiveTurn reviewerThread reviewerTurn))
          )
    }
 where
  repo = RepoName "soulomoon/mlf2"
  prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
  workerThread = ThreadId "worker"
  reviewerThread = ThreadId "reviewer"
  reviewedCommit = CommitSha "abc123"
  reviewTarget = CommitSha "def456"
  workerTurn = TurnId "worker-turn"
  reviewerTurn = TurnId "reviewer-turn"
  reviewThreadId = ReviewThreadId "thread-fixed"
  evidence = reviewEvidenceFromThreads (reviewThreadId :| []) reviewedCommit
  initialized = PrReviewInitialized prConfig workerThread reviewerThread
  unresolved = PrReviewUnresolvedFound (reviewThreadId :| []) reviewedCommit workerTurn
  fixCompleted = PrReviewFixCompleted
  verificationStarted = PrReviewFixVerificationStarted evidence reviewTarget reviewerTurn

workflowPrReviewReviewerIndexedSpecMatchesCompatibilityForOutcomes :: IO Bool
workflowPrReviewReviewerIndexedSpecMatchesCompatibilityForOutcomes = do
  let normalFixture = prReviewReviewerNormalFixture
      verificationFixture = prReviewReviewerVerificationFixture
      cleanEvidence = CleanReviewEvidence (CommitSha "abc123") "LGTM"
      verificationCleanEvidence = CleanReviewEvidence (CommitSha "def456") "LGTM"
      fixedThread = ReviewThreadId "thread-fixed"
      remainingThread = ReviewThreadId "thread-remaining"
      missingThreadReason =
        "clean verification did not mark fixed prior review threads as resolved: thread-fixed"
      problemEvidence =
        ReviewEvidence
          ( ReviewThreadCommentFinding remainingThread Nothing "still applies"
              :| [ReviewSummaryFinding "new summary finding"]
          )
          (CommitSha "def456")
      incompleteReason = "reviewer needs another pass"
      blockedReason = BlockedReason "reviewer blocked on missing logs"
  results <-
    sequence
      [ prReviewReviewerIndexedSpecMatchesCompatibility
          "indexed workflow PR-review reviewer normal clean matches compatibility"
          normalFixture
          (ObservedReviewerOutcome (ReviewerClean cleanEvidence []))
          ( PrReviewReviewerIndexedObservation
              "PrReview/ReviewingClean"
              "PrReview/WaitingMergeability"
              (DaemonPrReviewObservation (ObservedReviewerOutcome (ReviewerClean cleanEvidence [])))
              :: PrReviewReviewerIndexedObservation PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedWaitingMergeability
          )
          "PrReview/WaitingMergeability"
          (PrReviewCleanFound cleanEvidence [])
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/WaitingMergeability" (PrReviewCleanFound cleanEvidence [])
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedWaitingMergeability
          )
          sleepPostCommitPlan
      , prReviewReviewerIndexedSpecMatchesCompatibility
          "indexed workflow PR-review reviewer verification clean matches compatibility"
          verificationFixture
          (ObservedReviewerOutcome (ReviewerClean verificationCleanEvidence [fixedThread]))
          ( PrReviewReviewerIndexedObservation
              "PrReview/ReviewingClean"
              "PrReview/CheckingReviews"
              (DaemonPrReviewObservation (ObservedReviewerOutcome (ReviewerClean verificationCleanEvidence [fixedThread])))
              :: PrReviewReviewerIndexedObservation PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          "PrReview/CheckingReviews"
          (PrReviewCleanFound verificationCleanEvidence [fixedThread])
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/CheckingReviews" (PrReviewCleanFound verificationCleanEvidence [fixedThread])
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          (effectTagPlan [ResolveReviewThreadTag, ReadReviewThreadsTag])
      , prReviewReviewerIndexedSpecMatchesCompatibility
          "indexed workflow PR-review reviewer verification clean missing fixed thread normalizes incomplete"
          verificationFixture
          (ObservedReviewerOutcome (ReviewerClean verificationCleanEvidence []))
          ( PrReviewReviewerIndexedObservation
              "PrReview/ReviewingClean"
              "PrReview/VerifyingReviewFix"
              (DaemonPrReviewObservation (ObservedReviewerOutcome (ReviewerClean verificationCleanEvidence [])))
              :: PrReviewReviewerIndexedObservation PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedVerifyingReviewFix
          )
          "PrReview/VerifyingReviewFix"
          (PrReviewReviewIncomplete missingThreadReason)
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/VerifyingReviewFix" (PrReviewReviewIncomplete missingThreadReason)
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedVerifyingReviewFix
          )
          sleepPostCommitPlan
      , prReviewReviewerIndexedSpecMatchesCompatibility
          "indexed workflow PR-review reviewer problems preserve resolve reply publish sleep order"
          verificationFixture
          (ObservedReviewerOutcome (ReviewerProblemsAdded problemEvidence [fixedThread]))
          ( PrReviewReviewerIndexedObservation
              "PrReview/ReviewingClean"
              "PrReview/CheckingReviews"
              (DaemonPrReviewObservation (ObservedReviewerOutcome (ReviewerProblemsAdded problemEvidence [fixedThread])))
              :: PrReviewReviewerIndexedObservation PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          "PrReview/CheckingReviews"
          (PrReviewProblemsAdded problemEvidence [fixedThread])
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/CheckingReviews" (PrReviewProblemsAdded problemEvidence [fixedThread])
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          (effectTagPlan [ResolveReviewThreadTag, ReplyReviewThreadTag, PublishReviewFindingsTag, SleepUntilNextPollTag])
      , prReviewReviewerIndexedSpecMatchesCompatibility
          "indexed workflow PR-review reviewer normal incomplete rechecks reviews"
          normalFixture
          (ObservedReviewerOutcome (ReviewerIncomplete incompleteReason))
          ( PrReviewReviewerIndexedObservation
              "PrReview/ReviewingClean"
              "PrReview/CheckingReviews"
              (DaemonPrReviewObservation (ObservedReviewerOutcome (ReviewerIncomplete incompleteReason)))
              :: PrReviewReviewerIndexedObservation PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          "PrReview/CheckingReviews"
          (PrReviewReviewIncomplete incompleteReason)
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/CheckingReviews" (PrReviewReviewIncomplete incompleteReason)
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          (effectTagPlan [ReadReviewThreadsTag])
      , prReviewReviewerIndexedSpecMatchesCompatibility
          "indexed workflow PR-review reviewer verification incomplete sleeps for verification retry"
          verificationFixture
          (ObservedReviewerOutcome (ReviewerIncomplete incompleteReason))
          ( PrReviewReviewerIndexedObservation
              "PrReview/ReviewingClean"
              "PrReview/VerifyingReviewFix"
              (DaemonPrReviewObservation (ObservedReviewerOutcome (ReviewerIncomplete incompleteReason)))
              :: PrReviewReviewerIndexedObservation PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedVerifyingReviewFix
          )
          "PrReview/VerifyingReviewFix"
          (PrReviewReviewIncomplete incompleteReason)
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/VerifyingReviewFix" (PrReviewReviewIncomplete incompleteReason)
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedVerifyingReviewFix
          )
          sleepPostCommitPlan
      , prReviewReviewerIndexedSpecMatchesCompatibility
          "indexed workflow PR-review reviewer blocked stops after commit"
          normalFixture
          (ObservedReviewerOutcome (ReviewerBlocked blockedReason))
          ( PrReviewReviewerIndexedObservation
              "PrReview/ReviewingClean"
              "PrReview/Blocked"
              (DaemonPrReviewObservation (ObservedReviewerOutcome (ReviewerBlocked blockedReason)))
              :: PrReviewReviewerIndexedObservation PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedBlocked
          )
          "PrReview/Blocked"
          (WatcherBlocked blockedReason)
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/Blocked" (WatcherBlocked blockedReason)
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedBlocked
          )
          blockedPostCommitPlan
      ]
  pure (and results)

workflowPrReviewReviewerIndexedSpecMatchesClassifierBackedOutcomes :: IO Bool
workflowPrReviewReviewerIndexedSpecMatchesClassifierBackedOutcomes = do
  let normalFixture = prReviewReviewerNormalFixture
      verificationFixture = prReviewReviewerVerificationFixture
      commit = CommitSha "abc123"
      verificationCommit = CommitSha "def456"
      cleanEvidence = CleanReviewEvidence commit "LGTM"
      verificationCleanEvidence = CleanReviewEvidence verificationCommit "LGTM"
      fixedThread = ReviewThreadId "thread-fixed"
      remainingThread = ReviewThreadId "thread-1"
      remainingEvidence = reviewEvidenceFromThreadComments ((remainingThread, "still not fixed") :| []) commit
      combinedEvidence =
        ReviewEvidence
          ( ReviewThreadCommentFinding remainingThread Nothing "still not fixed"
              :| [ReviewSummaryFinding "new summary finding"]
          )
          verificationCommit
      missingFieldsReason =
        "reviewer state missing required fields: reviewed_commit_sha, reviewer_prompt_version, added_review_comment_count, prior_findings_status, new_findings_status, lgtm_comment, prior_findings_summary, new_findings_summary, blocked_reason, solved_threads, remaining_review_threads"
      mismatchReason = "reviewer inspected def456, expected abc123"
      solvedThreadReason = "solved_threads require prior_findings_status=resolved or unresolved"
      missingOutputReason = BlockedReason "reviewer turn completed without output"
  results <-
    sequence
      [ prReviewReviewerIndexedClassifierCase
          "indexed workflow PR-review reviewer structured clean classifier backs indexed planning"
          normalFixture
          (WorkflowPrReviewAgent.prReviewReviewerAgentRole commit)
          (AppServerTurn (TurnId "reviewer-clean") "completed" (Just (reviewerStateOutput "not_applicable" "none" commit reviewerPromptVersion 0 (Just "LGTM") [] [] Nothing)))
          WorkflowAgent.AgentClean
          (ObservedReviewerOutcome (ReviewerClean cleanEvidence []))
          "PrReview/WaitingMergeability"
          (PrReviewCleanFound cleanEvidence [])
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/WaitingMergeability" (PrReviewCleanFound cleanEvidence [])
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedWaitingMergeability
          )
          sleepPostCommitPlan
      , prReviewReviewerIndexedClassifierCase
          "indexed workflow PR-review reviewer verification clean classifier backs indexed planning"
          verificationFixture
          (WorkflowPrReviewAgent.prReviewReviewerAgentRole verificationCommit)
          (AppServerTurn (TurnId "reviewer-clean-solved") "completed" (Just (reviewerStateOutputWithSolvedAndRemaining "resolved" "none" verificationCommit reviewerPromptVersion 0 (Just "LGTM") [] [] Nothing [(fixedThread, "fixed")] [])))
          WorkflowAgent.AgentClean
          (ObservedReviewerOutcome (ReviewerClean verificationCleanEvidence [fixedThread]))
          "PrReview/CheckingReviews"
          (PrReviewCleanFound verificationCleanEvidence [fixedThread])
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/CheckingReviews" (PrReviewCleanFound verificationCleanEvidence [fixedThread])
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          (effectTagPlan [ResolveReviewThreadTag, ReadReviewThreadsTag])
      , prReviewReviewerIndexedClassifierCase
          "indexed workflow PR-review reviewer new findings classifier backs indexed planning"
          normalFixture
          (WorkflowPrReviewAgent.prReviewReviewerAgentRole commit)
          (AppServerTurn (TurnId "reviewer-new-findings") "completed" (Just (reviewerStateOutput "not_applicable" "found" commit reviewerPromptVersion 0 Nothing [] ["left summary finding"] Nothing)))
          WorkflowAgent.AgentProblems
          (ObservedReviewerOutcome (ReviewerProblemsAdded (reviewEvidenceFromSummaries ("left summary finding" :| []) commit) []))
          "PrReview/CheckingReviews"
          (PrReviewProblemsAdded (reviewEvidenceFromSummaries ("left summary finding" :| []) commit) [])
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/CheckingReviews" (PrReviewProblemsAdded (reviewEvidenceFromSummaries ("left summary finding" :| []) commit) [])
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          (effectTagPlan [PublishReviewFindingsTag, SleepUntilNextPollTag])
      , prReviewReviewerIndexedClassifierCase
          "indexed workflow PR-review reviewer remaining-thread classifier backs indexed planning"
          normalFixture
          (WorkflowPrReviewAgent.prReviewReviewerAgentRole commit)
          (AppServerTurn (TurnId "reviewer-remaining-thread") "completed" (Just (reviewerStateOutputWithRemaining "unresolved" "none" commit reviewerPromptVersion 0 Nothing [] [] Nothing [(remainingThread, "still not fixed")])))
          WorkflowAgent.AgentProblems
          (ObservedReviewerOutcome (ReviewerProblemsAdded remainingEvidence []))
          "PrReview/CheckingReviews"
          (PrReviewProblemsAdded remainingEvidence [])
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/CheckingReviews" (PrReviewProblemsAdded remainingEvidence [])
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          (effectTagPlan [ReplyReviewThreadTag, SleepUntilNextPollTag])
      , prReviewReviewerIndexedClassifierCase
          "indexed workflow PR-review reviewer prior and new findings classifier backs indexed planning"
          verificationFixture
          (WorkflowPrReviewAgent.prReviewReviewerAgentRole verificationCommit)
          (AppServerTurn (TurnId "reviewer-prior-and-new-findings") "completed" (Just (reviewerStateOutputWithSolvedAndRemaining "unresolved" "found" verificationCommit reviewerPromptVersion 0 Nothing [] ["new summary finding"] Nothing [(fixedThread, "fixed")] [(remainingThread, "still not fixed")])))
          WorkflowAgent.AgentProblems
          (ObservedReviewerOutcome (ReviewerProblemsAdded combinedEvidence [fixedThread]))
          "PrReview/CheckingReviews"
          (PrReviewProblemsAdded combinedEvidence [fixedThread])
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/CheckingReviews" (PrReviewProblemsAdded combinedEvidence [fixedThread])
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          (effectTagPlan [ResolveReviewThreadTag, ReplyReviewThreadTag, PublishReviewFindingsTag, SleepUntilNextPollTag])
      , prReviewReviewerIndexedClassifierCase
          "indexed workflow PR-review reviewer missing-state malformed classifier backs indexed planning"
          normalFixture
          (WorkflowPrReviewAgent.prReviewReviewerAgentRole commit)
          (AppServerTurn (TurnId "reviewer-missing-state") "completed" (Just "{\"result\":\"clean\",\"comment\":\"schema LGTM\"}"))
          WorkflowAgent.AgentMalformed
          (ObservedReviewerOutcome (ReviewerIncomplete missingFieldsReason))
          "PrReview/CheckingReviews"
          (PrReviewReviewIncomplete missingFieldsReason)
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/CheckingReviews" (PrReviewReviewIncomplete missingFieldsReason)
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          (effectTagPlan [ReadReviewThreadsTag])
      , prReviewReviewerIndexedClassifierCase
          "indexed workflow PR-review reviewer commit mismatch classifier backs indexed planning"
          normalFixture
          (WorkflowPrReviewAgent.prReviewReviewerAgentRole commit)
          (AppServerTurn (TurnId "reviewer-sha-mismatch") "completed" (Just (reviewerStateOutput "not_applicable" "none" verificationCommit reviewerPromptVersion 0 (Just "LGTM") [] [] Nothing)))
          WorkflowAgent.AgentIncomplete
          (ObservedReviewerOutcome (ReviewerIncomplete mismatchReason))
          "PrReview/CheckingReviews"
          (PrReviewReviewIncomplete mismatchReason)
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/CheckingReviews" (PrReviewReviewIncomplete mismatchReason)
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          (effectTagPlan [ReadReviewThreadsTag])
      , prReviewReviewerIndexedClassifierCase
          "indexed workflow PR-review reviewer invalid solved-thread classifier backs indexed planning"
          normalFixture
          (WorkflowPrReviewAgent.prReviewReviewerAgentRole commit)
          (AppServerTurn (TurnId "reviewer-not-applicable-solved-thread") "completed" (Just (reviewerStateOutputWithSolvedAndRemaining "not_applicable" "none" commit reviewerPromptVersion 0 Nothing [] [] Nothing [(fixedThread, "fixed")] [])))
          WorkflowAgent.AgentIncomplete
          (ObservedReviewerOutcome (ReviewerIncomplete solvedThreadReason))
          "PrReview/CheckingReviews"
          (PrReviewReviewIncomplete solvedThreadReason)
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/CheckingReviews" (PrReviewReviewIncomplete solvedThreadReason)
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedCheckingReviews
          )
          (effectTagPlan [ReadReviewThreadsTag])
      , prReviewReviewerIndexedClassifierCase
          "indexed workflow PR-review reviewer missing output classifier backs indexed planning"
          normalFixture
          (WorkflowPrReviewAgent.prReviewReviewerAgentRole commit)
          (AppServerTurn (TurnId "reviewer-missing-output") "completed" Nothing)
          WorkflowAgent.AgentBlocked
          (ObservedReviewerOutcome (ReviewerBlocked missingOutputReason))
          "PrReview/Blocked"
          (WatcherBlocked missingOutputReason)
          ( PrReviewReviewerIndexedEvent "PrReview/ReviewingClean" "PrReview/Blocked" (WatcherBlocked missingOutputReason)
              :: PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean PrReviewReviewerIndexedBlocked
          )
          blockedPostCommitPlan
      ]
  pure (and results)

workflowPrReviewReviewerIndexedSpecRejectsInvalidObservationLikeFacade :: IO Bool
workflowPrReviewReviewerIndexedSpecRejectsInvalidObservationLikeFacade = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      cleanEvidence = CleanReviewEvidence (CommitSha "abc123") "LGTM"
      state = SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      facadeObservation = ObservedReviewerOutcome (ReviewerClean cleanEvidence [])
      daemonObservation = DaemonPrReviewObservation facadeObservation
      indexedState =
        PrReviewReviewerIndexedState state
          :: PrReviewReviewerIndexedState PrReviewReviewerIndexedCheckingReviews
      indexedObservation =
        PrReviewReviewerIndexedObservation "PrReview/CheckingReviews" "PrReview/WaitingMergeability" daemonObservation
          :: PrReviewReviewerIndexedObservation PrReviewReviewerIndexedCheckingReviews PrReviewReviewerIndexedWaitingMergeability
  assert "indexed workflow PR-review reviewer rejects invalid observation like facade" $
    case
      ( prReviewObserve state facadeObservation
      , workflowObserve @MoifoldSpec state daemonObservation
      , workflowPlanObservation @MoifoldSpec state daemonObservation
      , IndexedWorkflow.indexedWorkflowObserve @PrReviewReviewerIndexedSpec indexedState indexedObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @PrReviewReviewerIndexedSpec indexedState indexedObservation
      )
      of
      (Left facadeFailure, Left compatibilityFailure, Left compatibilityPlanFailure, Left indexedFailure, Left indexedPlanFailure) ->
        compatibilityFailure == facadeFailure
          && compatibilityPlanFailure == facadeFailure
          && indexedFailure == facadeFailure
          && indexedPlanFailure == facadeFailure
      _ -> False

prReviewReviewerIndexedClassifierCase
  :: forall (target :: Type).
     String
  -> PrReviewReviewerIndexedFixture
  -> WorkflowAgent.AgentRole Text PrReviewObservation
  -> AppServerTurn
  -> WorkflowAgent.AgentOutputClass
  -> PrReviewObservation
  -> Text
  -> WatcherEvent
  -> PrReviewReviewerIndexedEvent PrReviewReviewerIndexedReviewingClean target
  -> (PlannedTransition MoifoldSpec -> Bool)
  -> IO Bool
prReviewReviewerIndexedClassifierCase title fixture role turn expectedClass expectedObservation expectedTargetLabel expectedEvent indexedEvent planCheck =
  case WorkflowAgent.classifyAgentRoleTurn role turn of
    Right classified
      | classified.classifiedOutputClass == expectedClass
          && classified.classifiedOutputPayload == expectedObservation ->
          prReviewReviewerIndexedSpecMatchesCompatibility
            title
            fixture
            expectedObservation
            ( PrReviewReviewerIndexedObservation
                "PrReview/ReviewingClean"
                expectedTargetLabel
                (DaemonPrReviewObservation expectedObservation)
                :: PrReviewReviewerIndexedObservation PrReviewReviewerIndexedReviewingClean target
            )
            expectedTargetLabel
            expectedEvent
            indexedEvent
            planCheck
    _ ->
      assert title False

prReviewReviewerIndexedSpecMatchesCompatibility
  :: forall (source :: Type) (target :: Type).
     String
  -> PrReviewReviewerIndexedFixture
  -> PrReviewObservation
  -> PrReviewReviewerIndexedObservation source target
  -> Text
  -> WatcherEvent
  -> PrReviewReviewerIndexedEvent source target
  -> (PlannedTransition MoifoldSpec -> Bool)
  -> IO Bool
prReviewReviewerIndexedSpecMatchesCompatibility title fixture facadeObservation indexedObservation expectedTargetLabel expectedEvent indexedEvent planCheck =
  assert title $
    case
      ( prReviewObserve state facadeObservation
      , workflowObserve @MoifoldSpec state observation
      , workflowPlanObservation @MoifoldSpec state observation
      , IndexedWorkflow.indexedWorkflowObserve @PrReviewReviewerIndexedSpec indexedState indexedObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @PrReviewReviewerIndexedSpec indexedState indexedObservation
      , workflowApplyEvent @MoifoldSpec state expectedEvent
      , IndexedWorkflow.indexedWorkflowApplyEvent @PrReviewReviewerIndexedSpec indexedState indexedEvent
      , workflowReplayEvents @MoifoldSpec (fixture.prReviewReviewerIndexedPrefix <> [expectedEvent])
      , IndexedWorkflow.indexedWorkflowReplayEvents @PrReviewReviewerIndexedSpec
          (fixture.prReviewReviewerIndexedTypedPrefix <> [IndexedWorkflow.SomeIndexedWorkflowEvent indexedEvent])
      )
      of
      ( Right facadeObserved
        , Right compatibilityObserved
        , Right compatibilityPlan
        , Right indexedObserved
        , Right indexedPlan
        , Right (appliedState, appliedEffects)
        , Right (PrReviewReviewerIndexedState indexedAppliedState, PrReviewReviewerIndexedEffectPlan indexedAppliedEffects)
        , Right compatibilityReplay
        , Right indexedReplay
        ) ->
          let PrReviewReviewerIndexedState indexedNextState =
                IndexedWorkflow.indexedWorkflowObservedState @PrReviewReviewerIndexedSpec indexedObserved
              indexedReplayResultValue = prReviewReviewerIndexedReplayResult indexedReplay
              wrappedTransition = IndexedWorkflow.SomeIndexedPlannedTransition indexedPlan
              fullCompatibilityPlan = compatibilityPlan.plannedPreCommitEffects <> compatibilityPlan.plannedPostCommitEffects
              indexedFullPlan =
                PrReviewReviewerIndexedEffectPlan fullCompatibilityPlan
                  :: PrReviewReviewerIndexedEffectPlan source target
           in facadeObserved.prReviewTickEvent == compatibilityObserved.observedEvent
                && facadeObserved.prReviewTickEffects == compatibilityObserved.observedEffects
                && sameWatcherStateShape facadeObserved.prReviewTickState compatibilityObserved.observedState
                && compatibilityObserved.observedEvent == expectedEvent
                && prReviewReviewerIndexedTransitionEvent indexedPlan == compatibilityPlan.plannedEvent
                && prReviewReviewerIndexedTransitionEvent indexedPlan == expectedEvent
                && IndexedWorkflow.someIndexedWorkflowTransitionSourceLabel @PrReviewReviewerIndexedSpec wrappedTransition == workflowStateLabel @MoifoldSpec state
                && IndexedWorkflow.someIndexedWorkflowTransitionTargetLabel @PrReviewReviewerIndexedSpec wrappedTransition == expectedTargetLabel
                && workflowStateLabel @MoifoldSpec indexedNextState == workflowStateLabel @MoifoldSpec compatibilityObserved.observedState
                && sameWatcherStateShape compatibilityObserved.observedState indexedNextState
                && sameWatcherStateShape compatibilityObserved.observedState appliedState
                && sameWatcherStateShape appliedState indexedAppliedState
                && prReviewReviewerIndexedTransitionPreCommitEffects indexedPlan == compatibilityPlan.plannedPreCommitEffects
                && prReviewReviewerIndexedTransitionPostCommitEffects indexedPlan == compatibilityPlan.plannedPostCommitEffects
                && fullCompatibilityPlan == compatibilityObserved.observedEffects
                && appliedEffects == fullCompatibilityPlan
                && indexedAppliedEffects == fullCompatibilityPlan
                && planCheck compatibilityPlan
                && IndexedWorkflow.indexedWorkflowPlannedTransitionPreCommitEffectLabels @PrReviewReviewerIndexedSpec indexedPlan
                  == fmap (workflowEffectLabel @MoifoldSpec) compatibilityPlan.plannedPreCommitEffects
                && IndexedWorkflow.indexedWorkflowPlannedTransitionPostCommitEffectLabels @PrReviewReviewerIndexedSpec indexedPlan
                  == fmap (workflowEffectLabel @MoifoldSpec) compatibilityPlan.plannedPostCommitEffects
                && workflowValidateEffects @MoifoldSpec state fullCompatibilityPlan
                  == IndexedWorkflow.indexedWorkflowValidateEffects @PrReviewReviewerIndexedSpec indexedState indexedFullPlan
                && all
                  ( \effect ->
                      workflowEffectAllowed @MoifoldSpec state effect
                        == IndexedWorkflow.indexedWorkflowEffectAllowed @PrReviewReviewerIndexedSpec indexedState (PrReviewReviewerIndexedEffect effect)
                  )
                  fullCompatibilityPlan
                && sameWatcherStateShape compatibilityReplay.replayState indexedReplayResultValue.replayState
                && workflowStateLabel @MoifoldSpec compatibilityReplay.replayState == workflowStateLabel @MoifoldSpec indexedReplayResultValue.replayState
                && compatibilityReplay.replayEffects == indexedReplayResultValue.replayEffects
      _ -> False
 where
  state = fixture.prReviewReviewerIndexedStateValue
  indexedState =
    PrReviewReviewerIndexedState state
      :: PrReviewReviewerIndexedState source
  observation = DaemonPrReviewObservation facadeObservation

effectTagPlan :: [EffectTag] -> PlannedTransition MoifoldSpec -> Bool
effectTagPlan expectedTags planned =
  fmap effectTag (planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects) == expectedTags
