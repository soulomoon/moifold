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

module WorkflowEventLogSpec
  ( workflowEventLogTests
  )
where


import CodexWatcher.AppServerProtocol
import CodexWatcher.ActionExecutor
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
import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))
import CodexWatcher.Workflow.Codec qualified as WorkflowCodec
import CodexWatcher.Workflow.Daemon.Core qualified as WorkflowDaemon
import CodexWatcher.Workflow.DSL qualified as WorkflowDSL
import CodexWatcher.Workflow.DocsMigration qualified as DocsMigration
import CodexWatcher.Workflow.Audit qualified as WorkflowAudit
import CodexWatcher.Workflow.EventLog.Commit.Core qualified as WorkflowEventLogCommit
import CodexWatcher.Workflow.EventLog.Core qualified as WorkflowEventLogCore
import CodexWatcher.Workflow.EventLog.File.Core qualified as WorkflowEventLogFileCore
import CodexWatcher.Workflow.Execution qualified as WorkflowExecution
import CodexWatcher.Workflow.Execution.Core qualified as WorkflowExecutionCore
import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..), ReviewThreadId (..))
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

workflowEventLogTests :: IO Bool
workflowEventLogTests =
  sequenceAnd
    [ workflowEventCodecContractCoversWatcherEvents
    , workflowEventCodecToleratesMetadataAndPreservesGoldenTypes
    , workflowEventLogCommitCoreEncodesAndAppendsBeforeSuccess
    , workflowEventLogFileCoreNumberingIgnoresBlankLines
    , workflowEventLogFileCoreDecodeFailureReportsSourceLine
    , workflowEventLogFileWrapperDecodesExistingFixtures
    , workflowEventLogFileWrapperFormatsMalformedErrors
    , workflowEventLogCoreDetailedReplayMatchesMoifold
    , workflowEventLogCoreFixtureContractValidatesReplay
    , workflowEventLogCoreTransitionContractsUseDirectReplay
    , workflowEventLogFailureAuditClassifiesRetryRecommendation
    ]

goldenEventLogFixturePaths :: [FilePath]
goldenEventLogFixturePaths =
  [ "golden/event-log/pr-review/mlf2-pr6-merged/events.jsonl"
  , "golden/event-log/pr-review/mlf2-pr6-reviewer-comments/events.jsonl"
  , "golden/event-log/pr-review/mlf2-pr6-worker-incomplete/events.jsonl"
  , "golden/event-log/pr-review/mlf2-pr6-reviewer-incomplete/events.jsonl"
  , "golden/event-log/issue-implement/mlf2-issue42-complete/events.jsonl"
  , "golden/event-log/issue-implement/mlf2-issue42-pr-created/events.jsonl"
  , "golden/event-log/issue-implement/mlf2-issue42-pr-reused/events.jsonl"
  , "golden/event-log/issue-implement/mlf2-issue42-incomplete-then-complete/events.jsonl"
  , "golden/event-log/issue-implement/mlf2-issue42-implementation-blocked/events.jsonl"
  , "golden/event-log/issue-planning/mlf2-planning-ready/events.jsonl"
  ]


