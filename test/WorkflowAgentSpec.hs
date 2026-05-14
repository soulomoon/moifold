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

module WorkflowAgentSpec
  ( workflowAgentTests
  )
where


import CodexWatcher.AppServerProtocol
import CodexWatcher.ActionExecutor
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))
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
import CodexWatcher.StateMachine
import CodexWatcher.Supervisor
import CodexWatcher.Domain.IssueImplement.TurnClassifier
import CodexWatcher.Domain.IssuePlanning.TurnClassifier
import CodexWatcher.Domain.PrReview.TurnClassifier
import CodexWatcher.Turn.Classifier.Common
import CodexWatcher.TurnOutput
import CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..), nextRequestId)
import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..), ReviewThreadId (..))
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
import CodexWatcher.Workflow.EventLog.Commit.Core qualified as WorkflowEventLogCommit
import CodexWatcher.Workflow.EventLog.File.Core qualified as WorkflowEventLogFileCore
import CodexWatcher.Workflow.Execution qualified as WorkflowExecution
import CodexWatcher.Workflow.Execution.Core qualified as WorkflowExecutionCore
import CodexWatcher.Workflow.Indexed.Spec qualified as IndexedWorkflow
import CodexWatcher.Workflow.Moifold.AgentRoles qualified as MoifoldAgentRoles
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

data TestPrReviewWorkerAgent

workflowAgentTests :: IO Bool
workflowAgentTests =
  sequenceAnd
    [ workflowExecutionFacadeDryRunMatchesExecutor
    , workflowPrReviewCheckingFacadeMatchesWatcher
    , workflowPrReviewMergeabilityFacadeMatchesWatcher
    , workflowAgentRoleWrapsPrReviewWorkerClassifier
    , workflowAgentRolesExposeRetryAndSideEffectMetadata
    , workflowAgentCodexStartRequestsMatchCompiledEffects
    , workflowAgentCodexStartsThreadsThroughTypedAdapter
    , workflowAgentCodexParsesTurnLifecycle
    , workflowPrReviewAgentRolesClassifyOutputs
    , workflowAgentObservationKernelMatchesPrReviewClassifiers
    , workflowPlanObservationLawHoldsForPrReviewAgentObservation
    ]


workflowExecutionFacadeDryRunMatchesExecutor :: IO Bool
workflowExecutionFacadeDryRunMatchesExecutor = do
  let repo = RepoName "soulomoon/mlf2"
      config = effectRuntimeConfig repo "/tmp/work" 301
      evidence = reviewEvidenceFromSummaries ("fix review" :| []) (CommitSha "abc123")
      effects = [SomeEffect (StartWorkerTurn evidence (ThreadId "worker")), SomeEffect SleepUntilNextPoll]
      direct = dryRunCompiledEffectPlan (compileEffectPlan config effects)
      facade = WorkflowExecution.dryRunWorkflowEffectPlan config effects
  assert "workflow execution facade preserves dry-run reports" (direct == facade)

workflowPrReviewCheckingFacadeMatchesWatcher :: IO Bool
workflowPrReviewCheckingFacadeMatchesWatcher = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      state = SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle (ThreadId "worker")) (ReviewerIdle (ThreadId "reviewer")))
      reviewThreadId = ReviewThreadId "thread-1"
      commit = CommitSha "abc123"
      turnId = TurnId "worker-turn"
      report = reviewThreadsReport [reviewThreadId]
      watcher = prReviewObserve state (ObservedReviewThreads report commit turnId)
      facade = WorkflowPrReview.observePrReviewChecking state (WorkflowPrReview.CheckingObservedReviewThreads report commit turnId)
  assert "workflow PR-review checking facade matches watcher transition" $
    case (watcher, facade) of
      (Right watcherTick, Right observed) ->
        watcherTick.prReviewTickEvent == observed.observedEvent
          && somePhase watcherTick.prReviewTickState == somePhase observed.observedState
          && watcherTick.prReviewTickEffects == observed.observedEffects
      _ -> False

