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

module WorkflowExecutionSpec
  ( workflowExecutionTests
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
import TestSupport.Workflow hiding (isRightUnit, lastEffectPlanIs, sameWatcherStateShape)

workflowExecutionTests :: IO Bool
workflowExecutionTests =
  sequenceAnd
    [ workflowPlannedTransitionPreservesObservedEffects
    , workflowPlannedTransitionPartitionsPostCommitEffects
    , workflowPrReviewMergeabilityPlannedTransitionKeepsMergePreCommitEffect
    , workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions
    , workflowDslWorkflowMAccumulationLaws
    , workflowDslAdvanceBuildsPhaseChangingTransition
    , workflowDslPrReviewFeedbackMatchesStateMachine
    , workflowDslTransitionLowersToPlannedTransition
    , workflowDslMoifoldProjectionParity
    , workflowDslDocsMigrationProjectionParity
    , workflowDslDocsMigrationDraftProducedPortParity
    , workflowDslIssuePlanningTurnCompletedPortParity
    , workflowDaemonCoreProjectsMoifoldAndDocsMigrationResults
    , workflowDaemonCoreProjectsObservedFailureBoundary
    , workflowTransactionDetailedFailuresRecordCommitBoundary
    , workflowTransactionDryRunExecuteParityUsesCommitBoundary
    , workflowExecutionMetadataCoversCurrentEffects
    , workflowExecutionCapabilityMetadataCoversCurrentEffects
    , workflowExecutionMetadataPartitionPreservesLegacyOrdering
    , workflowExecutionMetadataDryRunMatchesLegacy
    , workflowExecutionCoreCheckedActionsStopsOnFirstFailure
    , workflowExecutionCheckedActionsStopsOnHardFailure
    ]


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


issuePlanningIndexedConfig :: PlannerConfig
issuePlanningIndexedConfig =
  PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 4) [IssueNumber 12]

indexedPrReviewMergeabilityCleanObservation
  :: CommitSha
  -> PrReviewIndexedObservation PrReviewIndexedWaitingForMergeability PrReviewIndexedMerging
indexedPrReviewMergeabilityCleanObservation commit =
  PrReviewIndexedObservation
    "PrReview/WaitingMergeability"
    "PrReview/Merging"
    (DaemonPrReviewObservation (ObservedMergeabilityClean commit))

workflowPlannedTransitionPreservesObservedEffects :: IO Bool
workflowPlannedTransitionPreservesObservedEffects = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      state = SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle (ThreadId "worker")) (ReviewerIdle (ThreadId "reviewer")))
      evidence = reviewEvidenceFromSummaries ("fix review" :| []) (CommitSha "abc123")
      observation = DaemonPrReviewObservation (ObservedReviewFeedback evidence (TurnId "worker-turn"))
  assert "workflow planned-transition facade preserves observed event and effects" $
    case observeDaemonState state observation of
      Right observed ->
        let planned = legacyObservedPlannedTransition observed
         in planned.plannedEvent == observed.observedEvent
              && planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects == observed.observedEffects
      Left _ -> False