canonicalEventExamples :: [WatcherEvent]
canonicalEventExamples =
  [ IssuePlanningInitialized plannerConfig
  , IssuePlanningTurnStarted plannerThread plannerTurn
  , IssuePlanningIssuesRequested (IssueCreationRequest "Subissue title" "Subissue body" Nothing :| [])
  , IssuePlanningGraphUpdated planningGraph
  , IssuePlanningReadyIssuesFixed
  , IssuePlanningTurnRetryRequested blockedReason
  , IssuePlanningTurnCompleted
  , PrReviewInitialized prConfig workerThread reviewerThread
  , PrReviewUnresolvedFound (ReviewThreadId "review-thread-1" :| [ReviewThreadId "review-thread-2"]) commit workerTurn
  , PrReviewFeedbackFound (reviewEvidenceFromSummaries ("worker feedback" :| []) commit) workerTurn
  , PrReviewNoUnresolvedFound commit reviewerTurn
  , PrReviewFixCompleted
  , PrReviewFixIncomplete "worker marked incomplete"
  , PrReviewCleanFound cleanEvidence []
  , PrReviewMergeabilityWaiting "mergeability still unstable"
  , PrReviewMergeabilityRecheck "reviewed head changed"
  , PrReviewMergeabilityFixRequired (reviewEvidenceFromSummaries ("merge latest base branch into the PR branch" :| []) commit)
  , PrReviewMergeabilityClean commit
  , PrReviewProblemsAdded (reviewEvidenceFromSummaries ("reviewer reported problems" :| []) commit) []
  , PrReviewReviewIncomplete "reviewer state missing required fields"
  , PrReviewMergeCompleted mergeCommit
  , IssueImplementInitialized issueConfig workerThread
  , IssueAttemptBranchAdvancedEvent (BranchName "codex/issue-42-2")
  , IssuePullRequestCreatedEvent prNumber
  , IssuePullRequestReusedEvent prNumber
  , IssuePlanTurnStartedEvent plannerTurn
  , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
  , IssuePlanCompletedEvent sampleIssuePlanMarkdown (Just implementationTurn)
  , IssuePullRequestBodyUpdatedEvent prNumber
  , IssueImplementationTurnStartedEvent implementationTurn
  , IssueImplementationIncompleteEvent "implementation incomplete"
  , IssueImplementationBlockedEvent blockedReason
  , IssueReviewHandoffInitializedEvent prNumber
  , IssueReviewHandoffStartedEvent prNumber
  , IssueImplementationCompletedEvent prNumber Nothing
  , IssuePullRequestMergedEvent prNumber
  , IssueReviewerThreadReadyEvent reviewerThread
  , IssuePostMergeReviewStartedEvent commit reviewerTurn
  , IssuePostMergeReviewCleanEvent cleanEvidence
  , IssuePostMergeReviewFollowUpEvent (reviewEvidenceFromSummaries ("follow-up" :| []) commit)
  , IssuePostMergeReviewIncompleteEvent "review incomplete"
  , IssueClosedEvent prNumber
  , WatcherRecoveredInvalidState "synthetic recovery marker"
  , WatcherBlocked blockedReason
  , WatcherStopped stopReason
  ]
 where
  repo = RepoName "owner/name"
  plannerConfig = PlannerConfig repo (maxParallelForTest 8) []
  issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
  prNumber = PrNumber 7
  prConfig = PrConfig repo prNumber (BranchName "codex/pr-7")
  plannerThread = ThreadId "planner-thread"
  workerThread = ThreadId "worker-thread"
  reviewerThread = ThreadId "reviewer-thread"
  plannerTurn = TurnId "turn-plan"
  implementationTurn = TurnId "turn-implement"
  workerTurn = TurnId "turn-worker"
  reviewerTurn = TurnId "turn-reviewer"
  commit = CommitSha "0123456789abcdef"
  cleanEvidence = CleanReviewEvidence commit "LGTM"
  mergeCommit = MergeCommit (CommitSha "fedcba9876543210")
  blockedReason = BlockedReason "blocked for test"
  stopReason = StopReason "stopped for test"
  planningGraph =
    PlanningGraph
      [IssueNumber 42]
      [BlockedPlanningIssue (IssueNumber 43) [IssueNumber 42] "wait for dependency"]
      [IssueDependency (IssueNumber 43) [IssueNumber 42]]

workflowEventCodecContractCoversWatcherEvents :: IO Bool
workflowEventCodecContractCoversWatcherEvents = do
  results <-
    traverse
      ( \event ->
          assert ("workflow event codec round-trips " <> Text.unpack (eventName event)) $
            WorkflowCodec.workflowCodecEventTypeLabel watcherEventCodecContract event == WorkflowCodec.WorkflowEventTypeLabel (eventName event)
              && WorkflowCodec.workflowCodecSchemaVersion watcherEventCodecContract event == WorkflowCodec.WorkflowSchemaVersion 1
              && WorkflowCodec.validateWorkflowCodecEncodedTypeLabel watcherEventCodecContract event == Right ()
              && WorkflowCodec.validateWorkflowCodecRoundTrip watcherEventCodecContract event == Right ()
      )
      canonicalEventExamples
  pure (and results)

workflowEventCodecToleratesMetadataAndPreservesGoldenTypes :: IO Bool
workflowEventCodecToleratesMetadataAndPreservesGoldenTypes = do
  metadataResults <-
    traverse
      ( \event ->
          assert ("workflow event codec tolerates metadata for " <> Text.unpack (eventName event)) $
            WorkflowCodec.workflowCodecDecode watcherEventCodecContract (withUnknownMetadata (toJSON event)) == Right event
      )
      canonicalEventExamples
  goldenResults <- traverse goldenEventLogTypeFieldsMatchDecodedEvents goldenEventLogFixturePaths
  pure (and metadataResults && and goldenResults)