workflowPrReviewMergeabilityFacadeMatchesWatcher :: IO Bool
workflowPrReviewMergeabilityFacadeMatchesWatcher = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      commit = CommitSha "abc123"
      cleanEvidence = CleanReviewEvidence commit "LGTM"
      fixEvidence = reviewEvidenceFromSummaries ("merge latest base branch" :| []) commit
      state = SomeWatcherState (PrWaitingForMergeability prConfig cleanEvidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      matches watcherObservation facadeObservation =
        case (prReviewObserve state watcherObservation, WorkflowPrReviewMergeability.observePrReviewMergeability state facadeObservation) of
          (Right watcherTick, Right observed) ->
            watcherTick.prReviewTickEvent == observed.observedEvent
              && somePhase watcherTick.prReviewTickState == somePhase observed.observedState
              && watcherTick.prReviewTickEffects == observed.observedEffects
          _ -> False
  results <-
    sequence
      [ assert "workflow PR-review mergeability clean facade matches watcher" $
          matches
            (ObservedMergeabilityClean commit)
            (WorkflowPrReviewMergeability.MergeabilityObservedClean commit)
      , assert "workflow PR-review mergeability retry facade matches watcher" $
          matches
            (ObservedMergeabilityRetry "pending")
            (WorkflowPrReviewMergeability.MergeabilityObservedRetry "pending")
      , assert "workflow PR-review mergeability recheck facade matches watcher" $
          matches
            (ObservedMergeabilityRecheck "review changed")
            (WorkflowPrReviewMergeability.MergeabilityObservedRecheck "review changed")
      , assert "workflow PR-review mergeability fix-required facade matches watcher" $
          matches
            (ObservedMergeabilityFixRequired fixEvidence)
            (WorkflowPrReviewMergeability.MergeabilityObservedFixRequired fixEvidence)
      ]
  pure (and results)

workflowAgentRoleWrapsPrReviewWorkerClassifier :: IO Bool
workflowAgentRoleWrapsPrReviewWorkerClassifier = do
  let role =
        WorkflowAgent.AgentRole
          { WorkflowAgent.agentRoleName = "pr-review-worker"
          , WorkflowAgent.renderAgentInput = \input -> input
          , WorkflowAgent.agentOutputSchema = Nothing
          , WorkflowAgent.agentRetryPolicy = WorkflowAgent.defaultAgentRetryPolicy
          , WorkflowAgent.agentSideEffectScope = WorkflowAgent.AgentWritesWorktree
          , WorkflowAgent.agentClassifyTurn = \appTurn ->
              case classifyPrReviewWorkerTurn appTurn of
                Just output -> Right (WorkflowAgent.ClassifiedAgentOutput WorkflowAgent.AgentIncomplete output)
                Nothing -> Left "turn still running"
          }
      turn = AppServerTurn (TurnId "worker") "completed" (Just "{\"outcome\":\"incomplete\",\"reason\":\"needs tests\"}")
  assert "workflow agent role wraps existing classifier without weakening output" $
    case WorkflowAgent.classifyAgentRoleTurn role turn of
      Right (WorkflowAgent.ClassifiedAgentOutput WorkflowAgent.AgentIncomplete (ObservedWorkerOutcome (WorkerIncomplete "needs tests"))) -> True
      _ -> False

workflowAgentRolesExposeRetryAndSideEffectMetadata :: IO Bool
workflowAgentRolesExposeRetryAndSideEffectMetadata = do
  let workerRole = WorkflowPrReviewAgent.prReviewWorkerAgentRole
      reviewerRole = WorkflowPrReviewAgent.prReviewReviewerAgentRole (CommitSha "abc123")
      policy = WorkflowAgent.defaultAgentRetryPolicy
  results <-
    sequence
      [ assert "workflow worker role declares worktree side effects" $
          workerRole.agentSideEffectScope == WorkflowAgent.AgentWritesWorktree
      , assert "workflow reviewer role declares read-only side effects" $
          reviewerRole.agentSideEffectScope == WorkflowAgent.AgentReadOnly
      , assert "workflow malformed output is retry-classified" $
          WorkflowAgent.agentOutputRetryReason WorkflowAgent.AgentMalformed == Just WorkflowAgent.RetryMalformedOutput
            && WorkflowAgent.agentRetryDecision policy WorkflowAgent.RetryMalformedOutput 0 == WorkflowAgent.AgentRetryAllowed WorkflowAgent.RetryMalformedOutput
      , assert "workflow incomplete output is retry-classified" $
          WorkflowAgent.agentOutputRetryReason WorkflowAgent.AgentIncomplete == Just WorkflowAgent.RetryIncompleteOutput
            && WorkflowAgent.agentRetryDecision policy WorkflowAgent.RetryIncompleteOutput policy.agentMaxIncompleteRetries == WorkflowAgent.AgentRetryExhausted WorkflowAgent.RetryIncompleteOutput
      , assert "workflow blocked output is not automatic retry" $
          WorkflowAgent.agentOutputRetryReason WorkflowAgent.AgentBlocked == Nothing
      ]
  pure (and results)

workflowAgentCodexStartRequestsMatchCompiledEffects :: IO Bool
workflowAgentCodexStartRequestsMatchCompiledEffects = do
  let repo = RepoName "soulomoon/mlf2"
      config = effectRuntimeConfig repo "/tmp/work" 440
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      commit = CommitSha "abc123"
      evidence = reviewEvidenceFromSummaries ("fix review" :| []) commit
      thread = ThreadId "agent-thread"
      requestId = config.effectRuntimeNextRequestId
      cases =
        [ ( "planner"
          , SomeEffect (StartPlannerTurn thread)
          , MoifoldAgentRoles.plannerAgentRoleId
          )
        , ( "pr-review worker"
          , SomeEffect (StartWorkerTurn evidence thread)
          , MoifoldAgentRoles.prReviewWorkerAgentRoleId
          )
        , ( "issue plan worker"
          , SomeEffect (StartIssuePlanWorkerTurn issueConfig (PrNumber 6) thread)
          , MoifoldAgentRoles.issuePlanWorkerAgentRoleId
          )
        , ( "issue implementation worker"
          , SomeEffect (StartIssueImplementationWorkerTurn thread)
          , MoifoldAgentRoles.issueImplementationWorkerAgentRoleId
          )
        , ( "reviewer"
          , SomeEffect (StartReviewerTurn prConfig commit thread)
          , MoifoldAgentRoles.reviewerAgentRoleId
          )
        , ( "verification reviewer"
          , SomeEffect (StartReviewerVerificationTurn prConfig evidence commit thread)
          , MoifoldAgentRoles.prReviewVerificationReviewerAgentRoleId
          )
        , ( "final reviewer"
          , SomeEffect (StartIssueFinalReviewTurn issueConfig (PrNumber 6) commit thread)
          , MoifoldAgentRoles.finalReviewerAgentRoleId
          )
        ]
  results <-
    traverse
      ( \(labelText, effect, expectedRoleId) ->
          assert ("workflow Codex agent start request matches compiled effect for " <> Text.unpack labelText) $
            case (agentTurnPlanForEffect config effect, compileEffect config requestId effect) of
              (Just plan, ([PlannedAppServerRequest request], nextRequestId')) ->
                plan.agentTurnPlanRoleId == expectedRoleId
                  && request == WorkflowAgentCodexProtocol.agentTurnStartRequest requestId plan
                  && nextRequestId' == nextRequestId requestId
              _ -> False
      )
      cases
  pure (and results)

workflowAgentCodexStartsThreadsThroughTypedAdapter :: IO Bool
workflowAgentCodexStartsThreadsThroughTypedAdapter = do
  let plan =
        WorkflowAgent.AgentThreadPlan
          { WorkflowAgent.agentThreadPlanRoleId = MoifoldAgentRoles.plannerAgentRoleId
          , WorkflowAgent.agentThreadPlanCwd = "/tmp/work"
          , WorkflowAgent.agentThreadPlanApprovalPolicy = "never"
          , WorkflowAgent.agentThreadPlanSandbox = "danger-full-access"
          , WorkflowAgent.agentThreadPlanModel = "gpt-5.2"
          , WorkflowAgent.agentThreadPlanDeveloperInstructions = "plan docs migration"
          }
      requestId = RequestId 443
      response = object ["threadId" .= ("thread-1" :: Text)]
      expectedRequest =
        threadStartRequest
          requestId
          ThreadStartOptions
            { threadCwd = "/tmp/work"
            , threadApprovalPolicy = "never"
            , threadSandbox = "danger-full-access"
            , threadModel = "gpt-5.2"
            , threadDeveloperInstructions = "plan docs migration"
            }
      request = WorkflowAgentCodexProtocol.agentThreadStartRequest requestId plan
  started <-
    WorkflowAgentCodex.startAgentThread
      ( AppServerInterpreter \incomingRequest ->
          if incomingRequest == expectedRequest
            then pure response
            else pure (object ["unexpected" .= True])
      )
      requestId
      plan
  results <-
    sequence
      [ assert "workflow Codex adapter renders typed thread start request" $
          request == expectedRequest
      , assert "workflow Codex adapter parses thread start" $
          WorkflowAgentCodex.parseAgentThreadStart plan response
            == Right (WorkflowAgent.AgentThreadStart MoifoldAgentRoles.plannerAgentRoleId (ThreadId "thread-1"))
      , assert "workflow Codex adapter starts thread with interpreter" $
          started == Right (WorkflowAgent.AgentThreadStart MoifoldAgentRoles.plannerAgentRoleId (ThreadId "thread-1"))
      ]
  pure (and results)

workflowAgentCodexParsesTurnLifecycle :: IO Bool
workflowAgentCodexParsesTurnLifecycle = do
  let plan =
        WorkflowAgent.AgentTurnPlan
          { WorkflowAgent.agentTurnPlanRoleId = MoifoldAgentRoles.prReviewWorkerAgentRoleId
          , WorkflowAgent.agentTurnPlanThreadId = ThreadId "thread-1"
          , WorkflowAgent.agentTurnPlanCwd = "/tmp/work"
          , WorkflowAgent.agentTurnPlanEffort = defaultEffort
          , WorkflowAgent.agentTurnPlanModel = defaultModel
          , WorkflowAgent.agentTurnPlanApprovalPolicy = defaultApprovalPolicy
          , WorkflowAgent.agentTurnPlanSandboxPolicy = defaultSandboxPolicy
          , WorkflowAgent.agentTurnPlanInput = "fix review"
          , WorkflowAgent.agentTurnPlanOutputSchema = Nothing
          , WorkflowAgent.agentTurnPlanCollaborationMode = Nothing
          }
      turnRef =
        WorkflowAgent.TurnRef
          { WorkflowAgent.turnRefThreadId = ThreadId "thread-1"
          , WorkflowAgent.turnRefTurnId = TurnId "turn-1"
          }
      startValue = object ["turnId" .= ("turn-1" :: Text)]
      readValue =
        object
          [ "thread" .= object
              [ "status" .= object ["type" .= ("systemError" :: Text)]
              , "turns" .=
                  [ object
                      [ "id" .= ("turn-1" :: Text)
                      , "status" .= ("completed" :: Text)
                      , "output" .= ("done" :: Text)
                      ]
                  ]
              ]
          ]
      missingTurnValue =
        object ["turns" .= [object ["id" .= ("other-turn" :: Text), "status" .= ("running" :: Text)]]]
      malformedValue = object ["turn" .= object ["status" .= ("completed" :: Text)]]
      request = WorkflowAgentCodexProtocol.agentTurnStartRequest (RequestId 440) plan
      interruptRequest = WorkflowAgentCodexProtocol.agentThreadInterruptRequest (RequestId 442) turnRef
      cached =
        WorkflowAgentCodex.cachedAgentTurnStartInterpreter
          (AppServerInterpreter \_ -> pure (object ["turnId" .= ("uncached" :: Text)]))
          request
          startValue
  startedViaInterpreter <- WorkflowAgentCodex.startAgentTurn cached (RequestId 440) plan
  readViaInterpreter <-
    WorkflowAgentCodex.readAgentTurn
      (AppServerInterpreter \_ -> pure readValue)
      (RequestId 441)
      turnRef
  interruptViaInterpreter <-
    WorkflowAgentCodex.interruptAgentTurn
      (AppServerInterpreter \incomingRequest -> if incomingRequest == interruptRequest then pure Null else pure (object ["unexpected" .= True]))
      (RequestId 442)
      turnRef
  results <-
    sequence
      [ assert "workflow Codex adapter parses turn start" $
          WorkflowAgentCodex.parseAgentTurnStart plan startValue
            == Right (WorkflowAgent.AgentTurnStart MoifoldAgentRoles.prReviewWorkerAgentRoleId (ThreadId "thread-1") (TurnId "turn-1"))
      , assert "workflow Codex adapter exposes typed turn refs from starts" $
          case WorkflowAgentCodex.parseAgentTurnStart plan startValue of
            Right started ->
              (WorkflowAgent.agentTurnStartRef started :: WorkflowAgent.TurnRef TestPrReviewWorkerAgent ())
                == WorkflowAgent.TurnRef (ThreadId "thread-1") (TurnId "turn-1")
            Left _ -> False
      , assert "workflow Codex adapter cached start response is used" $
          startedViaInterpreter
            == Right (WorkflowAgent.AgentTurnStart MoifoldAgentRoles.prReviewWorkerAgentRoleId (ThreadId "thread-1") (TurnId "turn-1"))
      , assert "workflow Codex adapter renders typed thread read request" $
          WorkflowAgentCodexProtocol.agentThreadReadRequest (RequestId 441) turnRef
            == threadReadRequest (RequestId 441) (ThreadId "thread-1") True
      , assert "workflow Codex adapter parses thread read turn" $
          case readViaInterpreter of
            Right readResult ->
              readResult.agentTurnReadTurn == Just (AppServerTurn (TurnId "turn-1") "completed" (Just "done"))
                && readResult.agentTurnReadThreadSystemError == Just "systemError"
            Left _ -> False
      , assert "workflow Codex adapter reports missing active turn" $
          case WorkflowAgentCodex.parseAgentTurnReadResult turnRef missingTurnValue of
            Right readResult -> readResult.agentTurnReadTurn == Nothing
            Left _ -> False
      , assert "workflow Codex adapter renders typed interrupt request" $
          interruptRequest == turnInterruptRequest (RequestId 442) (ThreadId "thread-1") (TurnId "turn-1")
      , assert "workflow Codex adapter parses turn interrupt" $
          interruptViaInterpreter
            == Right (WorkflowAgent.AgentTurnInterrupt (ThreadId "thread-1") (TurnId "turn-1"))
      , assert "workflow Codex adapter rejects malformed turn start response" $
          case WorkflowAgentCodex.parseAgentTurnStart plan malformedValue of
            Left _ -> True
            Right _ -> False
      ]
  pure (and results)

workflowPrReviewAgentRolesClassifyOutputs :: IO Bool
workflowPrReviewAgentRolesClassifyOutputs = do
  let commit = CommitSha "abc123"
      workerRole = WorkflowPrReviewAgent.prReviewWorkerAgentRole
      reviewerRole = WorkflowPrReviewAgent.prReviewReviewerAgentRole commit
      classifiesAs role expected turn =
        case WorkflowAgent.classifyAgentRoleTurn role turn of
          Right classified -> classified.classifiedOutputClass == expected
          Left _ -> False
      cleanReviewOutput =
        reviewerStateOutput "not_applicable" "none" commit reviewerPromptVersion 0 (Just "LGTM") [] [] Nothing
      problemsReviewOutput =
        reviewerStateOutput "not_applicable" "found" commit reviewerPromptVersion 0 Nothing [] ["left summary finding"] Nothing
  results <-
    sequence
      [ assert "workflow PR-review worker role classifies complete output" $
          classifiesAs
            workerRole
            WorkflowAgent.AgentComplete
            (AppServerTurn (TurnId "worker-complete") "completed" (Just "{\"outcome\":\"complete\",\"summary\":\"done\"}"))
      , assert "workflow PR-review worker role classifies incomplete output" $
          classifiesAs
            workerRole
            WorkflowAgent.AgentIncomplete
            (AppServerTurn (TurnId "worker-incomplete") "completed" (Just "{\"outcome\":\"incomplete\",\"reason\":\"needs tests\"}"))
      , assert "workflow PR-review worker role classifies blocked output" $
          classifiesAs
            workerRole
            WorkflowAgent.AgentBlocked
            (AppServerTurn (TurnId "worker-blocked") "completed" Nothing)
      , assert "workflow PR-review worker role classifies malformed output" $
          classifiesAs
            workerRole
            WorkflowAgent.AgentMalformed
            (AppServerTurn (TurnId "worker-malformed") "completed" (Just "plain text"))
      , assert "workflow PR-review reviewer role classifies clean output" $
          classifiesAs
            reviewerRole
            WorkflowAgent.AgentClean
            (AppServerTurn (TurnId "reviewer-clean") "completed" (Just cleanReviewOutput))
      , assert "workflow PR-review reviewer role classifies problems output" $
          classifiesAs
            reviewerRole
            WorkflowAgent.AgentProblems
            (AppServerTurn (TurnId "reviewer-problems") "completed" (Just problemsReviewOutput))
      , assert "workflow PR-review reviewer role classifies malformed output" $
          classifiesAs
            reviewerRole
            WorkflowAgent.AgentMalformed
            (AppServerTurn (TurnId "reviewer-malformed") "completed" (Just "{\"result\":\"clean\"}"))
      ]
  pure (and results)

workflowAgentObservationKernelMatchesPrReviewClassifiers :: IO Bool
workflowAgentObservationKernelMatchesPrReviewClassifiers = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      workerTurn = ActiveTurn workerThread (TurnId "worker-turn")
      reviewerTurn = ActiveTurn reviewerThread (TurnId "reviewer-turn")
      commit = CommitSha "abc123"
      evidence = reviewEvidenceFromSummaries ("fix review" :| []) commit
      workerState =
        SomeWatcherState
          ( PrFixingReviews
              prConfig
              evidence
              (WorkerActive workerTurn)
              (ReviewerIdle reviewerThread)
          )
      reviewerState =
        SomeWatcherState
          ( PrReviewingClean
              prConfig
              commit
              normalReviewContext
              (WorkerIdle workerThread)
              (ReviewerActive reviewerTurn)
          )
      cleanReviewOutput =
        reviewerStateOutput "not_applicable" "none" commit reviewerPromptVersion 0 (Just "LGTM") [] [] Nothing
      problemsReviewOutput =
        reviewerStateOutput "not_applicable" "found" commit reviewerPromptVersion 0 Nothing [] ["left summary finding"] Nothing
      matchesWorker turn =
        case classifyPrReviewWorkerTurn turn of
          Just observation ->
            agentObservationPlanMatches
              workerState
              WorkflowPrReviewAgent.prReviewWorkerAgentRole
              DaemonPrReviewObservation
              turn
              (DaemonPrReviewObservation observation)
          Nothing ->
            False
      matchesReviewer turn =
        case classifyPrReviewReviewerTurn commit turn of
          Just observation ->
            agentObservationPlanMatches
              reviewerState
              (WorkflowPrReviewAgent.prReviewReviewerAgentRole commit)
              DaemonPrReviewObservation
              turn
              (DaemonPrReviewObservation observation)
          Nothing ->
            False
  results <-
    sequence
      [ assert "workflow agent observation kernel matches worker complete classifier" $
          matchesWorker (AppServerTurn (TurnId "worker-turn") "completed" (Just "{\"outcome\":\"complete\",\"summary\":\"done\"}"))
      , assert "workflow agent observation kernel matches worker incomplete classifier" $
          matchesWorker (AppServerTurn (TurnId "worker-turn") "completed" (Just "{\"outcome\":\"incomplete\",\"reason\":\"needs tests\"}"))
      , assert "workflow agent observation kernel matches worker blocked classifier" $
          matchesWorker (AppServerTurn (TurnId "worker-turn") "completed" Nothing)
      , assert "workflow agent observation kernel matches worker malformed classifier" $
          matchesWorker (AppServerTurn (TurnId "worker-turn") "completed" (Just "plain text"))
      , assert "workflow agent observation kernel matches reviewer clean classifier" $
          matchesReviewer (AppServerTurn (TurnId "reviewer-turn") "completed" (Just cleanReviewOutput))
      , assert "workflow agent observation kernel matches reviewer problems classifier" $
          matchesReviewer (AppServerTurn (TurnId "reviewer-turn") "completed" (Just problemsReviewOutput))
      , assert "workflow agent observation kernel matches reviewer malformed classifier" $
          matchesReviewer (AppServerTurn (TurnId "reviewer-turn") "completed" (Just "{\"result\":\"clean\"}"))
      ]
  pure (and results)

workflowPlanObservationLawHoldsForPrReviewAgentObservation :: IO Bool
workflowPlanObservationLawHoldsForPrReviewAgentObservation = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      workerTurn = ActiveTurn workerThread (TurnId "worker-turn")
      commit = CommitSha "abc123"
      evidence = reviewEvidenceFromSummaries ("fix review" :| []) commit
      state =
        SomeWatcherState
          ( PrFixingReviews
              prConfig
              evidence
              (WorkerActive workerTurn)
              (ReviewerIdle reviewerThread)
          )
      turn = AppServerTurn (TurnId "worker-turn") "completed" (Just "{\"outcome\":\"complete\",\"summary\":\"done\"}")
      observation =
        WorkflowObservationAgent.classifiedAgentTurnObservationPayload
          WorkflowPrReviewAgent.prReviewWorkerAgentRole
          DaemonPrReviewObservation
          turn
  assert "workflow observation law holds for PR-review agent output" $
    case observation of
      Just daemonObservation ->
        case (workflowObserve @MoifoldSpec state daemonObservation, workflowPlanObservation @MoifoldSpec state daemonObservation) of
          (Right observed, Right planned) ->
            case workflowApplyEvent @MoifoldSpec state planned.plannedEvent of
              Right (appliedState, replayedEffects) ->
                someDomain appliedState == someDomain observed.observedState
                  && somePhase appliedState == somePhase observed.observedState
                  && replayedEffects == planned.plannedPreCommitEffects <> planned.plannedPostCommitEffects
              Left _ -> False
          _ -> False
      Nothing -> False

agentObservationPlanMatches
  :: SomeWatcherState
  -> WorkflowAgent.AgentRole input PrReviewObservation
  -> (PrReviewObservation -> DaemonObservation)
  -> AppServerTurn
  -> DaemonObservation
  -> Bool
agentObservationPlanMatches state role toObservation turn expectedObservation =
  case (oldPlan, newPlan) of
    (Right old, Right new) ->
      old.plannedEvent == new.plannedEvent
        && old.plannedPreCommitEffects == new.plannedPreCommitEffects
        && old.plannedPostCommitEffects == new.plannedPostCommitEffects
    _ ->
      False
 where
  oldPlan =
    legacyObservedPlannedTransition <$> observeDaemonState state expectedObservation
  newPlan =
    WorkflowObservationAgent.planAgentTurnObservation @MoifoldSpec state role toObservation turn
