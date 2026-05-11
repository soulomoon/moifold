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

module WorkflowDocsMigrationSpec
  ( workflowDocsMigrationTests
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
import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))
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
import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog
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

workflowDocsMigrationTests :: IO Bool
workflowDocsMigrationTests =
  sequenceAnd
    [ workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions
    , workflowDocsMigrationIndexedLawMatchesUnindexedDraftReplayTerminalAndPermissions
    , workflowDocsMigrationIndexedSpecMatchesCompatibilityForDraft
    , workflowDocsMigrationIndexedSpecMatchesCompatibilityForValidationAndBlocked
    , workflowDocsMigrationIndexedSpecPreservesPermissionsAndFixtureCodec
    , workflowDocsMigrationIndexedDryRunAndDaemonParity
    , workflowDocsMigrationSpecProvesSecondWorkflow
    , workflowDocsMigrationPermissionAndPartitionContracts
    , workflowDocsMigrationEventCodecFixtureContract
    , workflowDocsMigrationFixtureFailureReportsThroughCore
    , workflowDocsMigrationAgentRoleClassifiesCompleteOutput
    , workflowDocsMigrationUsesCoreExecutionContracts
    ]


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

workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions :: IO Bool
workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions = do
  let config =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      turnRef = WorkflowAgent.TurnRef (ThreadId "docs-thread") (TurnId "docs-turn")
      events =
        [ DocsMigration.DocsMigrationInitialized config
        , DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")
        ]
      activeState = DocsMigration.DocsMigrationTurnActive config turnRef
      output = DocsMigration.DocsMigrationOutput "draft markdown" "draft ready"
      observation =
        DocsMigration.DocsMigrationAgentReturned
          (WorkflowAgent.ClassifiedAgentOutput WorkflowAgent.AgentComplete output)
      expectedEvent = DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
      expectedState = DocsMigration.DocsMigrationDraftReady config "draft markdown"
      expectedEffects =
        [ DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidation "docs/target.md"
        ]
      fullEvents = events <> [expectedEvent]
      directReplay = DocsMigration.replayDocsMigrationEvents fullEvents
      detailedReplay = WorkflowEventLog.replayWorkflowEventLogDetailed @DocsMigration.DocsMigrationSpec id fullEvents
      dryRunResult = DocsMigration.runDocsMigrationObservedDryRun events observation
      expectedActions =
        [ DocsMigration.WriteDocsMigrationDraftAction "docs/target.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidationAction "docs/target.md"
        ]
      expectedEffectHistory =
        [ [DocsMigration.StartDocsMigrationTurn config]
        , []
        , expectedEffects
        ]
      wrongTargetEffects =
        [ DocsMigration.WriteDocsMigrationDraft "docs/wrong.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidation "docs/target.md"
        ]
      partialEffects =
        [DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown"]
  results <-
    sequence
      [ assert "workflow docs-migration law observe and plan agree" $
          case (workflowObserve @DocsMigration.DocsMigrationSpec activeState observation, workflowPlanObservation @DocsMigration.DocsMigrationSpec activeState observation) of
            (Right observed, Right planned) ->
              observed.docsMigrationTickEvent == expectedEvent
                && planned.plannedEvent == observed.docsMigrationTickEvent
                && observed.docsMigrationTickState == expectedState
                && planned.plannedPreCommitEffects == []
                && planned.plannedPostCommitEffects == expectedEffects
                && planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects == observed.docsMigrationTickEffects
            _ -> False
      , assert "workflow docs-migration law apply planned event reaches observed state" $
          case (workflowObserve @DocsMigration.DocsMigrationSpec activeState observation, workflowPlanObservation @DocsMigration.DocsMigrationSpec activeState observation) of
            (Right observed, Right planned) ->
              case workflowApplyEvent @DocsMigration.DocsMigrationSpec activeState planned.plannedEvent of
                Right (appliedState, appliedEffects) ->
                  appliedState == observed.docsMigrationTickState
                    && appliedEffects == planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects
                Left _ -> False
            _ -> False
      , assert "workflow docs-migration law replay history matches detailed core replay" $
          case (directReplay, detailedReplay) of
            (Right direct, Right detailed) ->
              direct.docsMigrationReplayState == expectedState
                && detailed.workflowReplaySummaryState == expectedState
                && direct.docsMigrationReplayEffects == expectedEffectHistory
                && detailed.workflowReplaySummaryEffects == expectedEffectHistory
                && lastEffectPlanIs expectedEffects direct.docsMigrationReplayEffects
                && lastEffectPlanIs expectedEffects detailed.workflowReplaySummaryEffects
            _ -> False
      , assert "workflow docs-migration law permission accepts complete draft plan" $
          workflowValidateEffects @DocsMigration.DocsMigrationSpec activeState expectedEffects == Right ()
            && isRightUnit (WorkflowPermission.validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec activeState expectedEffects)
      , assert "workflow docs-migration law permission rejects partial draft plan" $
          case (workflowValidateEffects @DocsMigration.DocsMigrationSpec activeState partialEffects, WorkflowPermission.validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec activeState partialEffects) of
            (Left directReason, Left coreReason) ->
              "effect plan" `Text.isInfixOf` directReason
                && "effect plan" `Text.isInfixOf` coreReason.workflowPermissionReason
            _ -> False
      , assert "workflow docs-migration law permission rejects wrong target draft write" $
          case (workflowValidateEffects @DocsMigration.DocsMigrationSpec activeState wrongTargetEffects, WorkflowPermission.validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec activeState wrongTargetEffects) of
            (Left directReason, Left coreReason) ->
              "target" `Text.isInfixOf` directReason
                && coreReason.workflowPermissionEffectLabel == "write-docs-migration-draft"
                && "target" `Text.isInfixOf` coreReason.workflowPermissionReason
            _ -> False
      , assert "workflow docs-migration law dry-run preserves post-commit action reports" $
          case dryRunResult of
            Right dryRunTick ->
              let reportActions = fmap DocsMigration.docsMigrationActionReportAction dryRunTick.docsMigrationDaemonActionReports
                  compiledActions =
                    fmap
                      WorkflowExecution.workflowGenericPlannedAction
                      (WorkflowExecution.workflowGenericCompiledActions dryRunTick.docsMigrationDaemonCompiledEffects)
                  (preReports, postReports) =
                    WorkflowExecution.partitionWorkflowGenericActionReports
                      dryRunTick.docsMigrationDaemonCompiledEffects
                      dryRunTick.docsMigrationDaemonActionReports
               in dryRunTick.docsMigrationDaemonCommittedEvents == []
                    && all ((== DryRunActions) . DocsMigration.docsMigrationActionReportMode) dryRunTick.docsMigrationDaemonActionReports
                    && not (any DocsMigration.docsMigrationActionReportExecuted dryRunTick.docsMigrationDaemonActionReports)
                    && null preReports
                    && postReports == dryRunTick.docsMigrationDaemonActionReports
                    && null (WorkflowEventLog.workflowAuditPreCommitReports dryRunTick.docsMigrationDaemonAudit)
                    && WorkflowEventLog.workflowAuditPostCommitReports dryRunTick.docsMigrationDaemonAudit == dryRunTick.docsMigrationDaemonActionReports
                    && WorkflowEventLog.workflowAuditCommittedEventLabel dryRunTick.docsMigrationDaemonAudit == Nothing
                    && reportActions == expectedActions
                    && compiledActions == expectedActions
            Left _ -> False
      ]
  pure (and results)

workflowDocsMigrationIndexedLawMatchesUnindexedDraftReplayTerminalAndPermissions :: IO Bool
workflowDocsMigrationIndexedLawMatchesUnindexedDraftReplayTerminalAndPermissions = do
  let config =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      turnRef = WorkflowAgent.TurnRef (ThreadId "docs-thread") (TurnId "docs-turn")
      events =
        [ DocsMigration.DocsMigrationInitialized config
        , DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")
        ]
      activeState = DocsMigration.DocsMigrationTurnActive config turnRef
      readyState = DocsMigration.DocsMigrationReady config
      completeState = DocsMigration.DocsMigrationComplete "done"
      blockedState = DocsMigration.DocsMigrationBlocked "blocked"
      output = DocsMigration.DocsMigrationOutput "draft markdown" "draft ready"
      observation =
        DocsMigration.DocsMigrationAgentReturned
          (WorkflowAgent.ClassifiedAgentOutput WorkflowAgent.AgentComplete output)
      expectedEvent = DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
      expectedEffects =
        [ DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidation "docs/target.md"
        ]
      indexedState =
        DocsMigration.DocsMigrationIndexedState activeState
          :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedTurnActive
      indexedObservation =
        DocsMigration.DocsMigrationIndexedObservation "turn-active" "draft-ready" observation
          :: DocsMigration.DocsMigrationIndexedObservation DocsMigration.DocsMigrationIndexedTurnActive DocsMigration.DocsMigrationIndexedDraftReady
      indexedEvents =
        [ IndexedWorkflow.SomeIndexedWorkflowEvent
            ( DocsMigration.DocsMigrationIndexedEvent "uninitialized" "ready" (DocsMigration.DocsMigrationInitialized config)
                :: DocsMigration.DocsMigrationIndexedEvent DocsMigration.DocsMigrationIndexedUninitialized DocsMigration.DocsMigrationIndexedReady
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( DocsMigration.DocsMigrationIndexedEvent "ready" "turn-active" (DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn"))
                :: DocsMigration.DocsMigrationIndexedEvent DocsMigration.DocsMigrationIndexedReady DocsMigration.DocsMigrationIndexedTurnActive
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( DocsMigration.DocsMigrationIndexedEvent "turn-active" "draft-ready" expectedEvent
                :: DocsMigration.DocsMigrationIndexedEvent DocsMigration.DocsMigrationIndexedTurnActive DocsMigration.DocsMigrationIndexedDraftReady
            )
        ]
      activeIndexedState =
        DocsMigration.DocsMigrationIndexedState activeState
          :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedTurnActive
      readyIndexedState =
        DocsMigration.DocsMigrationIndexedState readyState
          :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedReady
      completeIndexedState =
        DocsMigration.DocsMigrationIndexedState completeState
          :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedComplete
      blockedIndexedState =
        DocsMigration.DocsMigrationIndexedState blockedState
          :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedBlocked
      allowedIndexedPlan =
        DocsMigration.DocsMigrationIndexedEffectPlan expectedEffects
          :: DocsMigration.DocsMigrationIndexedEffectPlan DocsMigration.DocsMigrationIndexedTurnActive DocsMigration.DocsMigrationIndexedDraftReady
      rejectedReadyIndexedPlan =
        DocsMigration.DocsMigrationIndexedEffectPlan expectedEffects
          :: DocsMigration.DocsMigrationIndexedEffectPlan DocsMigration.DocsMigrationIndexedReady DocsMigration.DocsMigrationIndexedDraftReady
      allowedIndexedEffect =
        DocsMigration.DocsMigrationIndexedEffect (DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown")
          :: DocsMigration.DocsMigrationIndexedEffect DocsMigration.DocsMigrationIndexedTurnActive DocsMigration.DocsMigrationIndexedDraftReady
      rejectedReadyIndexedEffect =
        DocsMigration.DocsMigrationIndexedEffect (DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown")
          :: DocsMigration.DocsMigrationIndexedEffect DocsMigration.DocsMigrationIndexedReady DocsMigration.DocsMigrationIndexedDraftReady
  assert "indexed docs-migration law matches unindexed draft replay terminal and permissions" $
    case
      ( workflowObserve @DocsMigration.DocsMigrationSpec activeState observation
      , workflowPlanObservation @DocsMigration.DocsMigrationSpec activeState observation
      , IndexedWorkflow.indexedWorkflowObserve @DocsMigration.DocsMigrationSpec indexedState indexedObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @DocsMigration.DocsMigrationSpec indexedState indexedObservation
      , workflowReplayEvents @DocsMigration.DocsMigrationSpec (events <> [expectedEvent])
      , workflowReplayEvents @DocsMigration.DocsMigrationSpec (events <> [expectedEvent])
      , IndexedWorkflow.indexedWorkflowReplayEvents @DocsMigration.DocsMigrationSpec indexedEvents
      , IndexedWorkflow.indexedWorkflowReplayEvents @DocsMigration.DocsMigrationSpec indexedEvents
      )
      of
      (Right observed, Right planned, Right indexedObserved, Right indexedPlan, Right replay, Right replayAgain, Right indexedReplay, Right indexedReplayAgain) ->
        let DocsMigration.DocsMigrationIndexedState indexedObservedState =
              IndexedWorkflow.indexedWorkflowObservedState @DocsMigration.DocsMigrationSpec indexedObserved
            indexedReplayValue = docsMigrationIndexedReplayResult indexedReplay
            indexedReplayAgainValue = docsMigrationIndexedReplayResult indexedReplayAgain
            wrappedTransition = IndexedWorkflow.SomeIndexedPlannedTransition indexedPlan
         in observed.docsMigrationTickEvent == planned.plannedEvent
              && docsMigrationIndexedTransitionEvent indexedPlan == planned.plannedEvent
              && observed.docsMigrationTickState == indexedObservedState
              && planned.plannedPreCommitEffects == []
              && docsMigrationIndexedTransitionPreCommitEffects indexedPlan == planned.plannedPreCommitEffects
              && docsMigrationIndexedTransitionPostCommitEffects indexedPlan == planned.plannedPostCommitEffects
              && planned.plannedPostCommitEffects == expectedEffects
              && IndexedWorkflow.someIndexedWorkflowTransitionEventLabel @DocsMigration.DocsMigrationSpec wrappedTransition
                == workflowEventLabel @DocsMigration.DocsMigrationSpec expectedEvent
              && IndexedWorkflow.someIndexedWorkflowTransitionSourceLabel @DocsMigration.DocsMigrationSpec wrappedTransition == "turn-active"
              && IndexedWorkflow.someIndexedWorkflowTransitionTargetLabel @DocsMigration.DocsMigrationSpec wrappedTransition == "draft-ready"
              && IndexedWorkflow.someIndexedWorkflowTransitionPreCommitEffectLabels @DocsMigration.DocsMigrationSpec wrappedTransition == []
              && IndexedWorkflow.someIndexedWorkflowTransitionPostCommitEffectLabels @DocsMigration.DocsMigrationSpec wrappedTransition
                == fmap (workflowEffectLabel @DocsMigration.DocsMigrationSpec) expectedEffects
              && workflowStateLabel @DocsMigration.DocsMigrationSpec (workflowReplayState @DocsMigration.DocsMigrationSpec replay)
                == IndexedWorkflow.someIndexedWorkflowReplayStateLabel @DocsMigration.DocsMigrationSpec indexedReplay
              && workflowIsTerminal @DocsMigration.DocsMigrationSpec completeState
                == IndexedWorkflow.indexedWorkflowIsTerminal @DocsMigration.DocsMigrationSpec completeIndexedState
              && workflowIsTerminal @DocsMigration.DocsMigrationSpec blockedState
                == IndexedWorkflow.indexedWorkflowIsTerminal @DocsMigration.DocsMigrationSpec blockedIndexedState
              && workflowIsTerminal @DocsMigration.DocsMigrationSpec activeState
                == IndexedWorkflow.indexedWorkflowIsTerminal @DocsMigration.DocsMigrationSpec activeIndexedState
              && workflowReplayState @DocsMigration.DocsMigrationSpec replay == workflowReplayState @DocsMigration.DocsMigrationSpec replayAgain
              && replay.docsMigrationReplayEffects == replayAgain.docsMigrationReplayEffects
              && indexedReplayValue.docsMigrationReplayState == indexedReplayAgainValue.docsMigrationReplayState
              && indexedReplayValue.docsMigrationReplayEffects == indexedReplayAgainValue.docsMigrationReplayEffects
              && IndexedWorkflow.indexedWorkflowValidateEffects @DocsMigration.DocsMigrationSpec activeIndexedState allowedIndexedPlan
                == workflowValidateEffects @DocsMigration.DocsMigrationSpec activeState expectedEffects
              && IndexedWorkflow.indexedWorkflowEffectAllowed @DocsMigration.DocsMigrationSpec activeIndexedState allowedIndexedEffect
                == workflowEffectAllowed @DocsMigration.DocsMigrationSpec activeState (DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown")
              && IndexedWorkflow.indexedWorkflowValidateEffects @DocsMigration.DocsMigrationSpec readyIndexedState rejectedReadyIndexedPlan
                == workflowValidateEffects @DocsMigration.DocsMigrationSpec readyState expectedEffects
              && IndexedWorkflow.indexedWorkflowEffectAllowed @DocsMigration.DocsMigrationSpec readyIndexedState rejectedReadyIndexedEffect
                == workflowEffectAllowed @DocsMigration.DocsMigrationSpec readyState (DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown")
      _ -> False
workflowDocsMigrationIndexedSpecMatchesCompatibilityForDraft :: IO Bool
workflowDocsMigrationIndexedSpecMatchesCompatibilityForDraft = do
  let config =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      turnRef = WorkflowAgent.TurnRef (ThreadId "docs-thread") (TurnId "docs-turn")
      activeState = DocsMigration.DocsMigrationTurnActive config turnRef
      output = DocsMigration.DocsMigrationOutput "draft markdown" "draft ready"
      observation =
        DocsMigration.DocsMigrationAgentReturned
          (WorkflowAgent.ClassifiedAgentOutput WorkflowAgent.AgentComplete output)
      expectedEvent = DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
      expectedState = DocsMigration.DocsMigrationDraftReady config "draft markdown"
      expectedEffects =
        [ DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidation "docs/target.md"
        ]
      events =
        [ DocsMigration.DocsMigrationInitialized config
        , DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")
        ]
      indexedState =
        DocsMigration.DocsMigrationIndexedState activeState
          :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedTurnActive
      indexedObservation =
        DocsMigration.DocsMigrationIndexedObservation "turn-active" "draft-ready" observation
          :: DocsMigration.DocsMigrationIndexedObservation DocsMigration.DocsMigrationIndexedTurnActive DocsMigration.DocsMigrationIndexedDraftReady
      indexedEvents =
        [ IndexedWorkflow.SomeIndexedWorkflowEvent
            ( DocsMigration.DocsMigrationIndexedEvent "uninitialized" "ready" (DocsMigration.DocsMigrationInitialized config)
                :: DocsMigration.DocsMigrationIndexedEvent DocsMigration.DocsMigrationIndexedUninitialized DocsMigration.DocsMigrationIndexedReady
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( DocsMigration.DocsMigrationIndexedEvent "ready" "turn-active" (DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn"))
                :: DocsMigration.DocsMigrationIndexedEvent DocsMigration.DocsMigrationIndexedReady DocsMigration.DocsMigrationIndexedTurnActive
            )
        , IndexedWorkflow.SomeIndexedWorkflowEvent
            ( DocsMigration.DocsMigrationIndexedEvent "turn-active" "draft-ready" expectedEvent
                :: DocsMigration.DocsMigrationIndexedEvent DocsMigration.DocsMigrationIndexedTurnActive DocsMigration.DocsMigrationIndexedDraftReady
            )
        ]
      expectedEffectHistory =
        [ [DocsMigration.StartDocsMigrationTurn config]
        , []
        , expectedEffects
        ]
  assert "indexed docs-migration draft adapter matches compatibility facade" $
    case
      ( workflowObserve @DocsMigration.DocsMigrationSpec activeState observation
      , workflowPlanObservation @DocsMigration.DocsMigrationSpec activeState observation
      , IndexedWorkflow.indexedWorkflowObserve @DocsMigration.DocsMigrationSpec indexedState indexedObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @DocsMigration.DocsMigrationSpec indexedState indexedObservation
      , DocsMigration.replayDocsMigrationEvents (events <> [expectedEvent])
      , IndexedWorkflow.indexedWorkflowReplayEvents @DocsMigration.DocsMigrationSpec indexedEvents
      )
      of
      (Right compatibilityObserved, Right compatibilityPlan, Right indexedObserved, Right indexedPlan, Right compatibilityReplay, Right indexedReplay) ->
        let DocsMigration.DocsMigrationIndexedState indexedNextState =
              IndexedWorkflow.indexedWorkflowObservedState @DocsMigration.DocsMigrationSpec indexedObserved
            indexedReplayValue = docsMigrationIndexedReplayResult indexedReplay
            wrappedTransition = IndexedWorkflow.SomeIndexedPlannedTransition indexedPlan
         in compatibilityObserved.docsMigrationTickEvent == expectedEvent
              && compatibilityObserved.docsMigrationTickState == expectedState
              && compatibilityPlan.plannedEvent == expectedEvent
              && compatibilityPlan.plannedPreCommitEffects == []
              && compatibilityPlan.plannedPostCommitEffects == expectedEffects
              && docsMigrationIndexedTransitionEvent indexedPlan == compatibilityPlan.plannedEvent
              && indexedNextState == expectedState
              && docsMigrationIndexedTransitionPreCommitEffects indexedPlan == compatibilityPlan.plannedPreCommitEffects
              && docsMigrationIndexedTransitionPostCommitEffects indexedPlan == compatibilityPlan.plannedPostCommitEffects
              && IndexedWorkflow.someIndexedWorkflowTransitionEventLabel @DocsMigration.DocsMigrationSpec wrappedTransition == "docs-migration-draft-produced"
              && IndexedWorkflow.someIndexedWorkflowTransitionSourceLabel @DocsMigration.DocsMigrationSpec wrappedTransition == "turn-active"
              && IndexedWorkflow.someIndexedWorkflowTransitionTargetLabel @DocsMigration.DocsMigrationSpec wrappedTransition == "draft-ready"
              && IndexedWorkflow.someIndexedWorkflowTransitionPreCommitEffectLabels @DocsMigration.DocsMigrationSpec wrappedTransition == []
              && IndexedWorkflow.someIndexedWorkflowTransitionPostCommitEffectLabels @DocsMigration.DocsMigrationSpec wrappedTransition == ["write-docs-migration-draft", "run-docs-migration-validation"]
              && compatibilityReplay.docsMigrationReplayState == expectedState
              && indexedReplayValue.docsMigrationReplayState == compatibilityReplay.docsMigrationReplayState
              && indexedReplayValue.docsMigrationReplayEffects == expectedEffectHistory
              && indexedReplayValue.docsMigrationReplayEffects == compatibilityReplay.docsMigrationReplayEffects
      _ -> False

workflowDocsMigrationIndexedSpecMatchesCompatibilityForValidationAndBlocked :: IO Bool
workflowDocsMigrationIndexedSpecMatchesCompatibilityForValidationAndBlocked = do
  let config =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      turnRef = WorkflowAgent.TurnRef (ThreadId "docs-thread") (TurnId "docs-turn")
      activeState = DocsMigration.DocsMigrationTurnActive config turnRef
      draftState = DocsMigration.DocsMigrationDraftReady config "draft markdown"
      validationObservation = DocsMigration.DocsMigrationValidationReturned True "validation passed"
      blockedObservation =
        DocsMigration.DocsMigrationAgentReturned
          (WorkflowAgent.ClassifiedAgentOutput WorkflowAgent.AgentBlocked (DocsMigration.DocsMigrationOutput "" "agent blocked"))
      validationIndexedState =
        DocsMigration.DocsMigrationIndexedState draftState
          :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedDraftReady
      validationIndexedObservation =
        DocsMigration.DocsMigrationIndexedObservation "draft-ready" "validated" validationObservation
          :: DocsMigration.DocsMigrationIndexedObservation DocsMigration.DocsMigrationIndexedDraftReady DocsMigration.DocsMigrationIndexedValidated
      blockedIndexedState =
        DocsMigration.DocsMigrationIndexedState activeState
          :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedTurnActive
      blockedIndexedObservation =
        DocsMigration.DocsMigrationIndexedObservation "turn-active" "blocked" blockedObservation
          :: DocsMigration.DocsMigrationIndexedObservation DocsMigration.DocsMigrationIndexedTurnActive DocsMigration.DocsMigrationIndexedBlocked
  assert "indexed docs-migration validation and blocked adapters preserve stop effects and labels" $
    case
      ( workflowPlanObservation @DocsMigration.DocsMigrationSpec draftState validationObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @DocsMigration.DocsMigrationSpec validationIndexedState validationIndexedObservation
      , workflowObserve @DocsMigration.DocsMigrationSpec draftState validationObservation
      , IndexedWorkflow.indexedWorkflowObserve @DocsMigration.DocsMigrationSpec validationIndexedState validationIndexedObservation
      , workflowPlanObservation @DocsMigration.DocsMigrationSpec activeState blockedObservation
      , IndexedWorkflow.indexedWorkflowPlanObservation @DocsMigration.DocsMigrationSpec blockedIndexedState blockedIndexedObservation
      , workflowObserve @DocsMigration.DocsMigrationSpec activeState blockedObservation
      , IndexedWorkflow.indexedWorkflowObserve @DocsMigration.DocsMigrationSpec blockedIndexedState blockedIndexedObservation
      )
      of
      (Right validationPlan, Right indexedValidationPlan, Right validationObserved, Right indexedValidationObserved, Right blockedPlan, Right indexedBlockedPlan, Right blockedObserved, Right indexedBlockedObserved) ->
        let DocsMigration.DocsMigrationIndexedState indexedValidationState =
              IndexedWorkflow.indexedWorkflowObservedState @DocsMigration.DocsMigrationSpec indexedValidationObserved
            DocsMigration.DocsMigrationIndexedState indexedBlockedState =
              IndexedWorkflow.indexedWorkflowObservedState @DocsMigration.DocsMigrationSpec indexedBlockedObserved
            validationWrapped = IndexedWorkflow.SomeIndexedPlannedTransition indexedValidationPlan
            blockedWrapped = IndexedWorkflow.SomeIndexedPlannedTransition indexedBlockedPlan
         in validationObserved.docsMigrationTickState == DocsMigration.DocsMigrationValidated config "validation passed"
              && indexedValidationState == validationObserved.docsMigrationTickState
              && docsMigrationIndexedTransitionEvent indexedValidationPlan == validationPlan.plannedEvent
              && docsMigrationIndexedTransitionPostCommitEffects indexedValidationPlan == [DocsMigration.StopDocsMigrationDaemon]
              && docsMigrationIndexedTransitionPostCommitEffects indexedValidationPlan == validationPlan.plannedPostCommitEffects
              && IndexedWorkflow.someIndexedWorkflowTransitionSourceLabel @DocsMigration.DocsMigrationSpec validationWrapped == "draft-ready"
              && IndexedWorkflow.someIndexedWorkflowTransitionTargetLabel @DocsMigration.DocsMigrationSpec validationWrapped == "validated"
              && IndexedWorkflow.someIndexedWorkflowTransitionPostCommitEffectLabels @DocsMigration.DocsMigrationSpec validationWrapped == ["stop-docs-migration-daemon"]
              && not (IndexedWorkflow.indexedWorkflowIsTerminal @DocsMigration.DocsMigrationSpec (DocsMigration.DocsMigrationIndexedState indexedValidationState :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedValidated))
              && blockedObserved.docsMigrationTickState == DocsMigration.DocsMigrationBlocked "agent blocked"
              && indexedBlockedState == blockedObserved.docsMigrationTickState
              && docsMigrationIndexedTransitionEvent indexedBlockedPlan == blockedPlan.plannedEvent
              && docsMigrationIndexedTransitionPostCommitEffects indexedBlockedPlan == [DocsMigration.StopDocsMigrationDaemon]
              && docsMigrationIndexedTransitionPostCommitEffects indexedBlockedPlan == blockedPlan.plannedPostCommitEffects
              && IndexedWorkflow.someIndexedWorkflowTransitionSourceLabel @DocsMigration.DocsMigrationSpec blockedWrapped == "turn-active"
              && IndexedWorkflow.someIndexedWorkflowTransitionTargetLabel @DocsMigration.DocsMigrationSpec blockedWrapped == "blocked"
              && IndexedWorkflow.someIndexedWorkflowTransitionPostCommitEffectLabels @DocsMigration.DocsMigrationSpec blockedWrapped == ["stop-docs-migration-daemon"]
              && IndexedWorkflow.indexedWorkflowIsTerminal @DocsMigration.DocsMigrationSpec (DocsMigration.DocsMigrationIndexedState indexedBlockedState :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedBlocked)
      _ -> False

workflowDocsMigrationIndexedSpecPreservesPermissionsAndFixtureCodec :: IO Bool
workflowDocsMigrationIndexedSpecPreservesPermissionsAndFixtureCodec = do
  let config =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      readyState = DocsMigration.DocsMigrationReady config
      activeState =
        DocsMigration.DocsMigrationTurnActive
          config
          (WorkflowAgent.TurnRef (ThreadId "docs-thread") (TurnId "docs-turn"))
      readyIndexedState =
        DocsMigration.DocsMigrationIndexedState readyState
          :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedReady
      activeIndexedState =
        DocsMigration.DocsMigrationIndexedState activeState
          :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedTurnActive
      allowedEffects =
        [ DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidation "docs/target.md"
        ]
      partialEffects =
        [DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown"]
      wrongTargetEffects =
        [ DocsMigration.WriteDocsMigrationDraft "docs/wrong.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidation "docs/target.md"
        ]
      allowedPlan =
        DocsMigration.DocsMigrationIndexedEffectPlan allowedEffects
          :: DocsMigration.DocsMigrationIndexedEffectPlan DocsMigration.DocsMigrationIndexedTurnActive DocsMigration.DocsMigrationIndexedDraftReady
      partialPlan =
        DocsMigration.DocsMigrationIndexedEffectPlan partialEffects
          :: DocsMigration.DocsMigrationIndexedEffectPlan DocsMigration.DocsMigrationIndexedTurnActive DocsMigration.DocsMigrationIndexedDraftReady
      wrongTargetPlan =
        DocsMigration.DocsMigrationIndexedEffectPlan wrongTargetEffects
          :: DocsMigration.DocsMigrationIndexedEffectPlan DocsMigration.DocsMigrationIndexedTurnActive DocsMigration.DocsMigrationIndexedDraftReady
      disallowedStatePlan =
        DocsMigration.DocsMigrationIndexedEffectPlan allowedEffects
          :: DocsMigration.DocsMigrationIndexedEffectPlan DocsMigration.DocsMigrationIndexedReady DocsMigration.DocsMigrationIndexedDraftReady
      disallowedStateEffect =
        DocsMigration.DocsMigrationIndexedEffect (DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown")
          :: DocsMigration.DocsMigrationIndexedEffect DocsMigration.DocsMigrationIndexedReady DocsMigration.DocsMigrationIndexedDraftReady
      contract = DocsMigration.docsMigrationEventCodecContract
      fixture = DocsMigration.docsMigrationEventLogFixture
      encoded = fmap (WorkflowCodec.workflowCodecEncode contract) fixture
      decoded = traverse (WorkflowCodec.workflowCodecDecode contract) encoded
      codecRoundTripOk event =
        WorkflowCodec.validateWorkflowCodecRoundTrip contract event == Right ()
          && WorkflowCodec.validateWorkflowCodecEncodedTypeLabel contract event == Right ()
      indexedAllowedValidation =
        IndexedWorkflow.indexedWorkflowValidateEffects @DocsMigration.DocsMigrationSpec activeIndexedState allowedPlan
      indexedPartialValidation =
        IndexedWorkflow.indexedWorkflowValidateEffects @DocsMigration.DocsMigrationSpec activeIndexedState partialPlan
      indexedWrongTargetValidation =
        IndexedWorkflow.indexedWorkflowValidateEffects @DocsMigration.DocsMigrationSpec activeIndexedState wrongTargetPlan
      indexedDisallowedValidation =
        IndexedWorkflow.indexedWorkflowValidateEffects @DocsMigration.DocsMigrationSpec readyIndexedState disallowedStatePlan
      indexedDisallowedEffect =
        IndexedWorkflow.indexedWorkflowEffectAllowed @DocsMigration.DocsMigrationSpec readyIndexedState disallowedStateEffect
  results <-
    sequence
      [ assert "indexed docs-migration permissions accept allowed draft plan" $
          indexedAllowedValidation == workflowValidateEffects @DocsMigration.DocsMigrationSpec activeState allowedEffects
            && indexedAllowedValidation == Right ()
            && isRightUnit (WorkflowPermission.validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec activeState allowedEffects)
      , assert "indexed docs-migration permissions reject partial draft plan like compatibility" $
          case (indexedPartialValidation, workflowValidateEffects @DocsMigration.DocsMigrationSpec activeState partialEffects, WorkflowPermission.validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec activeState partialEffects) of
            (Left indexedReason, Left compatibilityReason, Left coreReason) ->
              indexedReason == compatibilityReason
                && "effect plan" `Text.isInfixOf` indexedReason
                && "effect plan" `Text.isInfixOf` coreReason.workflowPermissionReason
            _ -> False
      , assert "indexed docs-migration permissions reject wrong target plan like compatibility" $
          case (indexedWrongTargetValidation, workflowValidateEffects @DocsMigration.DocsMigrationSpec activeState wrongTargetEffects, WorkflowPermission.validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec activeState wrongTargetEffects) of
            (Left indexedReason, Left compatibilityReason, Left coreReason) ->
              indexedReason == compatibilityReason
                && "target" `Text.isInfixOf` indexedReason
                && coreReason.workflowPermissionEffectLabel == "write-docs-migration-draft"
            _ -> False
      , assert "indexed docs-migration permissions reject disallowed state like compatibility" $
          indexedDisallowedValidation == workflowValidateEffects @DocsMigration.DocsMigrationSpec readyState allowedEffects
            && indexedDisallowedEffect == workflowEffectAllowed @DocsMigration.DocsMigrationSpec readyState (DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown")
            && case WorkflowPermission.validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec readyState allowedEffects of
              Left coreReason -> "ready" `Text.isInfixOf` coreReason.workflowPermissionReason
              Right () -> False
      , assert "indexed docs-migration keeps fixture codec contract unchanged" $
          all codecRoundTripOk fixture
            && case decoded of
              Right decodedEvents ->
                case WorkflowEventLog.replayWorkflowEventLogDetailed @DocsMigration.DocsMigrationSpec id decodedEvents of
                  Right summary ->
                    WorkflowEventLog.validateEventLogFixtureContract
                      @DocsMigration.DocsMigrationSpec
                      DocsMigration.docsMigrationEventLogFixtureContract
                      summary
                      == Right ()
                  Left _failure -> False
              Left _failure -> False
      ]
  pure (and results)

workflowDocsMigrationIndexedDryRunAndDaemonParity :: IO Bool
workflowDocsMigrationIndexedDryRunAndDaemonParity = do
  calls <- newIORef []
  let record call = modifyIORef' calls (<> [call])
      config =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      events =
        [ DocsMigration.DocsMigrationInitialized config
        , DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")
        ]
      activeState =
        DocsMigration.DocsMigrationTurnActive
          config
          (WorkflowAgent.TurnRef (ThreadId "docs-thread") (TurnId "docs-turn"))
      output = DocsMigration.DocsMigrationOutput "draft markdown" "draft ready"
      observation =
        DocsMigration.DocsMigrationAgentReturned
          (WorkflowAgent.ClassifiedAgentOutput WorkflowAgent.AgentComplete output)
      interpreter =
        DocsMigration.DocsMigrationInterpreter
          { DocsMigration.docsMigrationStartTurn = \_config -> record "start-turn"
          , DocsMigration.docsMigrationWriteDraft = \path draft -> record ("write:" <> Text.pack path <> ":" <> draft)
          , DocsMigration.docsMigrationRunValidation = \path -> record ("validate:" <> Text.pack path)
          , DocsMigration.docsMigrationStopDaemon = record "stop"
          }
      expectedEvent = DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
      expectedState = DocsMigration.DocsMigrationDraftReady config "draft markdown"
      expectedEffects =
        [ DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidation "docs/target.md"
        ]
      expectedActions =
        [ DocsMigration.WriteDocsMigrationDraftAction "docs/target.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidationAction "docs/target.md"
        ]
      indexedState =
        DocsMigration.DocsMigrationIndexedState activeState
          :: DocsMigration.DocsMigrationIndexedState DocsMigration.DocsMigrationIndexedTurnActive
      indexedObservation =
        DocsMigration.DocsMigrationIndexedObservation "turn-active" "draft-ready" observation
          :: DocsMigration.DocsMigrationIndexedObservation DocsMigration.DocsMigrationIndexedTurnActive DocsMigration.DocsMigrationIndexedDraftReady
      compiledActions tick =
        fmap
          WorkflowExecution.workflowGenericPlannedAction
          (WorkflowExecution.workflowGenericCompiledActions tick.docsMigrationDaemonCompiledEffects)
      reportActions =
        fmap DocsMigration.docsMigrationActionReportAction . DocsMigration.docsMigrationDaemonActionReports
  executeResult <- DocsMigration.runDocsMigrationObservedExecute interpreter events observation
  executedCalls <- readIORef calls
  let dryRunResult = DocsMigration.runDocsMigrationObservedDryRun events observation
      indexedPlan = IndexedWorkflow.indexedWorkflowPlanObservation @DocsMigration.DocsMigrationSpec indexedState indexedObservation
  assert "indexed docs-migration dry-run and daemon helpers preserve compatibility output" $
    case (dryRunResult, executeResult, indexedPlan) of
      (Right dryRunTick, Right executeTick, Right indexedPlanned) ->
        DocsMigration.docsMigrationDaemonEvent dryRunTick == expectedEvent
          && DocsMigration.docsMigrationDaemonState dryRunTick == expectedState
          && DocsMigration.docsMigrationDaemonCommittedEvents dryRunTick == []
          && compiledActions dryRunTick == expectedActions
          && reportActions dryRunTick == expectedActions
          && all ((== DryRunActions) . DocsMigration.docsMigrationActionReportMode) dryRunTick.docsMigrationDaemonActionReports
          && not (any DocsMigration.docsMigrationActionReportExecuted dryRunTick.docsMigrationDaemonActionReports)
          && WorkflowEventLog.workflowAuditCommittedEventLabel dryRunTick.docsMigrationDaemonAudit == Nothing
          && DocsMigration.docsMigrationDaemonEvent executeTick == expectedEvent
          && DocsMigration.docsMigrationDaemonState executeTick == expectedState
          && DocsMigration.docsMigrationDaemonCommittedEvents executeTick == [expectedEvent]
          && compiledActions executeTick == expectedActions
          && reportActions executeTick == expectedActions
          && all ((== ExecuteActions) . DocsMigration.docsMigrationActionReportMode) executeTick.docsMigrationDaemonActionReports
          && all DocsMigration.docsMigrationActionReportExecuted executeTick.docsMigrationDaemonActionReports
          && WorkflowEventLog.workflowAuditCommittedEventLabel executeTick.docsMigrationDaemonAudit == Just "docs-migration-draft-produced"
          && executedCalls == ["write:docs/target.md:draft markdown", "validate:docs/target.md"]
          && reportActions executeTick == reportActions dryRunTick
          && docsMigrationIndexedTransitionEvent indexedPlanned == expectedEvent
          && docsMigrationIndexedTransitionPreCommitEffects indexedPlanned == []
          && docsMigrationIndexedTransitionPostCommitEffects indexedPlanned == expectedEffects
          && IndexedWorkflow.indexedWorkflowPlannedTransitionPostCommitEffectLabels @DocsMigration.DocsMigrationSpec indexedPlanned == ["write-docs-migration-draft", "run-docs-migration-validation"]
      _ -> False


workflowDocsMigrationSpecProvesSecondWorkflow :: IO Bool
workflowDocsMigrationSpecProvesSecondWorkflow = do
  let config =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      events =
        [ DocsMigration.DocsMigrationInitialized config
        , DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")
        , DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
        , DocsMigration.DocsMigrationValidationPassed "validation passed"
        , DocsMigration.DocsMigrationWorkflowCompleted "done"
        ]
  assert "workflow docs-migration spec replays as second non-PR workflow" $
    case DocsMigration.replayDocsMigrationEvents events of
      Right replay ->
        replay.docsMigrationReplayState == DocsMigration.DocsMigrationComplete "done"
          && case replay.docsMigrationReplayEffects of
            firstEffects : _ -> DocsMigration.StartDocsMigrationTurn config `elem` firstEffects
            [] -> False
      Left _ -> False

workflowDocsMigrationPermissionAndPartitionContracts :: IO Bool
workflowDocsMigrationPermissionAndPartitionContracts = do
  let config =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      readyState = DocsMigration.DocsMigrationReady config
      activeState =
        DocsMigration.DocsMigrationTurnActive
          config
          (WorkflowAgent.TurnRef (ThreadId "docs-thread") (TurnId "docs-turn"))
      event = DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
      effects =
        [ DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidation "docs/target.md"
        ]
      planned = workflowPlanTransition @DocsMigration.DocsMigrationSpec event effects
      compiled = DocsMigration.compileDocsMigrationEffectPlan (planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects)
      (preActions, postActions) = WorkflowExecution.partitionWorkflowGenericActions compiled
  results <-
    sequence
      [ assert "workflow docs-migration validates its initial start effect" $
          workflowValidateEffects @DocsMigration.DocsMigrationSpec readyState [DocsMigration.StartDocsMigrationTurn config] == Right ()
      , assert "workflow docs-migration validates active draft effects" $
          workflowValidateEffects @DocsMigration.DocsMigrationSpec activeState effects == Right ()
      , assert "workflow docs-migration rejects writes before the agent turn is active" $
          case workflowEffectAllowed @DocsMigration.DocsMigrationSpec readyState (DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft") of
            Left reason -> "ready" `Text.isInfixOf` reason
            Right () -> False
      , assert "workflow docs-migration rejects partial draft effect plans" $
          case workflowValidateEffects @DocsMigration.DocsMigrationSpec activeState [DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft"] of
            Left reason -> "effect plan" `Text.isInfixOf` reason
            Right () -> False
      , assert "workflow docs-migration planned transition follows post-commit metadata" $
          null planned.plannedPreCommitEffects
            && planned.plannedPostCommitEffects == effects
            && null preActions
            && length postActions == 2
      ]
  pure (and results)

workflowDocsMigrationEventCodecFixtureContract :: IO Bool
workflowDocsMigrationEventCodecFixtureContract = do
  let contract = DocsMigration.docsMigrationEventCodecContract
      fixture = DocsMigration.docsMigrationEventLogFixture
      encoded = fmap (WorkflowCodec.workflowCodecEncode contract) fixture
      decoded = traverse (WorkflowCodec.workflowCodecDecode contract) encoded
      codecRoundTripOk event =
        WorkflowCodec.validateWorkflowCodecRoundTrip contract event == Right ()
          && WorkflowCodec.validateWorkflowCodecEncodedTypeLabel contract event == Right ()
  assert "workflow docs-migration event codec validates fixture replay contract" $
    all codecRoundTripOk fixture
      && case decoded of
        Right decodedEvents ->
          case WorkflowEventLog.replayWorkflowEventLogDetailed @DocsMigration.DocsMigrationSpec id decodedEvents of
            Right summary ->
              WorkflowEventLog.validateEventLogFixtureContract
                @DocsMigration.DocsMigrationSpec
                DocsMigration.docsMigrationEventLogFixtureContract
                summary
                == Right ()
            Left _failure -> False
        Left _failure -> False

workflowDocsMigrationFixtureFailureReportsThroughCore :: IO Bool
workflowDocsMigrationFixtureFailureReportsThroughCore = do
  let config =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      badEvents =
        [ DocsMigration.DocsMigrationInitialized config
        , DocsMigration.DocsMigrationValidationPassed "too early"
        ]
      terminalEvents =
        DocsMigration.docsMigrationEventLogFixture
          <> [DocsMigration.DocsMigrationWorkflowBlocked "blocked after terminal"]
      blockedTerminalEvents =
        [ DocsMigration.DocsMigrationInitialized config
        , DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")
        , DocsMigration.DocsMigrationWorkflowBlocked "blocked by agent"
        , DocsMigration.DocsMigrationWorkflowCompleted "completed after blocked"
        ]
  results <-
    sequence
      [ assert "workflow docs-migration fixture failures report through core replay" $
          case WorkflowEventLog.replayWorkflowEventLogDetailed @DocsMigration.DocsMigrationSpec id badEvents of
            Left failure ->
              WorkflowEventLog.workflowReplayFailureEventIndex failure == 2
                && WorkflowEventLog.workflowReplayFailureEventLabel failure == "docs-migration-validation-passed"
                && WorkflowEventLog.workflowReplayFailurePriorStateLabel failure == Just "ready"
                && "ready" `Text.isInfixOf` WorkflowEventLog.workflowReplayFailureReason failure
            Right _summary -> False
      , assert "workflow docs-migration terminal states reject blocked transitions" $
          case WorkflowEventLog.replayWorkflowEventLogDetailed @DocsMigration.DocsMigrationSpec id terminalEvents of
            Left failure ->
              WorkflowEventLog.workflowReplayFailureEventIndex failure == length terminalEvents
                && WorkflowEventLog.workflowReplayFailureEventLabel failure == "docs-migration-blocked"
                && WorkflowEventLog.workflowReplayFailurePriorStateLabel failure == Just "complete"
            Right _summary -> False
      , assert "workflow docs-migration blocked terminal state rejects completion transitions" $
          case WorkflowEventLog.replayWorkflowEventLogDetailed @DocsMigration.DocsMigrationSpec id blockedTerminalEvents of
            Left failure ->
              WorkflowEventLog.workflowReplayFailureEventIndex failure == length blockedTerminalEvents
                && WorkflowEventLog.workflowReplayFailureEventLabel failure == "docs-migration-completed"
                && WorkflowEventLog.workflowReplayFailurePriorStateLabel failure == Just "blocked"
            Right _summary -> False
      ]
  pure (and results)

workflowDocsMigrationAgentRoleClassifiesCompleteOutput :: IO Bool
workflowDocsMigrationAgentRoleClassifiesCompleteOutput = do
  let turn =
        AppServerTurn
          (TurnId "docs-turn")
          "completed"
          (Just "{\"draft_markdown\":\"draft markdown\",\"summary\":\"draft ready\"}")
  assert "workflow docs-migration agent role classifies complete output" $
    case WorkflowAgent.classifyAgentRoleTurn DocsMigration.docsMigrationAgentRole turn of
      Right classified ->
        classified.classifiedOutputClass == WorkflowAgent.AgentComplete
          && classified.classifiedOutputPayload == DocsMigration.DocsMigrationOutput "draft markdown" "draft ready"
      Left _ -> False

workflowDocsMigrationUsesCoreExecutionContracts :: IO Bool
workflowDocsMigrationUsesCoreExecutionContracts = do
  calls <- newIORef []
  let record call = modifyIORef' calls (<> [call])
      config =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      events =
        [ DocsMigration.DocsMigrationInitialized config
        , DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")
        ]
      output = DocsMigration.DocsMigrationOutput "draft markdown" "draft ready"
      observation =
        DocsMigration.DocsMigrationAgentReturned
          (WorkflowAgent.ClassifiedAgentOutput WorkflowAgent.AgentComplete output)
      interpreter =
        DocsMigration.DocsMigrationInterpreter
          { DocsMigration.docsMigrationStartTurn = \_config -> record "start-turn"
          , DocsMigration.docsMigrationWriteDraft = \path draft -> record ("write:" <> Text.pack path <> ":" <> draft)
          , DocsMigration.docsMigrationRunValidation = \path -> record ("validate:" <> Text.pack path)
          , DocsMigration.docsMigrationStopDaemon = record "stop"
          }
      expectedEvent = DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
      expectedState = DocsMigration.DocsMigrationDraftReady config "draft markdown"
      reportActions = fmap DocsMigration.docsMigrationActionReportAction
      expectedActionOrder =
        [ DocsMigration.WriteDocsMigrationDraftAction "docs/target.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidationAction "docs/target.md"
        ]
  let dryRunResult = DocsMigration.runDocsMigrationObservedDryRun events observation
  dryRunCalls <- readIORef calls
  executeResult <- DocsMigration.runDocsMigrationObservedExecute interpreter events observation
  executedCalls <- readIORef calls
  assert "workflow docs-migration reuses core execution contracts" $
    case (dryRunResult, executeResult) of
      (Right dryRunTick, Right executeTick) ->
        DocsMigration.docsMigrationDaemonEvent dryRunTick == expectedEvent
          && DocsMigration.docsMigrationDaemonState dryRunTick == expectedState
          && DocsMigration.docsMigrationDaemonCommittedEvents dryRunTick == []
          && null dryRunCalls
          && all ((== DryRunActions) . DocsMigration.docsMigrationActionReportMode) dryRunTick.docsMigrationDaemonActionReports
          && not (any DocsMigration.docsMigrationActionReportExecuted dryRunTick.docsMigrationDaemonActionReports)
          && length (WorkflowExecution.workflowGenericCompiledActions dryRunTick.docsMigrationDaemonCompiledEffects) == 2
          && reportActions dryRunTick.docsMigrationDaemonActionReports == expectedActionOrder
          && null (WorkflowEventLog.workflowAuditPreCommitReports dryRunTick.docsMigrationDaemonAudit)
          && length (WorkflowEventLog.workflowAuditPostCommitReports dryRunTick.docsMigrationDaemonAudit) == 2
          && WorkflowEventLog.workflowAuditCommittedEventLabel dryRunTick.docsMigrationDaemonAudit == Nothing
          && DocsMigration.docsMigrationDaemonEvent executeTick == expectedEvent
          && DocsMigration.docsMigrationDaemonState executeTick == expectedState
          && DocsMigration.docsMigrationDaemonCommittedEvents executeTick == [expectedEvent]
          && all ((== ExecuteActions) . DocsMigration.docsMigrationActionReportMode) executeTick.docsMigrationDaemonActionReports
          && all DocsMigration.docsMigrationActionReportExecuted executeTick.docsMigrationDaemonActionReports
          && WorkflowExecution.workflowGenericCompiledActions executeTick.docsMigrationDaemonCompiledEffects == WorkflowExecution.workflowGenericCompiledActions dryRunTick.docsMigrationDaemonCompiledEffects
          && reportActions executeTick.docsMigrationDaemonActionReports == reportActions dryRunTick.docsMigrationDaemonActionReports
          && executedCalls == ["write:docs/target.md:draft markdown", "validate:docs/target.md"]
          && null (WorkflowEventLog.workflowAuditPreCommitReports executeTick.docsMigrationDaemonAudit)
          && reportActions (WorkflowEventLog.workflowAuditPostCommitReports executeTick.docsMigrationDaemonAudit) == expectedActionOrder
          && WorkflowEventLog.workflowAuditCommittedEventLabel executeTick.docsMigrationDaemonAudit == Just "docs-migration-draft-produced"
      _ -> False