withUnknownMetadata :: Value -> Value
withUnknownMetadata (Object objectValue) =
  Object
    ( KeyMap.insert (Key.fromText "emittedAt") (String "2026-05-07T00:00:00Z")
        ( KeyMap.insert (Key.fromText "schemaVersion") (Number 1)
            (KeyMap.insert (Key.fromText "unknownMetadata") (String "ignored") objectValue)
        )
    )
withUnknownMetadata value =
  value

goldenEventLogTypeFieldsMatchDecodedEvents :: FilePath -> IO Bool
goldenEventLogTypeFieldsMatchDecodedEvents path = do
  bytes <- LazyByteString.readFile path
  let lines' = filter (not . Text.null . Text.strip) (Text.lines (Text.Encoding.decodeUtf8 (LazyByteString.toStrict bytes)))
      decodedLines =
        traverse
          ( \lineText -> do
              value <- eitherDecodeStrict' (Text.Encoding.encodeUtf8 lineText) :: Either String Value
              event <- eitherDecodeStrict' (Text.Encoding.encodeUtf8 lineText) :: Either String WatcherEvent
              pure (value, event)
          )
          lines'
      typeMatches (Object objectValue, event) =
        KeyMap.lookup (Key.fromText "type") objectValue == Just (String (eventName event))
      typeMatches _ =
        False
  assert ("workflow event-log golden type fields unchanged " <> path) $
    case decodedLines of
      Right values -> all typeMatches values
      Left _ -> False

workflowEventLogCommitCoreEncodesAndAppendsBeforeSuccess :: IO Bool
workflowEventLogCommitCoreEncodesAndAppendsBeforeSuccess = do
  calls <- newIORef []
  let record call = modifyIORef' calls (<> [call])
      encodeEvent event = do
        record ("encode:" <> event)
        pure ("encoded:" <> event)
      appendEncoded encoded =
        record ("append:" <> encoded)
      committer :: WorkflowEventLogCommit.WorkflowEventCommitter IO Text Text
      committer =
        WorkflowEventLogCommit.workflowEncodedEventCommitter encodeEvent appendEncoded
  result <- WorkflowEventLogCommit.commitWorkflowEvent committer "event"
  recorded <- readIORef calls
  assert "workflow event-log commit core encodes once and appends before success" $
    result == Right ()
      && recorded == ["encode:event", "append:encoded:event"]

workflowEventLogFileCoreNumberingIgnoresBlankLines :: IO Bool
workflowEventLogFileCoreNumberingIgnoresBlankLines =
  let input = Text.Encoding.encodeUtf8 "\nfirst\n  \n\t\r\nsecond\n"
      expected = [(2, "first"), (5, "second")]
   in assert
        "workflow event-log file core ignores blank lines and preserves source line numbers"
        (WorkflowEventLogFileCore.numberedNonBlankWorkflowEventLogLines input == expected)

workflowEventLogFileCoreDecodeFailureReportsSourceLine :: IO Bool
workflowEventLogFileCoreDecodeFailureReportsSourceLine =
  let input = Text.Encoding.encodeUtf8 "ok\n  \nbad\n"
      decodeLine line =
        let lineText = Text.Encoding.decodeUtf8 line
         in if lineText == "bad"
              then Left "bad token"
              else Right lineText
      decoded = WorkflowEventLogFileCore.decodeWorkflowEventLogLines decodeLine input
   in assert "workflow event-log file core decode failure reports original source line" $
        case decoded of
          Left failure ->
            WorkflowEventLogFileCore.workflowEventLogLineDecodeErrorLineNumber failure == 3
              && WorkflowEventLogFileCore.workflowEventLogLineDecodeErrorReason failure == "bad token"
              && WorkflowEventLogFileCore.formatWorkflowEventLogLineDecodeError failure == "line 3: bad token"
          Right _ -> False

workflowEventLogFileWrapperDecodesExistingFixtures :: IO Bool
workflowEventLogFileWrapperDecodesExistingFixtures = do
  results <-
    traverse
      ( \path -> do
          loaded <- loadEventLogFile path
          assert ("workflow event-log file wrapper decodes existing fixture " <> path) $
            case loaded of
              Right events -> not (null events)
              Left _ -> False
      )
      goldenEventLogFixturePaths
  pure (and results)