workflowPlannedTransitionPartitionsPostCommitEffects :: IO Bool
workflowPlannedTransitionPartitionsPostCommitEffects = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      idleCheckingState =
        SomeWatcherState
          (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      cleanEvidence = CleanReviewEvidence (CommitSha "abc123") "LGTM"
      waitingState =
        SomeWatcherState
          (PrWaitingForMergeability prConfig cleanEvidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      plannedFrom state observation =
        legacyObservedPlannedTransition <$> observeDaemonState state observation
  results <-
    sequence
      [ assert "workflow planned transition places blocked terminal effects post-commit" $
          case plannedFrom idleCheckingState (DaemonPrReviewObservation (ObservedPrReviewBlocked (BlockedReason "blocked"))) of
            Right planned ->
              hasEffect RecordBlockedTag planned.plannedPostCommitEffects
                && hasEffect StopDaemonTag planned.plannedPostCommitEffects
                && lacksEffect RecordBlockedTag planned.plannedPreCommitEffects
                && lacksEffect StopDaemonTag planned.plannedPreCommitEffects
                && planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects == observedEffectsFor idleCheckingState (DaemonPrReviewObservation (ObservedPrReviewBlocked (BlockedReason "blocked")))
            Left _ -> False
      , assert "workflow planned transition places mergeability retry sleep post-commit" $
          case plannedFrom waitingState (DaemonPrReviewObservation (ObservedMergeabilityRetry "pending")) of
            Right planned ->
              hasEffect SleepUntilNextPollTag planned.plannedPostCommitEffects
                && lacksEffect SleepUntilNextPollTag planned.plannedPreCommitEffects
                && planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects == observedEffectsFor waitingState (DaemonPrReviewObservation (ObservedMergeabilityRetry "pending"))
            Left _ -> False
      ]
  pure (and results)
 where
  observedEffectsFor state observation =
    case observeDaemonState state observation of
      Right observed -> observed.observedEffects
      Left _ -> []

workflowPrReviewMergeabilityPlannedTransitionKeepsMergePreCommitEffect :: IO Bool
workflowPrReviewMergeabilityPlannedTransitionKeepsMergePreCommitEffect = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      commit = CommitSha "abc123"
      cleanEvidence = CleanReviewEvidence commit "LGTM"
      state = SomeWatcherState (PrWaitingForMergeability prConfig cleanEvidence (WorkerIdle (ThreadId "worker")) (ReviewerIdle (ThreadId "reviewer")))
      observation = DaemonPrReviewObservation (ObservedMergeabilityClean commit)
  assert "workflow mergeability planned transition keeps merge effect pre-commit" $
    case observeDaemonState state observation of
      Right observed ->
        let planned = legacyObservedPlannedTransition observed
         in planned.plannedEvent == PrReviewMergeabilityClean commit
              && hasEffect MergePullRequestTag planned.plannedPreCommitEffects
              && null planned.plannedPostCommitEffects
              && planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects == observed.observedEffects
              && WorkflowPermission.validateMoifoldEffectPlan state planned.plannedPreCommitEffects == Right ()
      Left _ -> False


workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions :: IO Bool
workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions = do
  let repo = RepoName "soulomoon/mlf2"
      prNumberValue = PrNumber 6
      prConfig = PrConfig repo prNumberValue (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      commit = CommitSha "abc123"
      cleanEvidence = CleanReviewEvidence commit "LGTM"
      events =
        [ PrReviewInitialized prConfig workerThread reviewerThread
        , PrReviewNoUnresolvedFound commit (TurnId "reviewer-turn")
        , PrReviewCleanFound cleanEvidence []
        ]
      state =
        SomeWatcherState
          (PrWaitingForMergeability prConfig cleanEvidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      deniedState =
        SomeWatcherState
          (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      observation = DaemonPrReviewObservation (ObservedMergeabilityClean commit)
      indexedState =
        PrReviewIndexedState state
          :: PrReviewIndexedState PrReviewIndexedWaitingForMergeability
      indexedObservation = indexedPrReviewMergeabilityCleanObservation commit
      facadeObservation = WorkflowPrReviewMergeability.MergeabilityObservedClean commit
      expectedEvent = PrReviewMergeabilityClean commit
      expectedEffects = [SomeEffect (MergePullRequest prNumberValue cleanEvidence)]
      fullEvents = events <> [expectedEvent]
      directReplay = replayEventLog fullEvents
      genericReplay = workflowReplayEvents @MoifoldSpec fullEvents
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 731
      workflow = WorkflowExecution.compileWorkflowEffectPlanWithMetadata runtimeConfig expectedEffects
      legacy = compileEffectPlan runtimeConfig expectedEffects
      dryRunReports = WorkflowExecution.dryRunWorkflowCompiledEffectPlan workflow
      (preCommitActions, postCommitActions) = WorkflowExecution.partitionWorkflowActions workflow
      expectedAction = PlannedCommand (GhPrCleanReviewAndMerge repo prNumberValue cleanEvidence runtimeConfig.effectRuntimeMergeMethod)
      expectedDryRunReports =
        [ ActionExecutionReport
            { actionExecutionMode = DryRunActions
            , actionExecutionAction = expectedAction
            , actionExecutionResult = DryRunActionResult
            , actionExecutionOutcome = ActionSucceeded
            }
        ]
      stateMatchesExpected stateValue =
        case stateValue of
          SomeWatcherState (PrMerging actualConfig actualEvidence) ->
            actualConfig == prConfig && actualEvidence == cleanEvidence
          _ -> False
  results <-
    sequence
      [ assert "workflow PR-review mergeability law observe and plan agree" $
          case (workflowObserve @MoifoldSpec state observation, workflowPlanObservation @MoifoldSpec state observation) of
            (Right observed, Right planned) ->
              observed.observedEvent == expectedEvent
                && planned.plannedEvent == observed.observedEvent
                && stateMatchesExpected observed.observedState
                && planned.plannedPreCommitEffects == expectedEffects
                && planned.plannedPostCommitEffects == []
                && planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects == observed.observedEffects
            _ -> False
      , assert "workflow PR-review mergeability law apply planned event reaches observed state" $
          case (workflowObserve @MoifoldSpec state observation, workflowPlanObservation @MoifoldSpec state observation) of
            (Right observed, Right planned) ->
              case workflowApplyEvent @MoifoldSpec state planned.plannedEvent of
                Right (appliedState, appliedEffects) ->
                  sameWatcherStateShape appliedState observed.observedState
                    && stateMatchesExpected appliedState
                    && appliedEffects == planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects
                Left _ -> False
            _ -> False
      , assert "workflow PR-review mergeability law direct and generic replay match" $
          case (directReplay, genericReplay) of
            (Right direct, Right generic) ->
              sameWatcherStateShape direct.replayState generic.replayState
                && stateMatchesExpected direct.replayState
                && direct.replayEffects == generic.replayEffects
                && lastEffectPlanIs expectedEffects direct.replayEffects
                && lastEffectPlanIs expectedEffects generic.replayEffects
            _ -> False
      , assert "workflow PR-review mergeability law facade observation matches public path" $
          case (workflowObserve @MoifoldSpec state observation, WorkflowPrReviewMergeability.observePrReviewMergeability state facadeObservation) of
            (Right publicObserved, Right facadeObserved) ->
              publicObserved.observedEvent == facadeObserved.observedEvent
                && sameWatcherStateShape publicObserved.observedState facadeObserved.observedState
                && publicObserved.observedEffects == facadeObserved.observedEffects
            _ -> False
      , assert "workflow PR-review mergeability law permission accepts merge from mergeability state" $
          validatePhaseActionPlan state expectedEffects == Right ()
            && WorkflowPermission.validateMoifoldEffectPlan state expectedEffects == Right ()
            && isRightUnit (WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec state expectedEffects)
      , assert "workflow PR-review mergeability law permission rejects merge outside mergeability state" $
          case (validatePhaseActionPlan deniedState expectedEffects, WorkflowPermission.validateMoifoldEffectPlan deniedState expectedEffects, WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec deniedState expectedEffects) of
            (Left directError, Left facadeError, Left coreError) ->
              facadeError == directError
                && coreError.workflowPermissionEffectLabel == "MergePullRequest"
                && "effect is not allowed" `Text.isInfixOf` coreError.workflowPermissionReason
            _ -> False
      , assert "workflow PR-review mergeability law dry-run keeps merge pre-commit" $
          fmap WorkflowExecution.workflowPlannedAction preCommitActions == legacy.compiledActions
            && legacy.compiledActions == [expectedAction]
            && postCommitActions == []
            && dryRunReports == expectedDryRunReports
      , assert "indexed PR-review mergeability law exposes matching labels effects and terminal status" $
          case
            ( workflowObserve @MoifoldSpec state observation
            , workflowPlanObservation @MoifoldSpec state observation
            , IndexedWorkflow.indexedWorkflowObserve @PrReviewMergeabilityIndexedSpec indexedState indexedObservation
            , IndexedWorkflow.indexedWorkflowPlanObservation @PrReviewMergeabilityIndexedSpec indexedState indexedObservation
            )
            of
            (Right compatibilityObserved, Right compatibilityPlan, Right indexedObserved, Right indexedPlan) ->
              let PrReviewIndexedState indexedNextState =
                    IndexedWorkflow.indexedWorkflowObservedState @PrReviewMergeabilityIndexedSpec indexedObserved
                  wrappedTransition = IndexedWorkflow.SomeIndexedPlannedTransition indexedPlan
                  indexedTargetState =
                    PrReviewIndexedState indexedNextState
                      :: PrReviewIndexedState PrReviewIndexedMerging
               in prReviewIndexedTransitionEvent indexedPlan == compatibilityPlan.plannedEvent
                    && IndexedWorkflow.someIndexedWorkflowTransitionEventLabel @PrReviewMergeabilityIndexedSpec wrappedTransition
                      == workflowEventLabel @MoifoldSpec compatibilityPlan.plannedEvent
                    && IndexedWorkflow.someIndexedWorkflowTransitionSourceLabel @PrReviewMergeabilityIndexedSpec wrappedTransition
                      == workflowStateLabel @MoifoldSpec state
                    && IndexedWorkflow.someIndexedWorkflowTransitionTargetLabel @PrReviewMergeabilityIndexedSpec wrappedTransition
                      == workflowStateLabel @MoifoldSpec compatibilityObserved.observedState
                    && prReviewIndexedTransitionPreCommitEffects indexedPlan == compatibilityPlan.plannedPreCommitEffects
                    && prReviewIndexedTransitionPostCommitEffects indexedPlan == compatibilityPlan.plannedPostCommitEffects
                    && IndexedWorkflow.someIndexedWorkflowTransitionPreCommitEffectLabels @PrReviewMergeabilityIndexedSpec wrappedTransition
                      == fmap (workflowEffectLabel @MoifoldSpec) compatibilityPlan.plannedPreCommitEffects
                    && IndexedWorkflow.someIndexedWorkflowTransitionPostCommitEffectLabels @PrReviewMergeabilityIndexedSpec wrappedTransition
                      == fmap (workflowEffectLabel @MoifoldSpec) compatibilityPlan.plannedPostCommitEffects
                    && workflowIsTerminal @MoifoldSpec compatibilityObserved.observedState
                      == IndexedWorkflow.indexedWorkflowIsTerminal @PrReviewMergeabilityIndexedSpec indexedTargetState
            _ -> False
      ]
  pure (and results)


workflowDslWorkflowMAccumulationLaws :: IO Bool
workflowDslWorkflowMAccumulationLaws = do
  let repo = RepoName "soulomoon/mlf2"
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      firstEffects =
        [SomeEffect (RecordIssuePlan issueConfig (PrNumber 1) "first plan")]
      secondEffects =
        [SomeEffect (RecordIssuePlan issueConfig (PrNumber 2) "second plan")]
      pureResult =
        WorkflowDSL.runWorkflowM
          (pure ("value" :: Text) :: WorkflowDSL.WorkflowM MoifoldSpec 'IssueImplement 'PlanMode Text)
      sequentialResult =
        WorkflowDSL.runWorkflowM
          ( do
              WorkflowDSL.emit firstEffects
              WorkflowDSL.emit secondEffects
              pure ("done" :: Text)
            :: WorkflowDSL.WorkflowM MoifoldSpec 'IssueImplement 'PlanMode Text
          )
      applicativeResult =
        WorkflowDSL.runWorkflowM
          ( ( (,)
                <$> (WorkflowDSL.emit firstEffects *> pure ("left" :: Text))
                <*> (WorkflowDSL.emit secondEffects *> pure ("right" :: Text))
            )
              :: WorkflowDSL.WorkflowM MoifoldSpec 'IssueImplement 'PlanMode (Text, Text)
          )
      monadResult =
        WorkflowDSL.runWorkflowM
          ( do
              WorkflowDSL.emit firstEffects
              left <- pure ("left" :: Text)
              WorkflowDSL.emit secondEffects
              pure (left <> "-right")
            :: WorkflowDSL.WorkflowM MoifoldSpec 'IssueImplement 'PlanMode Text
          )
      failedResult =
        WorkflowDSL.runWorkflowM
          ( do
              _ <- WorkflowDSL.failWorkflow "failed before later effects"
              WorkflowDSL.emit secondEffects
              pure ("unreachable" :: Text)
            :: WorkflowDSL.WorkflowM MoifoldSpec 'IssueImplement 'PlanMode Text
          )
  assert "workflow DSL WorkflowM accumulates effects left-to-right and short-circuits failures" $
    pureResult == Right ("value", [])
      && sequentialResult == Right ("done", firstEffects <> secondEffects)
      && applicativeResult == Right (("left", "right"), firstEffects <> secondEffects)
      && monadResult == Right ("left-right", firstEffects <> secondEffects)
      && failedResult == Left "failed before later effects"

workflowDslAdvanceBuildsPhaseChangingTransition :: IO Bool
workflowDslAdvanceBuildsPhaseChangingTransition = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      turnId = TurnId "worker-turn"
      state = PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle (ThreadId "reviewer"))
      evidence = reviewEvidenceFromSummaries ("fix review" :| []) (CommitSha "abc123")
      event = PrReviewFeedbackFound evidence turnId
      Decision _ effects = step state (ReviewThreadsFound evidence (ActiveTurn workerThread turnId))
      transitionResult =
        ( WorkflowDSL.advance
            event
            ( do
                WorkflowDSL.emit effects
                pure ("phase changed" :: Text)
              :: WorkflowDSL.WorkflowM MoifoldSpec 'PrReview 'CheckingReviews Text
            )
            :: Either Text (WorkflowDSL.Transition MoifoldSpec 'PrReview 'CheckingReviews 'FixingReviews Text)
        )
  assert "workflow DSL advance builds a phase-changing transition with value, event, and effects" $
    case transitionResult of
      Right transition ->
        let expected = workflowPlanTransition @MoifoldSpec event effects
            planned = WorkflowDSL.transitionPlannedTransition transition
         in WorkflowDSL.transitionValue transition == "phase changed"
              && WorkflowDSL.transitionEvent transition == event
              && WorkflowDSL.transitionEffects transition == effects
              && planned.plannedEvent == expected.plannedEvent
              && planned.plannedPreCommitEffects == expected.plannedPreCommitEffects
              && planned.plannedPostCommitEffects == expected.plannedPostCommitEffects
      Left _ -> False

workflowDslPrReviewFeedbackMatchesStateMachine :: IO Bool
workflowDslPrReviewFeedbackMatchesStateMachine = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      turnId = TurnId "worker-turn"
      state = PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle (ThreadId "reviewer"))
      evidence = reviewEvidenceFromSummaries ("fix review" :| []) (CommitSha "abc123")
      event = PrReviewFeedbackFound evidence turnId
      Decision _ effects = step state (ReviewThreadsFound evidence (ActiveTurn workerThread turnId))
      transitionResult =
        ( WorkflowDSL.advance
            event
            (WorkflowDSL.emit effects :: WorkflowDSL.WorkflowM MoifoldSpec 'PrReview 'CheckingReviews ())
            :: Either Text (WorkflowDSL.Transition MoifoldSpec 'PrReview 'CheckingReviews 'FixingReviews ())
        )
  assert "workflow DSL transition preserves PR-review event and effect plan" $
    case transitionResult of
      Right transition ->
        WorkflowDSL.transitionEvent transition == event
          && WorkflowDSL.transitionEffects transition == effects
          && WorkflowDSL.transitionPreCommitEffects transition == effects
          && null (WorkflowDSL.transitionPostCommitEffects transition)
      Left _ -> False

workflowDslTransitionLowersToPlannedTransition :: IO Bool
workflowDslTransitionLowersToPlannedTransition = do
  let repo = RepoName "soulomoon/mlf2"
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      prNumber = PrNumber 6
      event = IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
      effects =
        [ SomeEffect (RecordIssuePlan issueConfig prNumber sampleIssuePlanMarkdown)
        , SomeEffect SleepUntilNextPoll
        ]
      transitionResult =
        ( WorkflowDSL.advance
            event
            (WorkflowDSL.emit effects :: WorkflowDSL.WorkflowM MoifoldSpec 'IssueImplement 'PlanMode ())
            :: Either Text (WorkflowDSL.Transition MoifoldSpec 'IssueImplement 'PlanMode 'Implementing ())
        )
  assert "workflow DSL transition lowers to planned pre/post commit effects" $
    case transitionResult of
      Right transition ->
        let expected = moifoldPlannedTransitionFromEffects event effects
            planned = WorkflowDSL.transitionPlannedTransition transition
         in WorkflowDSL.transitionEvent transition == event
              && WorkflowDSL.transitionEffects transition == effects
              && hasEffect RecordIssuePlanTag (WorkflowDSL.transitionPreCommitEffects transition)
              && lacksEffect SleepUntilNextPollTag (WorkflowDSL.transitionPreCommitEffects transition)
              && hasEffect SleepUntilNextPollTag (WorkflowDSL.transitionPostCommitEffects transition)
              && lacksEffect RecordIssuePlanTag (WorkflowDSL.transitionPostCommitEffects transition)
              && planned.plannedEvent == expected.plannedEvent
              && planned.plannedPreCommitEffects == expected.plannedPreCommitEffects
              && planned.plannedPostCommitEffects == expected.plannedPostCommitEffects
      Left _ -> False

workflowDslMoifoldProjectionParity :: IO Bool
workflowDslMoifoldProjectionParity = do
  let repo = RepoName "soulomoon/mlf2"
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      event = IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
      effects =
        [ SomeEffect SleepUntilNextPoll
        , SomeEffect (RecordIssuePlan issueConfig (PrNumber 6) sampleIssuePlanMarkdown)
        ]
      transitionResult =
        ( WorkflowDSL.advance
            event
            (WorkflowDSL.emit effects :: WorkflowDSL.WorkflowM MoifoldSpec 'IssueImplement 'PlanMode ())
            :: Either Text (WorkflowDSL.Transition MoifoldSpec 'IssueImplement 'PlanMode 'Implementing ())
        )
      moifoldExpected = moifoldPlannedTransitionFromEffects event effects
      genericExpected = workflowPlanTransition @MoifoldSpec event effects
  assert "workflow DSL moifold projections match planned transition partitioning" $
    case transitionResult of
      Right transition ->
        let planned = WorkflowDSL.transitionPlannedTransition transition
         in planned.plannedEvent == moifoldExpected.plannedEvent
              && planned.plannedPreCommitEffects == moifoldExpected.plannedPreCommitEffects
              && planned.plannedPostCommitEffects == moifoldExpected.plannedPostCommitEffects
              && planned.plannedEvent == genericExpected.plannedEvent
              && planned.plannedPreCommitEffects == genericExpected.plannedPreCommitEffects
              && planned.plannedPostCommitEffects == genericExpected.plannedPostCommitEffects
              && WorkflowDSL.transitionPreCommitEffects transition == moifoldExpected.plannedPreCommitEffects
              && WorkflowDSL.transitionPostCommitEffects transition == moifoldExpected.plannedPostCommitEffects
              && WorkflowDSL.transitionEffects transition == moifoldExpected.plannedPreCommitEffects <> moifoldExpected.plannedPostCommitEffects
      Left _ -> False

workflowDslDocsMigrationProjectionParity :: IO Bool
workflowDslDocsMigrationProjectionParity = do
  let event = DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
      effects =
        [ DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidation "docs/target.md"
        ]
      transitionResult =
        ( WorkflowDSL.advance
            event
            ( do
                WorkflowDSL.emit effects
                pure ("docs transition" :: Text)
              :: WorkflowDSL.WorkflowM DocsMigration.DocsMigrationSpec () DocsMigration.DocsMigrationIndexedTurnActive Text
            )
            :: Either Text (WorkflowDSL.Transition DocsMigration.DocsMigrationSpec () DocsMigration.DocsMigrationIndexedTurnActive DocsMigration.DocsMigrationIndexedDraftReady Text)
        )
      expected = workflowPlanTransition @DocsMigration.DocsMigrationSpec event effects
  assert "workflow DSL DocsMigration projections match all-post-commit planned transition partitioning" $
    case transitionResult of
      Right transition ->
        WorkflowDSL.transitionValue transition == "docs transition"
          && WorkflowDSL.transitionEvent transition == expected.plannedEvent
          && WorkflowDSL.transitionPreCommitEffects transition == expected.plannedPreCommitEffects
          && WorkflowDSL.transitionPostCommitEffects transition == expected.plannedPostCommitEffects
          && WorkflowDSL.transitionPreCommitEffects transition == []
          && WorkflowDSL.transitionPostCommitEffects transition == effects
          && WorkflowDSL.transitionEffects transition == expected.plannedPreCommitEffects <> expected.plannedPostCommitEffects
      Left _ -> False

workflowDslDocsMigrationDraftProducedPortParity :: IO Bool
workflowDslDocsMigrationDraftProducedPortParity = do
  let config =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      activeState =
        DocsMigration.DocsMigrationTurnActive
          config
          (WorkflowAgent.TurnRef (ThreadId "docs-thread") (TurnId "docs-turn"))
      event = DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
      expectedState = DocsMigration.DocsMigrationDraftReady config "draft markdown"
      expectedEffects =
        [ DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidation "docs/target.md"
        ]
      expectedActions =
        [ DocsMigration.WriteDocsMigrationDraftAction "docs/target.md" "draft markdown"
        , DocsMigration.RunDocsMigrationValidationAction "docs/target.md"
        ]
      expectedPlan = workflowPlanTransition @DocsMigration.DocsMigrationSpec event expectedEffects
      observation =
        DocsMigration.DocsMigrationAgentReturned
          ( WorkflowAgent.ClassifiedAgentOutput
              WorkflowAgent.AgentComplete
              (DocsMigration.DocsMigrationOutput "draft markdown" "draft ready")
          )
      compiled = DocsMigration.compileDocsMigrationEffectPlan (expectedPlan.plannedPreCommitEffects <> expectedPlan.plannedPostCommitEffects)
      reports = DocsMigration.dryRunDocsMigrationCompiledEffectPlan compiled
      transitionResult = DocsMigration.docsMigrationDraftProducedDslTransition config "draft markdown" "draft ready"
      appliedResult = workflowApplyEvent @DocsMigration.DocsMigrationSpec activeState event
      observedResult = workflowObserve @DocsMigration.DocsMigrationSpec activeState observation
      replayResult =
        workflowReplayEvents
          @DocsMigration.DocsMigrationSpec
          [ DocsMigration.DocsMigrationInitialized config
          , DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")
          , event
          ]
  assert "workflow DSL DocsMigration draft-produced port preserves transition, replay, permission, and dry-run parity" $
    case (transitionResult, appliedResult, observedResult, replayResult) of
      (Right transition, Right (appliedState, appliedEffects), Right observed, Right replay) ->
        let planned = WorkflowDSL.transitionPlannedTransition transition
         in WorkflowDSL.transitionEvent transition == event
              && WorkflowDSL.transitionValue transition == expectedState
              && WorkflowDSL.transitionPreCommitEffects transition == []
              && WorkflowDSL.transitionPostCommitEffects transition == expectedEffects
              && WorkflowDSL.transitionEffects transition == expectedEffects
              && planned.plannedEvent == expectedPlan.plannedEvent
              && planned.plannedPreCommitEffects == expectedPlan.plannedPreCommitEffects
              && planned.plannedPostCommitEffects == expectedPlan.plannedPostCommitEffects
              && appliedState == expectedState
              && appliedEffects == expectedEffects
              && observed.docsMigrationTickEvent == event
              && observed.docsMigrationTickState == expectedState
              && observed.docsMigrationTickEffects == expectedEffects
              && replay.docsMigrationReplayState == expectedState
              && last replay.docsMigrationReplayEffects == expectedEffects
              && workflowValidateEffects @DocsMigration.DocsMigrationSpec activeState expectedEffects == Right ()
              && case workflowEffectAllowed @DocsMigration.DocsMigrationSpec (DocsMigration.DocsMigrationReady config) (DocsMigration.WriteDocsMigrationDraft "docs/target.md" "draft markdown") of
                Left reason -> "ready" `Text.isInfixOf` reason
                Right () -> False
              && fmap DocsMigration.docsMigrationActionReportAction reports == expectedActions
              && all ((== DryRunActions) . DocsMigration.docsMigrationActionReportMode) reports
              && not (any DocsMigration.docsMigrationActionReportExecuted reports)
      _ -> False

workflowDslIssuePlanningTurnCompletedPortParity :: IO Bool
workflowDslIssuePlanningTurnCompletedPortParity = do
  let config = issuePlanningIndexedConfig
      threadId = ThreadId "planner-thread"
      turnId = TurnId "planner-turn"
      activeState = SomeWatcherState (PlanningTurnActive config (ActiveTurn threadId turnId))
      observation = DaemonIssuePlanningObservation ObservedPlanningTurnCompleted
      expectedEvent = IssuePlanningTurnCompleted
      expectedEffects = [SomeEffect StopDaemon]
      runtimeConfig = effectRuntimeConfig config.plannerRepo "/tmp/work" 1060
      expectedCompiled = compileEffectPlan runtimeConfig expectedEffects
      expectedReports = dryRunCompiledEffectPlan expectedCompiled
      indexedState =
        IssuePlanningIndexedState activeState
          :: IssuePlanningIndexedState IssuePlanningIndexedActiveTurn
      indexedObservation =
        IssuePlanningIndexedObservation "IssuePlanning/PlanMode" "IssuePlanning/Complete" observation
          :: IssuePlanningIndexedObservation IssuePlanningIndexedActiveTurn IssuePlanningIndexedComplete
      indexedPlanResult =
        IndexedWorkflow.indexedWorkflowPlanObservation
          @IssuePlanningIndexedSpec
          indexedState
          indexedObservation
      compatibilityPlanResult = workflowPlanObservation @MoifoldSpec activeState observation
      compatibilityObserveResult = workflowObserve @MoifoldSpec activeState observation
      dslProjectionResult = projectIssuePlanningTurnCompletedDslTransition activeState
      publicProjectionResult = projectIssuePlanningTurnCompletedObservation activeState
      replayResult =
        workflowReplayEvents
          @MoifoldSpec
          [ IssuePlanningInitialized config
          , IssuePlanningTurnStarted threadId turnId
          , expectedEvent
          ]
  assert "workflow DSL issue-planning turn-completed port preserves projection, replay, permission, action, and dry-run parity" $
    case (indexedPlanResult, compatibilityPlanResult, compatibilityObserveResult, dslProjectionResult, publicProjectionResult, replayResult) of
      (Right indexedPlan, Right compatibilityPlan, Right observed, Right dslProjection, Right publicProjection, Right replay) ->
        let indexedCompatibilityPlan = issuePlanningIndexedTransitionToCompatibility indexedPlan
            dslPlan = dslProjection.issuePlanningIndexedProjectionPlanned
            publicPlan = publicProjection.issuePlanningIndexedProjectionPlanned
            compiled =
              WorkflowExecution.compileWorkflowEffectPlanWithMetadata
                runtimeConfig
                dslProjection.issuePlanningIndexedProjectionEffectPlan
         in publicPlan.plannedEvent == dslPlan.plannedEvent
              && publicPlan.plannedPreCommitEffects == dslPlan.plannedPreCommitEffects
              && publicPlan.plannedPostCommitEffects == dslPlan.plannedPostCommitEffects
              && sameWatcherStateShape publicProjection.issuePlanningIndexedProjectionFinalState dslProjection.issuePlanningIndexedProjectionFinalState
              && dslPlan.plannedEvent == expectedEvent
              && dslPlan.plannedEvent == compatibilityPlan.plannedEvent
              && dslPlan.plannedEvent == indexedCompatibilityPlan.plannedEvent
              && dslPlan.plannedPreCommitEffects == compatibilityPlan.plannedPreCommitEffects
              && dslPlan.plannedPostCommitEffects == compatibilityPlan.plannedPostCommitEffects
              && dslPlan.plannedPreCommitEffects == indexedCompatibilityPlan.plannedPreCommitEffects
              && dslPlan.plannedPostCommitEffects == indexedCompatibilityPlan.plannedPostCommitEffects
              && dslProjection.issuePlanningIndexedProjectionEffectPlan == expectedEffects
              && dslProjection.issuePlanningIndexedProjectionSourceLabel == "IssuePlanning/PlanMode"
              && dslProjection.issuePlanningIndexedProjectionTargetLabel == "IssuePlanning/Complete"
              && sameWatcherStateShape dslProjection.issuePlanningIndexedProjectionFinalState observed.observedState
              && workflowStateLabel @MoifoldSpec dslProjection.issuePlanningIndexedProjectionFinalState == "IssuePlanning/Complete"
              && sameWatcherStateShape replay.replayState dslProjection.issuePlanningIndexedProjectionFinalState
              && last replay.replayEffects == expectedEffects
              && workflowValidateEffects @MoifoldSpec activeState expectedEffects == Right ()
              && all (\effect -> workflowEffectAllowed @MoifoldSpec activeState effect == Right ()) expectedEffects
              && validatePhaseActionPlan activeState expectedEffects == Right ()
              && fmap WorkflowExecution.workflowPlannedAction compiled.workflowCompiledActions == expectedCompiled.compiledActions
              && WorkflowExecution.dryRunWorkflowCompiledEffectPlan compiled == expectedReports
      _ -> False


workflowDaemonCoreProjectsMoifoldAndDocsMigrationResults :: IO Bool
workflowDaemonCoreProjectsMoifoldAndDocsMigrationResults = do
  (executor, _getCalls) <- fakeActionExecutor
  docsCalls <- newIORef []
  let record call = modifyIORef' docsCalls (<> [call])
      runtimeConfig = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 720
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      moifoldEvents = [IssuePlanningInitialized (PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 8) [])]
      moifoldObservation = DaemonIssuePlanningObservation (ObservedPlanningTurnStarted (ThreadId "planner-thread") (TurnId "turn-plan"))
      docsConfig =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      docsEvents =
        [ DocsMigration.DocsMigrationInitialized docsConfig
        , DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")
        ]
      docsOutput = DocsMigration.DocsMigrationOutput "draft markdown" "draft ready"
      docsObservation =
        DocsMigration.DocsMigrationAgentReturned
          (WorkflowAgent.ClassifiedAgentOutput WorkflowAgent.AgentComplete docsOutput)
      docsInterpreter =
        DocsMigration.DocsMigrationInterpreter
          { DocsMigration.docsMigrationStartTurn = \_config -> record "start-turn"
          , DocsMigration.docsMigrationWriteDraft = \path draft -> record ("write:" <> Text.pack path <> ":" <> draft)
          , DocsMigration.docsMigrationRunValidation = \path -> record ("validate:" <> Text.pack path)
          , DocsMigration.docsMigrationStopDaemon = record "stop"
          }
      docsExpectedEvent = DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
  moifoldResult <- runObservedDaemonTickWithEvents executor options moifoldEvents moifoldObservation
  docsResult <- DocsMigration.runDocsMigrationObservedExecute docsInterpreter docsEvents docsObservation
  results <-
    sequence
      [ assert "workflow daemon core projects moifold dry-run tick result" $
          case moifoldResult of
            Right tick ->
              let coreTick = daemonObservedCoreTickResult tick
               in WorkflowDaemon.workflowObservedDaemonEvent coreTick == tick.daemonObservedEvent
                    && WorkflowDaemon.workflowObservedDaemonCommittedEvents coreTick == []
                    && WorkflowDaemon.workflowObservedDaemonCommittedEvents coreTick == tick.daemonObservedCommittedEvents
                    && WorkflowDaemon.workflowObservedDaemonActionReports coreTick == tick.daemonObservedActionReports
                    && WorkflowDaemon.workflowObservedDaemonPreCommitReports coreTick == WorkflowEventLog.workflowAuditPreCommitReports tick.daemonObservedAudit
                    && WorkflowDaemon.workflowObservedDaemonPostCommitReports coreTick == WorkflowEventLog.workflowAuditPostCommitReports tick.daemonObservedAudit
                    && WorkflowEventLog.workflowAuditCommittedEventLabel (WorkflowDaemon.workflowObservedDaemonAudit coreTick) == Nothing
            Left _ -> False
      , assert "workflow daemon core projects docs-migration execute tick result" $
          case docsResult of
            Right tick ->
              let coreTick = DocsMigration.docsMigrationDaemonCoreTickResult tick
               in WorkflowDaemon.workflowObservedDaemonEvent coreTick == docsExpectedEvent
                    && WorkflowDaemon.workflowObservedDaemonCommittedEvents coreTick == [docsExpectedEvent]
                    && WorkflowDaemon.workflowObservedDaemonActionReports coreTick == tick.docsMigrationDaemonActionReports
                    && WorkflowDaemon.workflowObservedDaemonPreCommitReports coreTick == WorkflowEventLog.workflowAuditPreCommitReports tick.docsMigrationDaemonAudit
                    && WorkflowDaemon.workflowObservedDaemonPostCommitReports coreTick == WorkflowEventLog.workflowAuditPostCommitReports tick.docsMigrationDaemonAudit
                    && WorkflowEventLog.workflowAuditCommittedEventLabel (WorkflowDaemon.workflowObservedDaemonAudit coreTick) == Just "docs-migration-draft-produced"
            Left _ -> False
      ]
  pure (and results)

workflowDaemonCoreProjectsObservedFailureBoundary :: IO Bool
workflowDaemonCoreProjectsObservedFailureBoundary = do
  preCommitFailure <-
    WorkflowTransaction.runWorkflowObservedExecuteTransactionDetailed
      @DocsMigration.DocsMigrationSpec
      (docsMigrationFailureHooks FailPreCommit)
      events
      observation
  postCommitCallbackFailure <-
    WorkflowTransaction.runWorkflowObservedExecuteTransactionDetailed
      @DocsMigration.DocsMigrationSpec
      (docsMigrationFailureHooks FailPostCommitCallback)
      events
      observation
  results <-
    sequence
      [ assert "workflow daemon core projects retryable pre-commit failure" $
          case preCommitFailure of
            Left failure ->
              let coreFailure = WorkflowDaemon.workflowObservedDaemonTickFailure failure
               in WorkflowDaemon.workflowObservedDaemonFailureStage coreFailure == WorkflowTransaction.WorkflowTransactionPreCommitActionFailure
                    && WorkflowDaemon.workflowObservedDaemonFailureCommittedEvents coreFailure == []
                    && WorkflowDaemon.workflowObservedDaemonFailurePreCommitReports coreFailure == []
                    && WorkflowDaemon.workflowObservedDaemonFailurePostCommitReports coreFailure == []
                    && WorkflowDaemon.workflowObservedDaemonFailureReason coreFailure == "pre failed"
                    && failureAuditMatches coreFailure Nothing WorkflowEventLog.WorkflowDaemonRetry
            Right _ -> False
      , assert "workflow daemon core projects committed stop failure" $
          case postCommitCallbackFailure of
            Left failure ->
              let coreFailure = WorkflowDaemon.workflowObservedDaemonTickFailure failure
               in WorkflowDaemon.workflowObservedDaemonFailureStage coreFailure == WorkflowTransaction.WorkflowTransactionPostCommitCallbackFailure
                    && WorkflowDaemon.workflowObservedDaemonFailureCommittedEvents coreFailure == [expectedEvent]
                    && WorkflowDaemon.workflowObservedDaemonFailureFinalState coreFailure == Just expectedState
                    && WorkflowDaemon.workflowObservedDaemonFailurePreCommitReports coreFailure == ["pre-action"]
                    && WorkflowDaemon.workflowObservedDaemonFailurePostCommitReports coreFailure == []
                    && WorkflowDaemon.workflowObservedDaemonFailureReason coreFailure == "after commit failed"
                    && failureAuditMatches coreFailure (Just "docs-migration-draft-produced") WorkflowEventLog.WorkflowDaemonStop
            Right _ -> False
      ]
  pure (and results)
 where
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
  expectedEvent =
    DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
  expectedState =
    DocsMigration.DocsMigrationDraftReady config "draft markdown"

  failureAuditMatches coreFailure expectedCommitted expectedRecommendation =
    case WorkflowDaemon.workflowObservedDaemonFailureAudit coreFailure of
      Just audit ->
        WorkflowEventLog.workflowAuditCommittedEventLabel audit == expectedCommitted
          && WorkflowEventLog.workflowAuditFailureClassification audit == Just (WorkflowDaemon.workflowObservedDaemonFailureReason coreFailure)
          && WorkflowEventLog.workflowAuditNextDaemonRecommendation audit == expectedRecommendation
      Nothing -> False

data WorkflowTransactionFailureMode
  = NoTransactionFailure
  | FailPreCommit
  | FailCommit
  | FailPostCommitCallback
  | FailPostCommitAction
  deriving stock (Eq, Show)

workflowTransactionDetailedFailuresRecordCommitBoundary :: IO Bool
workflowTransactionDetailedFailuresRecordCommitBoundary = do
  let invalidInitialEvents = [DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")]
      replayOnlyEvents = [DocsMigration.DocsMigrationInitialized config]
      invalidPreparedEvent = DocsMigration.DocsMigrationValidationPassed "too early"
      invalidPreparedPlan =
        PlannedTransition
          { plannedEvent = invalidPreparedEvent
          , plannedPreCommitEffects = []
          , plannedPostCommitEffects = []
          }
  prepareBeforeReplayFailure <-
    WorkflowTransaction.runWorkflowObservedExecuteTransactionDetailed
      @DocsMigration.DocsMigrationSpec
      (docsMigrationFailureHooks NoTransactionFailure)
      invalidInitialEvents
      observation
  prepareAfterReplayFailure <-
    WorkflowTransaction.runWorkflowObservedExecuteTransactionDetailed
      @DocsMigration.DocsMigrationSpec
      (docsMigrationFailureHooks NoTransactionFailure)
      replayOnlyEvents
      observation
  preCommitFailure <- failureResult FailPreCommit
  commitFailure <- failureResult FailCommit
  postCommitReplayFailure <-
    case DocsMigration.replayDocsMigrationEvents events of
      Left reason -> pure (Left (prepareSyntheticFailure reason))
      Right priorReplay ->
        WorkflowTransaction.runWorkflowPreparedExecuteTransactionDetailed
          @DocsMigration.DocsMigrationSpec
          (docsMigrationFailureHooks NoTransactionFailure)
          events
          priorReplay
          observation
          invalidPreparedPlan
  postCommitCallbackFailure <- failureResult FailPostCommitCallback
  postCommitActionFailure <- failureResult FailPostCommitAction
  results <-
    sequence
      [ assert "workflow transaction prepare failure before replay has no audit" $
          case prepareBeforeReplayFailure of
            Left failure ->
              WorkflowTransaction.workflowTransactionFailureStage failure == WorkflowTransaction.WorkflowTransactionPrepareFailure
                && WorkflowTransaction.workflowTransactionFailurePriorReplay failure == Nothing
                && WorkflowTransaction.workflowTransactionFailureAudit failure == Nothing
                && WorkflowTransaction.workflowTransactionFailureCommittedEvents failure == []
            Right _ -> False
      , assert "workflow transaction prepare failure after replay records audit without commit" $
          case prepareAfterReplayFailure of
            Left failure ->
              WorkflowTransaction.workflowTransactionFailureStage failure == WorkflowTransaction.WorkflowTransactionPrepareFailure
                && WorkflowTransaction.workflowTransactionFailurePriorReplay failure /= Nothing
                && WorkflowTransaction.workflowTransactionFailureCommittedEvents failure == []
                && failureAuditLabels failure "ready" (Just "docs-migration-agent-returned") Nothing Nothing WorkflowEventLog.WorkflowDaemonStop
            Right _ -> False
      , assert "workflow transaction pre-commit failure records no committed event" $
          case preCommitFailure of
            Left failure ->
              WorkflowTransaction.workflowTransactionFailureStage failure == WorkflowTransaction.WorkflowTransactionPreCommitActionFailure
                && WorkflowTransaction.workflowTransactionFailureCommittedEvents failure == []
                && WorkflowTransaction.workflowTransactionFailurePreCommitReports failure == []
                && failureAuditLabels failure "turn-active" (Just "docs-migration-agent-returned") Nothing Nothing WorkflowEventLog.WorkflowDaemonRetry
            Right _ -> False
      , assert "workflow transaction commit failure preserves pre-commit reports without committed event" $
          case commitFailure of
            Left failure ->
              WorkflowTransaction.workflowTransactionFailureStage failure == WorkflowTransaction.WorkflowTransactionEventCommitFailure
                && WorkflowTransaction.workflowTransactionFailureCommittedEvents failure == []
                && WorkflowTransaction.workflowTransactionFailurePreCommitReports failure == ["pre-action"]
                && failureAuditLabels failure "turn-active" (Just "docs-migration-agent-returned") Nothing Nothing WorkflowEventLog.WorkflowDaemonStop
            Right _ -> False
      , assert "workflow transaction post-commit replay failure records committed event without final state" $
          case postCommitReplayFailure of
            Left failure ->
              WorkflowTransaction.workflowTransactionFailureStage failure == WorkflowTransaction.WorkflowTransactionPostCommitReplayFailure
                && WorkflowTransaction.workflowTransactionFailureCommittedEvents failure == [invalidPreparedEvent]
                && WorkflowTransaction.workflowTransactionFailureFinalState failure == Nothing
                && WorkflowTransaction.workflowTransactionFailurePreCommitReports failure == ["pre-action"]
                && failureAuditLabels failure "turn-active" (Just "docs-migration-agent-returned") (Just "docs-migration-validation-passed") Nothing WorkflowEventLog.WorkflowDaemonStop
            Right _ -> False
      , assert "workflow transaction post-commit callback failure records committed event and final state" $
          case postCommitCallbackFailure of
            Left failure ->
              WorkflowTransaction.workflowTransactionFailureStage failure == WorkflowTransaction.WorkflowTransactionPostCommitCallbackFailure
                && WorkflowTransaction.workflowTransactionFailureCommittedEvents failure == [expectedEvent]
                && WorkflowTransaction.workflowTransactionFailureFinalState failure == Just expectedState
                && WorkflowTransaction.workflowTransactionFailurePreCommitReports failure == ["pre-action"]
                && failureAuditLabels failure "turn-active" (Just "docs-migration-agent-returned") (Just "docs-migration-draft-produced") (Just "draft-ready") WorkflowEventLog.WorkflowDaemonStop
            Right _ -> False
      , assert "workflow transaction post-commit action failure records committed event and prior reports" $
          case postCommitActionFailure of
            Left failure ->
              WorkflowTransaction.workflowTransactionFailureStage failure == WorkflowTransaction.WorkflowTransactionPostCommitActionFailure
                && WorkflowTransaction.workflowTransactionFailureCommittedEvents failure == [expectedEvent]
                && WorkflowTransaction.workflowTransactionFailureFinalState failure == Just expectedState
                && WorkflowTransaction.workflowTransactionFailurePreCommitReports failure == ["pre-action"]
                && WorkflowTransaction.workflowTransactionFailurePostCommitReports failure == []
                && failureAuditLabels failure "turn-active" (Just "docs-migration-agent-returned") (Just "docs-migration-draft-produced") (Just "draft-ready") WorkflowEventLog.WorkflowDaemonStop
            Right _ -> False
      ]
  pure (and results)
 where
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
  expectedEvent =
    DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
  expectedState =
    DocsMigration.DocsMigrationDraftReady config "draft markdown"

  failureResult mode =
    WorkflowTransaction.runWorkflowObservedExecuteTransactionDetailed
      @DocsMigration.DocsMigrationSpec
      (docsMigrationFailureHooks mode)
      events
      observation

  failureAuditLabels failure expectedPrior expectedObservation expectedCommitted expectedFinal expectedRecommendation =
    case WorkflowTransaction.workflowTransactionFailureAudit failure of
      Just audit ->
        WorkflowEventLog.workflowAuditPriorStateLabel audit == expectedPrior
          && WorkflowEventLog.workflowAuditObservationLabel audit == expectedObservation
          && WorkflowEventLog.workflowAuditCommittedEventLabel audit == expectedCommitted
          && WorkflowEventLog.workflowAuditFinalStateLabel audit == expectedFinal
          && WorkflowEventLog.workflowAuditFailureClassification audit == Just (WorkflowTransaction.workflowTransactionFailureReason failure)
          && WorkflowEventLog.workflowAuditNextDaemonRecommendation audit == expectedRecommendation
      Nothing -> False

  prepareSyntheticFailure reason =
    WorkflowTransaction.WorkflowObservedTransactionFailure
      { WorkflowTransaction.workflowTransactionFailureStage = WorkflowTransaction.WorkflowTransactionPrepareFailure
      , WorkflowTransaction.workflowTransactionFailureReason = reason
      , WorkflowTransaction.workflowTransactionFailurePriorReplay = Nothing
      , WorkflowTransaction.workflowTransactionFailurePlanned = Nothing
      , WorkflowTransaction.workflowTransactionFailureFinalState = Nothing
      , WorkflowTransaction.workflowTransactionFailureCommittedEvents = []
      , WorkflowTransaction.workflowTransactionFailureCompiledEffects = Nothing
      , WorkflowTransaction.workflowTransactionFailurePreCommitReports = []
      , WorkflowTransaction.workflowTransactionFailurePostCommitReports = []
      , WorkflowTransaction.workflowTransactionFailureAudit = Nothing
      }

workflowTransactionDryRunExecuteParityUsesCommitBoundary :: IO Bool
workflowTransactionDryRunExecuteParityUsesCommitBoundary = do
  calls <- newIORef []
  let record call = modifyIORef' calls (<> [call])
      compiledOnce = ["compiled-once"] :: [Text]
      hooks =
        WorkflowTransaction.WorkflowObservedTransactionHooks
          { WorkflowTransaction.workflowTransactionMapError = id
          , WorkflowTransaction.workflowTransactionCompileEffects = const compiledOnce
          , WorkflowTransaction.workflowTransactionPartitionActions = const (["pre-action"], ["post-action"])
          , WorkflowTransaction.workflowTransactionDryRunActions = fmap ("dry:" <>)
          , WorkflowTransaction.workflowTransactionExecuteActions = \actions -> do
              mapM_ (record . ("execute:" <>)) actions
              pure (Right (fmap ("execute:" <>) actions))
          , WorkflowTransaction.workflowTransactionCommitEvent =
              WorkflowEventLogCommit.WorkflowEventCommitter \event -> do
                record ("commit:" <> workflowEventLabel @DocsMigration.DocsMigrationSpec event)
                pure (Right ())
          , WorkflowTransaction.workflowTransactionAfterCommit = \state -> do
              record ("after:" <> workflowStateLabel @DocsMigration.DocsMigrationSpec state)
              pure (Right ())
          , WorkflowTransaction.workflowTransactionFailureIsRetryable = const False
          }
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
      expectedEvent =
        DocsMigration.DocsMigrationDraftProduced "draft markdown" "draft ready"
      expectedState =
        DocsMigration.DocsMigrationDraftReady config "draft markdown"
      dryRunResult =
        WorkflowTransaction.runWorkflowObservedDryRunTransaction
          @DocsMigration.DocsMigrationSpec
          hooks
          events
          observation
  dryRunCalls <- readIORef calls
  executeResult <-
    WorkflowTransaction.runWorkflowObservedExecuteTransactionDetailed
      @DocsMigration.DocsMigrationSpec
      hooks
      events
      observation
  executeCalls <- readIORef calls
  results <-
    sequence
      [ assert "workflow transaction dry-run partitions reports without mutating" $
          case dryRunResult of
            Right dryRun ->
              dryRun.workflowTransactionCommittedEvents == []
                && dryRun.workflowTransactionCompiledEffects == compiledOnce
                && dryRun.workflowTransactionPreCommitReports == ["dry:pre-action"]
                && dryRun.workflowTransactionPostCommitReports == ["dry:post-action"]
                && WorkflowEventLog.workflowAuditCommittedEventLabel dryRun.workflowTransactionAudit == Nothing
                && WorkflowEventLog.workflowAuditPreCommitReports dryRun.workflowTransactionAudit == ["dry:pre-action"]
                && WorkflowEventLog.workflowAuditPostCommitReports dryRun.workflowTransactionAudit == ["dry:post-action"]
                && null dryRunCalls
            Left _ -> False
      , assert "workflow transaction execute commits before callback and post actions" $
          case executeResult of
            Right execute ->
              execute.workflowTransactionPlanned.plannedEvent == expectedEvent
                && execute.workflowTransactionFinalState == expectedState
                && execute.workflowTransactionCommittedEvents == [expectedEvent]
                && execute.workflowTransactionCompiledEffects == compiledOnce
                && execute.workflowTransactionPreCommitReports == ["execute:pre-action"]
                && execute.workflowTransactionPostCommitReports == ["execute:post-action"]
                && executeCalls == ["execute:pre-action", "commit:docs-migration-draft-produced", "after:draft-ready", "execute:post-action"]
                && WorkflowEventLog.workflowAuditCommittedEventLabel execute.workflowTransactionAudit == Just "docs-migration-draft-produced"
            Left _ -> False
      ]
  pure (and results)

docsMigrationFailureHooks
  :: WorkflowTransactionFailureMode
  -> WorkflowTransaction.WorkflowObservedTransactionHooks
       IO
       DocsMigration.DocsMigrationSpec
       ()
       Text
       Text
       Text
docsMigrationFailureHooks mode =
  WorkflowTransaction.WorkflowObservedTransactionHooks
    { WorkflowTransaction.workflowTransactionMapError = id
    , WorkflowTransaction.workflowTransactionCompileEffects = const ()
    , WorkflowTransaction.workflowTransactionPartitionActions = const (["pre-action"], ["post-action"])
    , WorkflowTransaction.workflowTransactionDryRunActions = id
    , WorkflowTransaction.workflowTransactionExecuteActions = \actions ->
        pure $
          if mode == FailPreCommit && actions == ["pre-action"]
            then Left "pre failed"
            else
              if mode == FailPostCommitAction && actions == ["post-action"]
                then Left "post failed"
                else Right actions
    , WorkflowTransaction.workflowTransactionCommitEvent =
        WorkflowEventLogCommit.WorkflowEventCommitter \_event ->
          pure $
            if mode == FailCommit
              then Left "commit failed"
              else Right ()
    , WorkflowTransaction.workflowTransactionAfterCommit = \_state ->
        pure $
          if mode == FailPostCommitCallback
            then Left "after commit failed"
            else Right ()
    , WorkflowTransaction.workflowTransactionFailureIsRetryable = (== "pre failed")
    }

workflowExecutionMetadataCoversCurrentEffects :: IO Bool
workflowExecutionMetadataCoversCurrentEffects = do
  results <-
    traverse
      ( \(effectLabel, effect, _expectedCapability, expectedCommitOrder, expectedIdempotency) ->
          let metadata = WorkflowExecution.workflowEffectMetadata effect
           in assert
                ("workflow execution metadata for " <> Text.unpack effectLabel)
                ( metadata.workflowEffectCommitOrder == expectedCommitOrder
                    && metadata.workflowEffectIdempotency == expectedIdempotency
                )
      )
      workflowMetadataFixtureEffects
  pure (and results)

workflowExecutionCapabilityMetadataCoversCurrentEffects :: IO Bool
workflowExecutionCapabilityMetadataCoversCurrentEffects = do
  results <-
    traverse
      ( \(effectLabel, effect, expectedCapability, _expectedCommitOrder, _expectedIdempotency) ->
          let metadata = WorkflowExecution.workflowEffectMetadata effect
           in assert
                ("workflow capability metadata for " <> Text.unpack effectLabel)
                (metadata.workflowEffectCapability == expectedCapability)
      )
      workflowMetadataFixtureEffects
  pure (and results)

workflowExecutionMetadataPartitionPreservesLegacyOrdering :: IO Bool
workflowExecutionMetadataPartitionPreservesLegacyOrdering = do
  let repo = RepoName "soulomoon/mlf2"
      config = effectRuntimeConfig repo "/tmp/work" 401
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      prNumber = PrNumber 6
      evidence = reviewEvidenceFromSummaries ("fix review" :| []) (CommitSha "abc123")
      cleanEvidence = CleanReviewEvidence (CommitSha "abc123") "LGTM"
      effects =
        [ SomeEffect (PushBranch (BranchName "codex/issue-42"))
        , SomeEffect (StartWorkerTurn evidence (ThreadId "worker"))
        , SomeEffect (RecordIssuePlan issueConfig prNumber "plan")
        , SomeEffect (RecordBlocked (BlockedReason "blocked"))
        , SomeEffect (MergePullRequest prNumber cleanEvidence)
        , SomeEffect SleepUntilNextPoll
        , SomeEffect StopDaemon
        ]
      legacy = compileEffectPlan config effects
      workflow = WorkflowExecution.compileWorkflowEffectPlanWithMetadata config effects
      (preCommit, postCommit) = WorkflowExecution.partitionWorkflowActions workflow
      preCommitActions = fmap WorkflowExecution.workflowPlannedAction preCommit
      postCommitActions = fmap WorkflowExecution.workflowPlannedAction postCommit
      legacyPartition =
        ( [legacy.compiledActions !! 0, legacy.compiledActions !! 1, legacy.compiledActions !! 2, legacy.compiledActions !! 4]
        , [legacy.compiledActions !! 3, legacy.compiledActions !! 5, legacy.compiledActions !! 6]
        )
  results <-
    sequence
      [ assert "workflow metadata compile preserves legacy action order" $
          fmap WorkflowExecution.workflowPlannedAction workflow.workflowCompiledActions == legacy.compiledActions
      , assert "workflow metadata compile preserves request id progression" $
          WorkflowExecution.workflowCompiledEffectPlanLegacy workflow == legacy
      , assert "workflow metadata partition preserves pre-commit ordering" $
          preCommitActions == fst legacyPartition
      , assert "workflow metadata partition preserves post-commit ordering" $
          postCommitActions == snd legacyPartition
      ]
  pure (and results)

workflowExecutionMetadataDryRunMatchesLegacy :: IO Bool
workflowExecutionMetadataDryRunMatchesLegacy = do
  (executor, getCalls) <- fakeActionExecutor
  let repo = RepoName "soulomoon/mlf2"
      config = effectRuntimeConfig repo "/tmp/work" 420
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      effects =
        [ SomeEffect (CreatePullRequest issueConfig)
        , SomeEffect (RecordPlanningGraph (PlanningGraph [IssueNumber 42] [] []))
        , SomeEffect SleepUntilNextPoll
        ]
      legacyDryRun = dryRunCompiledEffectPlan (compileEffectPlan config effects)
      workflow = WorkflowExecution.compileWorkflowEffectPlanWithMetadata config effects
      metadataDryRun = WorkflowExecution.dryRunWorkflowCompiledEffectPlan workflow
  executedDryRun <- WorkflowExecution.executeWorkflowCompiledEffectPlan executor DryRunActions workflow
  calls <- getCalls
  results <-
    sequence
      [ assert "workflow metadata dry-run matches legacy dry-run reports" (metadataDryRun == legacyDryRun)
      , assert "workflow metadata execute dry-run matches legacy dry-run reports" (executedDryRun == legacyDryRun)
      , assert "workflow metadata dry-run does not call interpreters" (null calls)
      ]
  pure (and results)

workflowExecutionCoreCheckedActionsStopsOnFirstFailure :: IO Bool
workflowExecutionCoreCheckedActionsStopsOnFirstFailure = do
  executedRef <- newIORef []
  let actions = [1, 2, 3, 4] :: [Int]
      runAction action = do
        modifyIORef' executedRef (<> [action])
        pure ("report-" <> show action)
      classifyFailure action report =
        if action == 3
          then Just ("failed-" <> report)
          else Nothing
  failedResult <- WorkflowExecutionCore.executeWorkflowCheckedActionsOf runAction classifyFailure actions
  executed <- readIORef executedRef
  successResult <-
    WorkflowExecutionCore.executeWorkflowCheckedActionsOf
      (\action -> pure ("ok-" <> show (action :: Int)))
      (\_ _ -> Nothing :: Maybe ())
      ([1, 2, 3] :: [Int])
  results <-
    sequence
      [ assert "workflow core checked execution runs left-to-right through first failure" $
          executed == [1, 2, 3]
      , assert "workflow core checked execution captures first failure and prior reports" $
          case failedResult of
            Left failure ->
              failure.workflowCheckedActionFailedAction == 3
                && failure.workflowCheckedActionFailedReport == "report-3"
                && failure.workflowCheckedActionFailurePriorReports == ["report-1", "report-2"]
                && failure.workflowCheckedActionFailureReason == "failed-report-3"
                && WorkflowExecutionCore.workflowCheckedActionFailureReports failure == ["report-1", "report-2", "report-3"]
            Right _ -> False
      , assert "workflow core checked execution returns ordered reports on success" $
          case successResult of
            Right reports -> reports == ["ok-1", "ok-2", "ok-3"]
            Left _ -> False
      ]
  pure (and results)

workflowExecutionCheckedActionsStopsOnHardFailure :: IO Bool
workflowExecutionCheckedActionsStopsOnHardFailure = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GitPush {} -> failedCommandReport "permission denied"
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let repo = RepoName "soulomoon/mlf2"
      config = effectRuntimeConfig repo "/tmp/work" 430
      request = IssueCreationRequest "child" "body" Nothing
      effects =
        [ SomeEffect (PushBranch (BranchName "codex/fail"))
        , SomeEffect (CreateIssue repo request)
        ]
      workflow = WorkflowExecution.compileWorkflowEffectPlanWithMetadata config effects
  result <- WorkflowExecution.executeWorkflowCheckedActions executor workflow.workflowCompiledActions
  calls <- getCalls
  results <-
    sequence
      [ assert "workflow checked execution stops after first hard failure" $
          calls == [FakeCommand (GitPush "/tmp/work" (BranchName "codex/fail"))]
      , assert "workflow checked execution returns classified failure" $
          case result of
            Left failure ->
              ( case failure.workflowFailedAction.workflowPlannedAction of
                  PlannedCommand GitPush {} -> True
                  _ -> False
              )
                && failure.workflowFailureClassification.failureClass == PolicyViolation
                && null failure.workflowFailurePriorReports
                && WorkflowExecution.workflowActionFailureReports failure == [failure.workflowFailedReport]
                && case failure.workflowFailureCommandReport of
                  Just report -> not report.ok
                  Nothing -> False
            Right _ -> False
      ]
  pure (and results)

workflowMetadataFixtureEffects
  :: [(Text, SomeEffect, WorkflowExecution.WorkflowCapability, WorkflowExecution.EffectCommitOrder, WorkflowExecution.EffectIdempotency)]
workflowMetadataFixtureEffects =
  let repo = RepoName "soulomoon/mlf2"
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      prNumber = PrNumber 6
      prConfig = PrConfig repo prNumber (BranchName "codex/issue-42")
      commit = CommitSha "abc123"
      thread = ThreadId "thread"
      reviewThread = ReviewThreadId "review-thread"
      evidence = reviewEvidenceFromSummaries ("fix review" :| []) commit
      cleanEvidence = CleanReviewEvidence commit "LGTM"
      issueRequest = IssueCreationRequest "child issue" "body" Nothing
      graph = PlanningGraph [IssueNumber 42] [] []
      blocked = BlockedReason "blocked"
      pre = WorkflowExecution.PreCommit
      post = WorkflowExecution.PostCommit
      readWorld = WorkflowExecution.ReadWorld
      startAgent = WorkflowExecution.StartAgent
      writeLocal = WorkflowExecution.WriteLocal
      mutateRemote = WorkflowExecution.MutateRemote
      merge = WorkflowExecution.Merge
      sleep = WorkflowExecution.Sleep
      stop = WorkflowExecution.Stop
      idempotent = WorkflowExecution.Idempotent
      checkThenAct = WorkflowExecution.CheckThenAct
      atMostOnce = WorkflowExecution.AtMostOnce
      derivedWrite = WorkflowExecution.DerivedWrite
   in [ ("ReadOpenIssues", SomeEffect (ReadOpenIssues repo), readWorld, pre, idempotent)
      , ("ReadOpenPullRequests", SomeEffect (ReadOpenPullRequests repo), readWorld, pre, idempotent)
      , ("ReadReviewThreads", SomeEffect (ReadReviewThreads prConfig), readWorld, pre, idempotent)
      , ("StartPlannerTurn", SomeEffect (StartPlannerTurn thread), startAgent, pre, atMostOnce)
      , ("StartWorkerTurn", SomeEffect (StartWorkerTurn evidence thread), startAgent, pre, atMostOnce)
      , ("StartIssuePlanWorkerTurn", SomeEffect (StartIssuePlanWorkerTurn issueConfig prNumber thread), startAgent, pre, atMostOnce)
      , ("StartIssueImplementationWorkerTurn", SomeEffect (StartIssueImplementationWorkerTurn thread), startAgent, pre, atMostOnce)
      , ("StartReviewerTurn", SomeEffect (StartReviewerTurn prConfig commit thread), startAgent, pre, atMostOnce)
      , ("StartReviewerVerificationTurn", SomeEffect (StartReviewerVerificationTurn prConfig evidence commit thread), startAgent, pre, atMostOnce)
      , ("StartIssueFinalReviewTurn", SomeEffect (StartIssueFinalReviewTurn issueConfig prNumber commit thread), startAgent, pre, atMostOnce)
      , ("PushBranch", SomeEffect (PushBranch (BranchName "codex/issue-42")), mutateRemote, pre, checkThenAct)
      , ("CreateIssue", SomeEffect (CreateIssue repo issueRequest), mutateRemote, pre, atMostOnce)
      , ("CreatePullRequest", SomeEffect (CreatePullRequest issueConfig), mutateRemote, pre, atMostOnce)
      , ("UpdatePullRequestBody", SomeEffect (UpdatePullRequestBody issueConfig prNumber), mutateRemote, pre, checkThenAct)
      , ("UpdateIssueFollowUp", SomeEffect (UpdateIssueFollowUp issueConfig evidence), mutateRemote, pre, atMostOnce)
      , ("CloseIssue", SomeEffect (CloseIssue issueConfig prNumber), mutateRemote, pre, checkThenAct)
      , ("ResolveReviewThread", SomeEffect (ResolveReviewThread reviewThread), mutateRemote, pre, checkThenAct)
      , ("ReplyReviewThread", SomeEffect (ReplyReviewThread reviewThread "reply"), mutateRemote, pre, atMostOnce)
      , ("PublishReviewFindings", SomeEffect (PublishReviewFindings prConfig evidence), mutateRemote, pre, atMostOnce)
      , ("RecordIssuePlan", SomeEffect (RecordIssuePlan issueConfig prNumber "plan"), writeLocal, pre, derivedWrite)
      , ("RecordPlanningGraph", SomeEffect (RecordPlanningGraph graph), writeLocal, post, derivedWrite)
      , ("RecordBlocked", SomeEffect (RecordBlocked blocked), writeLocal, post, derivedWrite)
      , ("MergePullRequest", SomeEffect (MergePullRequest prNumber cleanEvidence), merge, pre, checkThenAct)
      , ("StopDaemon", SomeEffect StopDaemon, stop, post, idempotent)
      , ("SleepUntilNextPoll", SomeEffect SleepUntilNextPoll, sleep, post, idempotent)
      ]

sameWatcherStateShape :: SomeWatcherState -> SomeWatcherState -> Bool
sameWatcherStateShape left right =
  someDomain left == someDomain right
    && somePhase left == somePhase right

lastEffectPlanIs :: Eq effectPlan => effectPlan -> [effectPlan] -> Bool
lastEffectPlanIs expected plans =
  case reverse plans of
    actual : _ -> actual == expected
    [] -> False

isRightUnit :: Either error () -> Bool
isRightUnit = \case
  Right () -> True
  Left _ -> False