workflowEventLogFileWrapperFormatsMalformedErrors :: IO Bool
workflowEventLogFileWrapperFormatsMalformedErrors = do
  let stateDir = "/tmp/moifold-event-log-file-wrapper"
      eventsPath = stateDir </> "events.jsonl"
      badLine = "not-json"
  stateDirExists <- doesDirectoryExist stateDir
  when stateDirExists (removePathForcibly stateDir)
  createDirectoryIfMissing True stateDir
  writeFile eventsPath "\n  \nnot-json\n"
  loaded <- loadEventLogFile eventsPath
  let expected =
        case eitherDecodeStrict' (Text.Encoding.encodeUtf8 badLine) :: Either String WatcherEvent of
          Left rawError -> Left ("line 3: " <> rawError)
          Right _ -> Left "unexpected valid malformed event-log line"
  assert "workflow event-log file wrapper preserves malformed line error formatting" (loaded == expected)

workflowEventLogCoreDetailedReplayMatchesMoifold :: IO Bool
workflowEventLogCoreDetailedReplayMatchesMoifold = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      commit = CommitSha "abc123"
      cleanEvidence = CleanReviewEvidence commit "LGTM"
      events =
        [ PrReviewInitialized prConfig workerThread reviewerThread
        , PrReviewNoUnresolvedFound commit (TurnId "reviewer-turn")
        , PrReviewCleanFound cleanEvidence []
        ]
      direct = replayEventLog events
      detailed = WorkflowEventLogCore.replayWorkflowEventLogDetailed @MoifoldSpec id events
  assert "workflow event-log core detailed replay matches moifold replay" $
    case (direct, detailed) of
      (Right replay, Right summary) ->
        someDomain replay.replayState == someDomain summary.workflowReplaySummaryState
          && somePhase replay.replayState == somePhase summary.workflowReplaySummaryState
          && replay.replayEffects == summary.workflowReplaySummaryEffects
          && summary.workflowReplaySummaryEventCount == length events
          && summary.workflowReplaySummaryTerminalEventIndex == Nothing
      _ -> False

workflowEventLogCoreFixtureContractValidatesReplay :: IO Bool
workflowEventLogCoreFixtureContractValidatesReplay = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      events =
        [ PrReviewInitialized prConfig (ThreadId "worker") (ThreadId "reviewer")
        , PrReviewNoUnresolvedFound (CommitSha "abc123") (TurnId "reviewer-turn")
        , PrReviewCleanFound (CleanReviewEvidence (CommitSha "abc123") "LGTM") []
        ]
      contract =
        WorkflowEventLogCore.EventLogFixtureContract
          { WorkflowEventLogCore.fixtureExpectedStateLabel = "PrReview/WaitingMergeability"
          , WorkflowEventLogCore.fixtureExpectedEventCount = Just 3
          }
  assert "workflow event-log core fixture contract validates replay summary" $
    case WorkflowEventLogCore.replayWorkflowEventLogDetailed @MoifoldSpec id events of
      Right summary -> WorkflowEventLogCore.validateEventLogFixtureContract @MoifoldSpec contract summary == Right ()
      Left _ -> False

workflowEventLogCoreTransitionContractsUseDirectReplay :: IO Bool
workflowEventLogCoreTransitionContractsUseDirectReplay = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      initialized = PrReviewInitialized prConfig (ThreadId "worker") (ThreadId "reviewer")
      noUnresolved = PrReviewNoUnresolvedFound (CommitSha "abc123") (TurnId "reviewer-turn")
      moifoldCoreInitial = WorkflowEventLogCore.initializeWorkflowEvent @MoifoldSpec id initialized
      moifoldReplayInitial = WorkflowEventLogCore.replayWorkflowEventLogDetailed @MoifoldSpec id [initialized]
      moifoldReplayApplied = WorkflowEventLogCore.replayWorkflowEventLogDetailed @MoifoldSpec id [initialized, noUnresolved]
      docsConfig =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      docsInitialized = DocsMigration.DocsMigrationInitialized docsConfig
      docsTurnStarted = DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")
      docsCoreInitial = WorkflowEventLogCore.initializeWorkflowEvent @DocsMigration.DocsMigrationSpec id docsInitialized
  results <-
    sequence
      [ assert "workflow event-log core initialize matches direct replay summary" $
          case (moifoldCoreInitial, moifoldReplayInitial) of
            (Right (coreState, coreEffects), Right summary) ->
              someDomain coreState == someDomain summary.workflowReplaySummaryState
                && somePhase coreState == somePhase summary.workflowReplaySummaryState
                && [coreEffects] == summary.workflowReplaySummaryEffects
                && summary.workflowReplaySummaryEventCount == 1
            _ -> False
      , assert "workflow event-log core apply matches direct replay summary" $
          case (moifoldCoreInitial, moifoldReplayApplied) of
            (Right (coreState, initialEffects), Right summary) ->
              case WorkflowEventLogCore.applyWorkflowEvent @MoifoldSpec id coreState noUnresolved of
                Right (coreState', coreEffects) ->
                  someDomain coreState' == someDomain summary.workflowReplaySummaryState
                    && somePhase coreState' == somePhase summary.workflowReplaySummaryState
                    && [initialEffects, coreEffects] == summary.workflowReplaySummaryEffects
                    && summary.workflowReplaySummaryEventCount == 2
                _ -> False
            _ -> False
      , assert "workflow event-log core transition failure records moifold state and event labels" $
          case moifoldCoreInitial of
            Right (state, _) ->
              case WorkflowEventLogCore.applyWorkflowEvent @MoifoldSpec id state initialized of
                Left failure ->
                  WorkflowEventLogCore.workflowTransitionEventLabel failure == "pr_review_initialized"
                    && WorkflowEventLogCore.workflowTransitionPriorStateLabel failure == Just (workflowStateLabel @MoifoldSpec state)
                    && not (Text.null (WorkflowEventLogCore.workflowTransitionReason failure))
                Right _ -> False
            Left _ -> False
      , assert "workflow event-log core initializes docs-migration workflow" $
          case docsCoreInitial of
            Right (state, effects) ->
              state == DocsMigration.DocsMigrationReady docsConfig
                && effects == [DocsMigration.StartDocsMigrationTurn docsConfig]
            Left _ -> False
      , assert "workflow event-log core applies docs-migration workflow" $
          case docsCoreInitial of
            Right (state, _) ->
              case WorkflowEventLogCore.applyWorkflowEvent @DocsMigration.DocsMigrationSpec id state docsTurnStarted of
                Right (state', effects) ->
                  state' == DocsMigration.DocsMigrationTurnActive docsConfig (WorkflowAgent.TurnRef (ThreadId "docs-thread") (TurnId "docs-turn"))
                    && effects == []
                Left _ -> False
            Left _ -> False
      , assert "workflow event-log core transition failure records docs-migration state and event labels" $
          case docsCoreInitial of
            Right (state, _) ->
              case WorkflowEventLogCore.applyWorkflowEvent @DocsMigration.DocsMigrationSpec id state (DocsMigration.DocsMigrationValidationPassed "too early") of
                Left failure ->
                  WorkflowEventLogCore.workflowTransitionEventLabel failure == "docs-migration-validation-passed"
                    && WorkflowEventLogCore.workflowTransitionPriorStateLabel failure == Just "ready"
                    && "ready" `Text.isInfixOf` WorkflowEventLogCore.formatWorkflowTransitionFailure failure
                Right _ -> False
            Left _ -> False
      ]
  pure (and results)



workflowEventLogFailureAuditClassifiesRetryRecommendation :: IO Bool
workflowEventLogFailureAuditClassifiesRetryRecommendation = do
  let repo = RepoName "soulomoon/mlf2"
      plannerConfig = PlannerConfig repo (maxParallelForTest 2) []
      priorState = SomeWatcherState (PlanningReady plannerConfig :: WatcherState 'IssuePlanning 'Initialized)
      observation = DaemonIssuePlanningObservation (ObservedPlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn"))
      classification = FailureClassification TransientFailure "network EOF"
      audit =
        WorkflowAudit.workflowFailureAudit @MoifoldSpec
          failureIsRetryable
          priorState
          (Just observation)
          Nothing
          Nothing
          []
          []
          classification
  assert "workflow event-log failure audit classifies retry recommendation" $
    WorkflowAudit.workflowAuditPriorStateLabel audit == "IssuePlanning/Initialized"
      && maybe False ("ObservedPlanningTurnStarted" `Text.isInfixOf`) (WorkflowAudit.workflowAuditObservationLabel audit)
      && WorkflowAudit.workflowAuditFailureClassification audit == Just classification
      && WorkflowAudit.workflowAuditNextDaemonRecommendation audit == WorkflowAudit.WorkflowDaemonRetry
