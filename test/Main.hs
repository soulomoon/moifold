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
{-# OPTIONS_GHC -Wno-orphans #-}

module Main (main) where

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
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (..), RuntimeCommandSpec (..))
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
import CodexWatcher.Workflow.GitHub.Command qualified as WorkflowGitHubCommand
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
import Data.Char (isAlphaNum)
import Data.Foldable qualified as Foldable
import Data.IORef
import Data.Kind (Type)
import Data.List (sort, (\\))
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import Data.Text.IO qualified as TextIO
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), addUTCTime, getCurrentTime, secondsToDiffTime)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory, removePathForcibly)
import System.FilePath (dropExtension, makeRelative, splitDirectories, (</>))
import System.Exit (ExitCode (..), exitFailure)
import System.Posix.Process (getProcessID)
import Test.QuickCheck
import AppServerSpec
  ( prop_appServerClientInitializesSingleRequestSessions
  , prop_appServerClientDetectsSystemErrorThreadStatus
  , prop_appServerClientMatchesSuccessResponse
  , prop_appServerClientMaterializationFallbackMarksSyntheticResponse
  , prop_appServerClientMaterializationFallbackRetriesWithoutTurns
  , prop_appServerClientParsesNestedThreadReadTurns
  , prop_appServerClientParsesThreadReadTurns
  , prop_appServerClientParsesThreadStartThreadId
  , prop_appServerClientStartsThreadWithInterpreter
  , prop_appServerClientParsesTurnStartTurnId
  , prop_appServerClientRejectsMalformedThreadStartThreadId
  , prop_appServerClientRejectsMalformedTurnStartTurnId
  , prop_appServerClientRejectsMismatchedResponseIds
  , prop_appServerClientRejectsUnsupportedJsonRpcVersion
  , prop_appServerClientSkipsNotifications
  , prop_appServerClientSurfacesJsonRpcErrors
  , prop_appServerInitializeRequestMatchesJsonRpc
  , prop_appServerInitializedNotificationMatchesJsonRpc
  , prop_appServerThreadReadAndInterruptUseThreadIds
  , prop_appServerThreadStartKeepsNodeNullFields
  , prop_appServerTurnStartOmitsAbsentOutputSchema
  , prop_appServerTurnStartPlanModeEncodesCollaborationMode
  )
import CliSpec
  ( prop_cliParsesAppServerProbe
  , prop_cliParsesGenericRunnerGuardDomains
  , prop_cliParsesHealthcheckAndRunLoop
  , prop_cliRejectsBadDomain
  )
import HealthcheckSpec
  ( prop_healthcheckDaemonRequiredStatuses
  , prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork
  , prop_healthcheckIssueImplementLifecycleReporting
  , prop_healthcheckSingletonDomains
  , prop_healthcheckSummaryJsonKeepsKindField
  , prop_healthcheckTypedAnalyzerDispatch
  )
import GhGitSpec
  ( prop_ghGitParsesGitOutputs
  , prop_ghGitParsesIssueAndPrLists
  , prop_ghGitParsesPrCreateAndChecks
  , prop_ghGitParsesRemotePrMetadataVariants
  , prop_ghGitParsesRemoteIssueView
  , prop_ghGitParsesRemotePrView
  , prop_ghGitParsesReviewThreadsGraphql
  )
import JsonPathSpec (prop_jsonPathHelpersDecodeNestedValues)
import RuntimeSpec
  ( prop_runtimeCommandSpecsHaveExecutable
  , prop_runtimeDefaultsCentralizeThreadAndTurnOptions
  , prop_runtimeGhIssueCreateUsesRepoTitleAndBody
  , prop_runtimeGhIssueCreateWithParentLinksSubIssue
  , prop_runtimeGhIssueCloseCommentsAndCloses
  , prop_runtimeGhPrBodyUpdateUsesPlanFile
  , prop_runtimeGhPrCreateKeepsStdoutJsonOnly
  , prop_runtimeGhPrCommentReviewFindingsUsesPrComment
  , prop_runtimeGhReplyReviewThreadUsesGraphqlMutation
  , prop_runtimeGhPrCleanReviewAndMergeCommentsBeforeMerge
  , prop_runtimeGhPrChecksUsesCurrentCli
  , prop_runtimeGhPrMergeUsesAdapterFlags
  , prop_runtimeGhPrViewUsesStructuredFields
  , prop_runtimeGhReviewThreadCommandsUseGraphql
  , prop_runtimeGitPushDryRunNeverForces
  , prop_runtimeGitPushNeverForces
  , prop_runtimeKillZeroOnlyChecksPid
  , runtimeProcessSpecCapturesStreamsAndExit
  )

instance Arbitrary RepoName where
  arbitrary = RepoName . Text.pack <$> listOf1 (elements (['a' .. 'z'] <> ['/', '-']))

instance Arbitrary IssueNumber where
  arbitrary = IssueNumber . getPositive <$> arbitrary

instance Arbitrary PrNumber where
  arbitrary = PrNumber . getPositive <$> arbitrary

instance Arbitrary ThreadId where
  arbitrary = ThreadId . Text.pack <$> listOf1 (elements ['a' .. 'z'])

instance Arbitrary TurnId where
  arbitrary = TurnId . Text.pack <$> listOf1 (elements ['a' .. 'z'])

instance Arbitrary BranchName where
  arbitrary = BranchName . ("codex/" <>) . Text.pack <$> listOf1 (elements ['a' .. 'z'])

instance Arbitrary ReviewThreadId where
  arbitrary = ReviewThreadId . Text.pack <$> listOf1 (elements ['a' .. 'z'])

instance Arbitrary CommitSha where
  arbitrary = CommitSha . Text.pack <$> vectorOf 12 (elements (['a' .. 'f'] <> ['0' .. '9']))

instance Arbitrary MergeCommit where
  arbitrary = MergeCommit <$> arbitrary

instance Arbitrary BlockedReason where
  arbitrary = BlockedReason . Text.pack <$> listOf1 (elements (['a' .. 'z'] <> [' ']))

instance Arbitrary StopReason where
  arbitrary = StopReason . Text.pack <$> listOf1 (elements (['a' .. 'z'] <> [' ']))

instance Arbitrary PlannerConfig where
  arbitrary = PlannerConfig <$> arbitrary <*> (maxParallelForTest . getPositive <$> arbitrary) <*> arbitrary

maxParallelForTest :: Int -> MaxParallel
maxParallelForTest value =
  case mkMaxParallel value of
    Just parsed -> parsed
    Nothing -> error ("invalid test maxParallel: " <> show value)

staleSecondsForTest :: Int -> StaleSeconds
staleSecondsForTest value =
  case mkStaleSeconds value of
    Just parsed -> parsed
    Nothing -> error ("invalid test stale seconds: " <> show value)

pollSecondsForTest :: Int -> PollSeconds
pollSecondsForTest value =
  case mkPollSeconds value of
    Just parsed -> parsed
    Nothing -> error ("invalid test poll seconds: " <> show value)

sequenceAnd :: [IO Bool] -> IO Bool
sequenceAnd =
  fmap and . sequence

instance Arbitrary IssueCreationRequest where
  arbitrary = do
    title <- Text.pack <$> listOf1 (elements (['a' .. 'z'] <> [' ', '-']))
    parent <- arbitrary
    body <-
      Text.pack
        <$> case parent of
          Just _ -> listOf1 (elements (['a' .. 'z'] <> [' ', '-']))
          Nothing -> listOf (elements (['a' .. 'z'] <> [' ', '-']))
    pure (IssueCreationRequest title body parent)

instance Arbitrary IssueDependency where
  arbitrary = IssueDependency <$> arbitrary <*> listOf arbitrary

instance Arbitrary BlockedPlanningIssue where
  arbitrary =
    BlockedPlanningIssue
      <$> arbitrary
      <*> listOf arbitrary
      <*> (Text.pack <$> listOf (elements (['a' .. 'z'] <> [' ', '-'])))

instance Arbitrary PlanningGraph where
  arbitrary = PlanningGraph <$> listOf arbitrary <*> listOf arbitrary <*> listOf arbitrary

validPlanningGraphForConfig :: PlannerConfig -> PlanningGraph
validPlanningGraphForConfig config =
  PlanningGraph [validReadyIssueForConfig config] [] []

validReadyIssueForConfig :: PlannerConfig -> IssueNumber
validReadyIssueForConfig config =
  case plannerScopeIssues config of
    issue : _ -> issue
    [] -> IssueNumber 1

instance Arbitrary IssueConfig where
  arbitrary = IssueConfig <$> arbitrary <*> arbitrary <*> arbitrary

instance Arbitrary PrConfig where
  arbitrary = PrConfig <$> arbitrary <*> arbitrary <*> arbitrary

instance Arbitrary ActiveTurn where
  arbitrary = ActiveTurn <$> arbitrary <*> arbitrary

instance Arbitrary ReviewFinding where
  arbitrary =
    oneof
      [ (`ReviewThreadFinding` Nothing) <$> arbitrary
      , (\threadId comment -> ReviewThreadCommentFinding threadId Nothing comment) <$> arbitrary <*> (Text.pack <$> listOf1 (elements ['a' .. 'z']))
      , ReviewSummaryFinding . Text.pack <$> listOf1 (elements ['a' .. 'z'])
      ]

instance Arbitrary ReviewEvidence where
  arbitrary = ReviewEvidence <$> ((:|) <$> arbitrary <*> listOf arbitrary) <*> arbitrary

instance Arbitrary CleanReviewEvidence where
  arbitrary = CleanReviewEvidence <$> arbitrary <*> pure "LGTM"

sampleIssuePlanMarkdown :: Text
sampleIssuePlanMarkdown =
  "Implement the issue in small verified steps."

sampleIssuePlanFile :: IssueConfig -> PrNumber -> Text
sampleIssuePlanFile issueConfig prNumber =
  Text.unlines
    [ "---"
    , "issue_number: " <> Text.pack (show (unIssueNumber issueConfig.issueNumber))
    , "pr_number: " <> Text.pack (show (unPrNumber prNumber))
    , "branch: " <> unBranchName issueConfig.issueBranch
    , "---"
    , ""
    , sampleIssuePlanMarkdown
    ]

data EffectTag
  = ReadOpenIssuesTag
  | ReadOpenPullRequestsTag
  | ReadReviewThreadsTag
  | StartPlannerTurnTag
  | StartWorkerTurnTag
  | StartIssuePlanWorkerTurnTag
  | StartIssueImplementationWorkerTurnTag
  | StartReviewerTurnTag
  | StartReviewerVerificationTurnTag
  | StartIssueFinalReviewTurnTag
  | PushBranchTag
  | CreateIssueTag
  | CreatePullRequestTag
  | UpdatePullRequestBodyTag
  | CloseIssueTag
  | UpdateIssueFollowUpTag
  | ResolveReviewThreadTag
  | ReplyReviewThreadTag
  | PublishReviewFindingsTag
  | RecordIssuePlanTag
  | RecordPlanningGraphTag
  | RecordBlockedTag
  | MergePullRequestTag
  | StopDaemonTag
  | SleepUntilNextPollTag
  deriving stock (Eq, Show)

effectTag :: SomeEffect -> EffectTag
effectTag = \case
  SomeEffect ReadOpenIssues {} -> ReadOpenIssuesTag
  SomeEffect ReadOpenPullRequests {} -> ReadOpenPullRequestsTag
  SomeEffect ReadReviewThreads {} -> ReadReviewThreadsTag
  SomeEffect StartPlannerTurn {} -> StartPlannerTurnTag
  SomeEffect StartWorkerTurn {} -> StartWorkerTurnTag
  SomeEffect StartIssuePlanWorkerTurn {} -> StartIssuePlanWorkerTurnTag
  SomeEffect StartIssueImplementationWorkerTurn {} -> StartIssueImplementationWorkerTurnTag
  SomeEffect StartReviewerTurn {} -> StartReviewerTurnTag
  SomeEffect StartReviewerVerificationTurn {} -> StartReviewerVerificationTurnTag
  SomeEffect StartIssueFinalReviewTurn {} -> StartIssueFinalReviewTurnTag
  SomeEffect PushBranch {} -> PushBranchTag
  SomeEffect CreateIssue {} -> CreateIssueTag
  SomeEffect CreatePullRequest {} -> CreatePullRequestTag
  SomeEffect UpdatePullRequestBody {} -> UpdatePullRequestBodyTag
  SomeEffect CloseIssue {} -> CloseIssueTag
  SomeEffect UpdateIssueFollowUp {} -> UpdateIssueFollowUpTag
  SomeEffect ResolveReviewThread {} -> ResolveReviewThreadTag
  SomeEffect ReplyReviewThread {} -> ReplyReviewThreadTag
  SomeEffect PublishReviewFindings {} -> PublishReviewFindingsTag
  SomeEffect RecordIssuePlan {} -> RecordIssuePlanTag
  SomeEffect RecordPlanningGraph {} -> RecordPlanningGraphTag
  SomeEffect RecordBlocked {} -> RecordBlockedTag
  SomeEffect MergePullRequest {} -> MergePullRequestTag
  SomeEffect StopDaemon -> StopDaemonTag
  SomeEffect SleepUntilNextPoll -> SleepUntilNextPollTag

hasEffect :: EffectTag -> [SomeEffect] -> Bool
hasEffect tag =
  any ((== tag) . effectTag)

lacksEffect :: EffectTag -> [SomeEffect] -> Bool
lacksEffect tag =
  not . hasEffect tag

startWorkerEvidenceFromEffects :: [SomeEffect] -> Maybe ReviewEvidence
startWorkerEvidenceFromEffects = \case
  SomeEffect (StartWorkerTurn evidence _) : _ -> Just evidence
  _ : rest -> startWorkerEvidenceFromEffects rest
  [] -> Nothing

expectRight :: Either e a -> (a -> Bool) -> Bool
expectRight result predicate =
  case result of
    Right value -> predicate value
    Left _ -> False

expectLeft :: Either e a -> Bool
expectLeft result =
  case result of
    Left _ -> True
    Right _ -> False

replaySatisfies :: [WatcherEvent] -> (EventReplayResult -> Bool) -> Bool
replaySatisfies events =
  expectRight (replayEventLog events)

prop_someEffectSemanticEquality :: ThreadId -> BlockedReason -> Bool
prop_someEffectSemanticEquality threadId reason =
  let otherThread = ThreadId (unThreadId threadId <> "-other")
      evidence = reviewEvidenceFromSummaries ("review feedback" :| []) (CommitSha "abc123")
   in SomeEffect (StartWorkerTurn evidence threadId) == SomeEffect (StartWorkerTurn evidence threadId)
        && SomeEffect (StartWorkerTurn evidence threadId) /= SomeEffect (StartWorkerTurn evidence otherThread)
        && SomeEffect (RecordBlocked reason) == SomeEffect (RecordBlocked reason)
        && SomeEffect StopDaemon /= SomeEffect SleepUntilNextPoll
        && SomeEffect (StartWorkerTurn evidence threadId) /= SomeEffect (StartIssueImplementationWorkerTurn threadId)

prop_observedFromDecisionPreservesTransition :: PlannerConfig -> ThreadId -> TurnId -> Bool
prop_observedFromDecisionPreservesTransition config threadId turnId =
  let event = IssuePlanningTurnStarted threadId turnId
      decision = step (PlanningReady config) (StartPlanningTurn (ActiveTurn threadId turnId))
      observed = observedFromDecision event decision
   in observed.observedEvent == event
        && someDomain observed.observedState == IssuePlanning
        && somePhase observed.observedState == PlanMode
        && observed.observedEffects == [SomeEffect (StartPlannerTurn threadId)]

prop_invalidObservationReportsState :: Bool
prop_invalidObservationReportsState =
  case (invalidObservation "test observation" (SomeWatcherState (StoppedState (StopReason "done") :: WatcherState 'PrReview 'Stopped)) ("bad" :: Text) :: Either Text ()) of
    Left message ->
      "test observation" `Text.isInfixOf` message
        && "PrReview/Stopped" `Text.isInfixOf` message
    Right _ -> False

prop_blockingNonTerminalRecordsReasonAndStops :: IssueConfig -> PrNumber -> ThreadId -> BlockedReason -> Bool
prop_blockingNonTerminalRecordsReasonAndStops config prNumber threadId reason =
  case step (IssuePlanReady config prNumber (WorkerIdle threadId)) (MarkBlocked reason) of
    Decision state effects ->
      phaseOf state == Blocked
        && hasEffect RecordBlockedTag effects
        && SomeEffect StopDaemon `elem` effects

prop_stoppedTerminalDoesNotMutate :: StopReason -> Bool
prop_stoppedTerminalDoesNotMutate reason =
  case step (StoppedState reason :: WatcherState 'PrReview 'Stopped) (StopWatcher reason) of
    Decision state effects ->
      phaseOf state == Stopped && not (hasMutation effects)

prop_completeTerminalStopDoesNotMutate :: MergeCommit -> StopReason -> Bool
prop_completeTerminalStopDoesNotMutate mergeCommit reason =
  case step (CompleteState (PrMerged mergeCommit)) (StopWatcher reason) of
    Decision state effects ->
      phaseOf state == Stopped && not (hasMutation effects)

prop_unresolvedReviewsStartWorkerButDoNotMerge :: PrConfig -> ThreadId -> ThreadId -> ReviewEvidence -> ActiveTurn -> Bool
prop_unresolvedReviewsStartWorkerButDoNotMerge config workerThread reviewerThread evidence activeTurn =
  case step (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) (ReviewThreadsFound evidence activeTurn) of
    Decision state effects ->
      phaseOf state == FixingReviews
        && hasEffect StartWorkerTurnTag effects
        && lacksEffect MergePullRequestTag effects

prop_noUnresolvedReviewsStartsReviewerOnly :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> ActiveTurn -> Bool
prop_noUnresolvedReviewsStartsReviewerOnly config workerThread reviewerThread commit activeTurn =
  case step (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) (NoReviewThreadsFound commit activeTurn) of
    Decision state effects ->
      phaseOf state == ReviewingClean
        && hasEffect StartReviewerTurnTag effects
        && lacksEffect StartWorkerTurnTag effects
        && lacksEffect MergePullRequestTag effects

prop_cleanReviewWaitsForMergeability :: PrConfig -> CommitSha -> ThreadId -> ActiveTurn -> CleanReviewEvidence -> Bool
prop_cleanReviewWaitsForMergeability config commit workerThread reviewerActive cleanEvidence =
  case step (PrReviewingClean config commit normalReviewContext (WorkerIdle workerThread) (ReviewerActive reviewerActive)) (ReviewerFoundClean cleanEvidence []) of
    Decision state effects ->
      phaseOf state == WaitingMergeability
        && hasEffect SleepUntilNextPollTag effects
        && lacksEffect MergePullRequestTag effects

prop_issuePlanCompletionWaitsBeforeImplementation :: IssueConfig -> PrNumber -> ActiveTurn -> ActiveTurn -> Bool
prop_issuePlanCompletionWaitsBeforeImplementation config prNumber planningTurn implementationTurn =
  case step (IssueInPlanMode config prNumber (WorkerActive planningTurn)) (IssuePlanCompleted sampleIssuePlanMarkdown (Just implementationTurn)) of
    Decision state effects ->
      phaseOf state == Implementing
        && hasEffect RecordIssuePlanTag effects
        && hasEffect SleepUntilNextPollTag effects
        && lacksEffect PushBranchTag effects
        && lacksEffect CreatePullRequestTag effects
        && lacksEffect StartIssueImplementationWorkerTurnTag effects

prop_issuePlanReadyStartsPlanTurn :: IssueConfig -> PrNumber -> ThreadId -> ActiveTurn -> Bool
prop_issuePlanReadyStartsPlanTurn config prNumber workerThread planTurn =
  case step (IssueReadyToPlan config prNumber (WorkerIdle workerThread)) (StartReadyIssuePlanTurn planTurn) of
    Decision state effects ->
      phaseOf state == PlanMode
        && hasEffect StartIssuePlanWorkerTurnTag effects
        && lacksEffect CreatePullRequestTag effects

prop_issuePlanCompletionWithoutImmediateTurnWaitsOnly :: IssueConfig -> PrNumber -> ActiveTurn -> Bool
prop_issuePlanCompletionWithoutImmediateTurnWaitsOnly config prNumber planningTurn =
  case step (IssueInPlanMode config prNumber (WorkerActive planningTurn)) (IssuePlanCompleted sampleIssuePlanMarkdown Nothing) of
    Decision state effects ->
      phaseOf state == Implementing
        && hasEffect RecordIssuePlanTag effects
        && hasEffect SleepUntilNextPollTag effects
        && lacksEffect PushBranchTag effects
        && lacksEffect CreatePullRequestTag effects
        && lacksEffect StartWorkerTurnTag effects

prop_issueImplementationIncompleteRestartsWorker :: IssueConfig -> PrNumber -> ActiveTurn -> Bool
prop_issueImplementationIncompleteRestartsWorker config prNumber activeTurn =
  case step (IssueImplementing config (Just prNumber) (WorkerActive activeTurn)) IssueImplementationIncomplete of
    Decision state effects ->
      phaseOf state == Implementing
        && hasEffect StartIssueImplementationWorkerTurnTag effects
        && lacksEffect RecordBlockedTag effects

prop_issueImplementationBlockedStops :: IssueConfig -> PrNumber -> ActiveTurn -> BlockedReason -> Bool
prop_issueImplementationBlockedStops config prNumber activeTurn reason =
  case step (IssueImplementing config (Just prNumber) (WorkerActive activeTurn)) (MarkBlocked reason) of
    Decision state effects ->
      phaseOf state == Blocked
        && hasEffect RecordBlockedTag effects
        && SomeEffect StopDaemon `elem` effects

prop_plannerCompletionReturnsToReady :: PlannerConfig -> ActiveTurn -> Bool
prop_plannerCompletionReturnsToReady config activeTurn =
  case step (PlanningTurnActive config activeTurn) PlannerTurnCompleted of
    Decision state effects ->
      phaseOf state == Complete
        && SomeEffect StopDaemon `elem` effects

prop_plannerGraphUpdateWaitsAndRecords :: PlannerConfig -> ActiveTurn -> PlanningGraph -> Bool
prop_plannerGraphUpdateWaitsAndRecords config activeTurn graph =
  case step (PlanningTurnActive config activeTurn) (PlannerUpdatedGraph graph) of
    Decision state effects ->
      phaseOf state == Initialized
        && hasEffect RecordPlanningGraphTag effects
        && SomeEffect SleepUntilNextPoll `elem` effects
        && not (SomeEffect StopDaemon `elem` effects)

prop_plannerIssueCreationReturnsToPlanning :: PlannerConfig -> ActiveTurn -> IssueCreationRequest -> Bool
prop_plannerIssueCreationReturnsToPlanning config activeTurn request =
  case step (PlanningTurnActive config activeTurn) (PlannerRequestedIssueCreation (request :| [])) of
    Decision state effects ->
      phaseOf state == Initialized
        && effects == [SomeEffect (CreateIssue (plannerRepo config) request), SomeEffect SleepUntilNextPoll]

prop_stateSingletonReflection :: PlannerConfig -> ActiveTurn -> Bool
prop_stateSingletonReflection config activeTurn =
  let activeState = PlanningTurnActive config activeTurn
      completeState = CompleteState PlanningComplete :: WatcherState 'IssuePlanning 'Complete
   in domainOf activeState == IssuePlanning
        && phaseOf activeState == PlanMode
        && not (isTerminalState (SomeWatcherState activeState))
        && isTerminalState (SomeWatcherState completeState)

prop_eventLogFullPrReviewPathCompletes :: PrConfig -> ThreadId -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> TurnId -> TurnId -> CleanReviewEvidence -> MergeCommit -> Bool
prop_eventLogFullPrReviewPathCompletes config workerThread reviewerThread reviewThreadIds reviewedCommit workerTurn verificationTurn finalReviewTurn cleanEvidence mergeCommit =
  let verifiedCleanEvidence = CleanReviewEvidence reviewedCommit (cleanReviewComment cleanEvidence)
   in replaySatisfies
        [ PrReviewInitialized config workerThread reviewerThread
        , PrReviewUnresolvedFound reviewThreadIds reviewedCommit workerTurn
        , PrReviewFixCompleted
        , PrReviewFixVerificationStarted (reviewEvidenceFromThreads reviewThreadIds reviewedCommit) reviewedCommit verificationTurn
        , PrReviewCleanFound verifiedCleanEvidence (Foldable.toList reviewThreadIds)
        , PrReviewNoUnresolvedFound reviewedCommit finalReviewTurn
        , PrReviewCleanFound verifiedCleanEvidence []
        , PrReviewMergeabilityClean reviewedCommit
        , PrReviewMergeCompleted mergeCommit
        ]
        \replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == Complete

prop_eventLogMergeabilityFixRequiredQueuesWorker :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> CleanReviewEvidence -> Bool
prop_eventLogMergeabilityFixRequiredQueuesWorker config workerThread reviewerThread reviewedCommit reviewerTurn cleanEvidence =
  let verifiedCleanEvidence = CleanReviewEvidence reviewedCommit (cleanReviewComment cleanEvidence)
      evidence = reviewEvidenceFromSummaries ("pre-merge merge state is DIRTY: the PR branch is not mergeable with the latest base branch" :| []) reviewedCommit
   in replaySatisfies
        [ PrReviewInitialized config workerThread reviewerThread
        , PrReviewNoUnresolvedFound reviewedCommit reviewerTurn
        , PrReviewCleanFound verifiedCleanEvidence []
        , PrReviewMergeabilityFixRequired evidence
        ]
        \replay ->
          case replay.replayState of
            SomeWatcherState (PrReviewFixQueued _ queuedEvidence (WorkerIdle queuedWorker) (ReviewerIdle queuedReviewer)) ->
              queuedEvidence == evidence
                && queuedWorker == workerThread
                && queuedReviewer == reviewerThread
            _ -> False

prop_eventLogCannotReviewCleanWhileFixing :: PrConfig -> ThreadId -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> TurnId -> Bool
prop_eventLogCannotReviewCleanWhileFixing config workerThread reviewerThread reviewThreadIds reviewedCommit workerTurn reviewerTurn =
  expectLeft
    ( replayEventLog
        [ PrReviewInitialized config workerThread reviewerThread
        , PrReviewUnresolvedFound reviewThreadIds reviewedCommit workerTurn
        , PrReviewNoUnresolvedFound reviewedCommit reviewerTurn
        ]
    )

prop_eventLogCannotMergeBeforeCleanReview :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> MergeCommit -> Bool
prop_eventLogCannotMergeBeforeCleanReview config workerThread reviewerThread commit reviewerTurn mergeCommit =
  expectLeft
    ( replayEventLog
        [ PrReviewInitialized config workerThread reviewerThread
        , PrReviewNoUnresolvedFound commit reviewerTurn
        , PrReviewMergeCompleted mergeCommit
        ]
    )

prop_eventLogFullIssueImplementationPathCompletes :: IssueConfig -> ThreadId -> TurnId -> TurnId -> PrNumber -> Bool
prop_eventLogFullIssueImplementationPathCompletes config workerThread planTurn implementationTurn prNumber =
  let reviewerThread = ThreadId "issue-post-merge-reviewer"
      reviewedCommit = CommitSha "0123456789abcdef"
      reviewerTurn = TurnId "post-merge-review"
   in replaySatisfies
        [ IssueImplementInitialized config workerThread
        , IssuePullRequestCreatedEvent prNumber
        , IssuePlanTurnStartedEvent planTurn
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown (Just implementationTurn)
        , IssuePullRequestBodyUpdatedEvent prNumber
        , IssueImplementationTurnStartedEvent implementationTurn
        , IssueImplementationCompletedEvent prNumber Nothing
        , IssueReviewHandoffInitializedEvent prNumber
        , IssueReviewHandoffStartedEvent prNumber
        , IssuePullRequestMergedEvent prNumber
        , IssueReviewerThreadReadyEvent reviewerThread
        , IssuePostMergeReviewStartedEvent reviewedCommit reviewerTurn
        , IssuePostMergeReviewCleanEvent (CleanReviewEvidence reviewedCommit "LGTM")
        , IssueClosedEvent prNumber
        ]
        \replay ->
          someDomain replay.replayState == IssueImplement
            && somePhase replay.replayState == Complete

prop_eventLogPostMergeReviewStartUsesExistingReviewer :: IssueConfig -> ThreadId -> TurnId -> TurnId -> PrNumber -> Bool
prop_eventLogPostMergeReviewStartUsesExistingReviewer config workerThread planTurn implementationTurn prNumber =
  let reviewerThread = ThreadId "handoff-reviewer"
      reviewedCommit = CommitSha "0123456789abcdef"
      reviewerTurn = TurnId "post-merge-review"
   in replaySatisfies
        [ IssueImplementInitialized config workerThread
        , IssuePullRequestCreatedEvent prNumber
        , IssuePlanTurnStartedEvent planTurn
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown (Just implementationTurn)
        , IssuePullRequestBodyUpdatedEvent prNumber
        , IssueImplementationTurnStartedEvent implementationTurn
        , IssueImplementationCompletedEvent prNumber Nothing
        , IssueReviewHandoffInitializedEvent prNumber
        , IssueReviewerThreadReadyEvent reviewerThread
        , IssueReviewHandoffStartedEvent prNumber
        , IssuePullRequestMergedEvent prNumber
        , IssuePostMergeReviewStartedEvent reviewedCommit reviewerTurn
        , IssuePostMergeReviewCleanEvent (CleanReviewEvidence reviewedCommit "LGTM")
        , IssueClosedEvent prNumber
        ]
        \replay ->
          someDomain replay.replayState == IssueImplement
            && somePhase replay.replayState == Complete

prop_eventLogIgnoresMergedPrBeforeHandoff :: IssueConfig -> ThreadId -> PrNumber -> Bool
prop_eventLogIgnoresMergedPrBeforeHandoff config workerThread prNumber =
  replaySatisfies
    [ IssueImplementInitialized config workerThread
    , IssuePullRequestMergedEvent prNumber
    ]
    \replay ->
      someDomain replay.replayState == IssueImplement
        && somePhase replay.replayState == Implementing
        && replay.replayEffects == [[], [SomeEffect SleepUntilNextPoll]]

prop_eventLogRefreshesIdleIssueWorkerThread :: IssueConfig -> ThreadId -> ThreadId -> TurnId -> Bool
prop_eventLogRefreshesIdleIssueWorkerThread config oldThread newThread turnId =
  replaySatisfies
    [ IssueImplementInitialized config oldThread
    , IssueWorkerThreadRefreshed newThread
    , IssuePullRequestCreatedEvent (PrNumber 7)
    , IssuePlanTurnStartedEvent turnId
    ]
    \replay ->
      case replay.replayState of
        SomeWatcherState (IssueInPlanMode _ _ (WorkerActive activeTurn)) ->
          activeTurn.activeThreadId == newThread
        _ ->
          False

prop_eventLogRefreshesIdlePrReviewThreads :: PrConfig -> ThreadId -> ThreadId -> ThreadId -> ThreadId -> CommitSha -> TurnId -> Bool
prop_eventLogRefreshesIdlePrReviewThreads config oldWorker oldReviewer newWorker newReviewer commit turnId =
  replaySatisfies
    [ PrReviewInitialized config oldWorker oldReviewer
    , PrReviewThreadsRefreshed newWorker newReviewer
    , PrReviewNoUnresolvedFound commit turnId
    ]
    \replay ->
      case replay.replayState of
        SomeWatcherState (PrReviewingClean _ _ _ _ (ReviewerActive activeTurn)) ->
          activeTurn.activeThreadId == newReviewer
        _ ->
          False

prop_eventLogRefreshesPrReviewVerificationThreads :: PrConfig -> ThreadId -> ThreadId -> ThreadId -> ThreadId -> ReviewThreadId -> CommitSha -> CommitSha -> TurnId -> TurnId -> Bool
prop_eventLogRefreshesPrReviewVerificationThreads config oldWorker oldReviewer newWorker newReviewer reviewThreadId reviewedCommit reviewTarget workerTurn reviewerTurn =
  let evidence = reviewEvidenceFromThreads (reviewThreadId :| []) reviewedCommit
   in replaySatisfies
        [ PrReviewInitialized config oldWorker oldReviewer
        , PrReviewUnresolvedFound (reviewThreadId :| []) reviewedCommit workerTurn
        , PrReviewFixCompleted
        , PrReviewThreadsRefreshed newWorker newReviewer
        , PrReviewFixVerificationStarted evidence reviewTarget reviewerTurn
        ]
        \replay ->
          case replay.replayState of
            SomeWatcherState (PrReviewingClean _ _ (SomeReviewContext (VerificationReviewContext _)) (WorkerIdle workerThread) (ReviewerActive activeTurn)) ->
              workerThread == newWorker && activeTurn.activeThreadId == newReviewer
            _ ->
              False

prop_eventLogRefreshesPrReviewReviewerWhileWorkerActive :: PrConfig -> ThreadId -> ThreadId -> ThreadId -> ReviewThreadId -> CommitSha -> CommitSha -> TurnId -> TurnId -> Bool
prop_eventLogRefreshesPrReviewReviewerWhileWorkerActive config workerThread oldReviewer newReviewer reviewThreadId reviewedCommit reviewTarget workerTurn reviewerTurn =
  let evidence = reviewEvidenceFromThreads (reviewThreadId :| []) reviewedCommit
   in replaySatisfies
        [ PrReviewInitialized config workerThread oldReviewer
        , PrReviewUnresolvedFound (reviewThreadId :| []) reviewedCommit workerTurn
        , PrReviewThreadsRefreshed workerThread newReviewer
        , PrReviewFixCompleted
        , PrReviewFixVerificationStarted evidence reviewTarget reviewerTurn
        ]
        \replay ->
          case replay.replayState of
            SomeWatcherState (PrReviewingClean _ _ (SomeReviewContext (VerificationReviewContext _)) (WorkerIdle idleWorker) (ReviewerActive activeTurn)) ->
              idleWorker == workerThread && activeTurn.activeThreadId == newReviewer
            _ ->
              False

prop_eventLogCreatePrBeforeIssuePlanStartsPlanReady :: IssueConfig -> ThreadId -> PrNumber -> Bool
prop_eventLogCreatePrBeforeIssuePlanStartsPlanReady config workerThread prNumber =
  replaySatisfies
    [ IssueImplementInitialized config workerThread
    , IssuePullRequestCreatedEvent prNumber
    ]
    \replay ->
      someDomain replay.replayState == IssueImplement
        && somePhase replay.replayState == PlanMode

prop_eventLogCannotUpdatePrBodyBeforePlan :: IssueConfig -> ThreadId -> PrNumber -> Bool
prop_eventLogCannotUpdatePrBodyBeforePlan config workerThread prNumber =
  expectLeft
    ( replayEventLog
        [ IssueImplementInitialized config workerThread
        , IssuePullRequestCreatedEvent prNumber
        , IssuePullRequestBodyUpdatedEvent prNumber
        ]
    )

prop_eventLogCannotCompleteIssueBeforeImplementationTurn :: IssueConfig -> ThreadId -> TurnId -> PrNumber -> Bool
prop_eventLogCannotCompleteIssueBeforeImplementationTurn config workerThread planTurn prNumber =
  expectLeft
    ( replayEventLog
        [ IssueImplementInitialized config workerThread
        , IssuePullRequestCreatedEvent prNumber
        , IssuePlanTurnStartedEvent planTurn
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        , IssuePullRequestMergedEvent prNumber
        ]
    )

prop_eventLogCannotHandoffBeforeImplementationCompletion :: IssueConfig -> ThreadId -> TurnId -> TurnId -> PrNumber -> Bool
prop_eventLogCannotHandoffBeforeImplementationCompletion config workerThread planTurn implementationTurn prNumber =
  expectLeft
    ( replayEventLog
        [ IssueImplementInitialized config workerThread
        , IssuePullRequestCreatedEvent prNumber
        , IssuePlanTurnStartedEvent planTurn
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        , IssuePullRequestBodyUpdatedEvent prNumber
        , IssueImplementationTurnStartedEvent implementationTurn
        , IssueReviewHandoffInitializedEvent prNumber
        ]
    )

prop_eventLogIssueInitializedStartsPrSetup :: IssueConfig -> ThreadId -> Bool
prop_eventLogIssueInitializedStartsPrSetup config workerThread =
  case replayEventLog [IssueImplementInitialized config workerThread] of
    Right replay ->
      someDomain replay.replayState == IssueImplement
        && somePhase replay.replayState == Implementing
    Left _ -> False

prop_eventLogIssueIncompleteCanContinueToComplete :: IssueConfig -> ThreadId -> TurnId -> TurnId -> PrNumber -> Bool
prop_eventLogIssueIncompleteCanContinueToComplete config workerThread planTurn firstImplementationTurn prNumber =
  let secondImplementationTurn = TurnId (unTurnId firstImplementationTurn <> "-next")
      reviewerThread = ThreadId "issue-post-merge-reviewer"
      reviewedCommit = CommitSha "0123456789abcdef"
      reviewerTurn = TurnId "post-merge-review"
   in case replayEventLog
        [ IssueImplementInitialized config workerThread
        , IssuePullRequestCreatedEvent prNumber
        , IssuePlanTurnStartedEvent planTurn
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        , IssuePullRequestBodyUpdatedEvent prNumber
        , IssueImplementationTurnStartedEvent firstImplementationTurn
        , IssueImplementationIncompleteEvent "incomplete"
        , IssueImplementationTurnStartedEvent secondImplementationTurn
        , IssueImplementationCompletedEvent prNumber Nothing
        , IssueReviewHandoffInitializedEvent prNumber
        , IssueReviewHandoffStartedEvent prNumber
        , IssuePullRequestMergedEvent prNumber
        , IssueReviewerThreadReadyEvent reviewerThread
        , IssuePostMergeReviewStartedEvent reviewedCommit reviewerTurn
        , IssuePostMergeReviewCleanEvent (CleanReviewEvidence reviewedCommit "LGTM")
        , IssueClosedEvent prNumber
        ] of
        Right replay ->
          someDomain replay.replayState == IssueImplement
            && somePhase replay.replayState == Complete
        Left _ -> False

prop_issueImplementWatcherStartsPlanMode :: IssueConfig -> PrNumber -> ThreadId -> TurnId -> Bool
prop_issueImplementWatcherStartsPlanMode config prNumber workerThread planTurn =
  let state = SomeWatcherState (IssueReadyToPlan config prNumber (WorkerIdle workerThread))
   in expectRight (issueImplementObserve state (ObservedPlanTurnStarted planTurn)) \tick ->
        issueImplementTickEvent tick == IssuePlanTurnStartedEvent planTurn
          && somePhase tick.issueImplementTickState == PlanMode
          && hasEffect StartIssuePlanWorkerTurnTag tick.issueImplementTickEffects

prop_issueImplementWatcherPlanCompletionWaitsBeforeImplementation :: IssueConfig -> PrNumber -> ThreadId -> TurnId -> TurnId -> Bool
prop_issueImplementWatcherPlanCompletionWaitsBeforeImplementation config prNumber workerThread planTurn implementationTurn =
  let state = SomeWatcherState (IssueInPlanMode config prNumber (WorkerActive (ActiveTurn workerThread planTurn)))
   in expectRight (issueImplementObserve state (ObservedPlanCompleted sampleIssuePlanMarkdown (Just implementationTurn))) \tick ->
        issueImplementTickEvent tick == IssuePlanCompletedEvent sampleIssuePlanMarkdown (Just implementationTurn)
          && somePhase tick.issueImplementTickState == Implementing
          && hasEffect RecordIssuePlanTag tick.issueImplementTickEffects
          && hasEffect SleepUntilNextPollTag tick.issueImplementTickEffects
          && lacksEffect PushBranchTag tick.issueImplementTickEffects
          && lacksEffect CreatePullRequestTag tick.issueImplementTickEffects
          && lacksEffect StartIssueImplementationWorkerTurnTag tick.issueImplementTickEffects

prop_issueImplementWatcherIncompleteRestartsImplementation :: IssueConfig -> PrNumber -> ThreadId -> TurnId -> Bool
prop_issueImplementWatcherIncompleteRestartsImplementation config prNumber workerThread implementationTurn =
  let state = SomeWatcherState (IssueImplementing config (Just prNumber) (WorkerActive (ActiveTurn workerThread implementationTurn)))
   in expectRight (issueImplementObserve state (ObservedImplementationIncomplete "incomplete")) \tick ->
        issueImplementTickEvent tick == IssueImplementationIncompleteEvent "incomplete"
          && somePhase tick.issueImplementTickState == Implementing
          && hasEffect StartIssueImplementationWorkerTurnTag tick.issueImplementTickEffects

prop_issueImplementWatcherRejectsCompletionBeforeImplementationTurn :: IssueConfig -> PrNumber -> ThreadId -> Bool
prop_issueImplementWatcherRejectsCompletionBeforeImplementationTurn config prNumber workerThread =
  let state = SomeWatcherState (IssueImplementationReady config (Just prNumber) (WorkerIdle workerThread))
   in expectLeft (issueImplementObserve state (ObservedImplementationCompleted prNumber Nothing))

prop_issueImplementWatcherRejectsStaleCompletionPrAfterHandoff :: Bool
prop_issueImplementWatcherRejectsStaleCompletionPrAfterHandoff =
  all rejectsStaleCompletion
    [ SomeWatcherState (IssueHandoffReady config expectedPr worker Nothing)
    , SomeWatcherState (IssueHandoffInitialized config expectedPr worker Nothing)
    , SomeWatcherState (IssueWaitingForPrMerge config expectedPr worker Nothing)
    ]
 where
  config = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
  expectedPr = PrNumber 7
  stalePr = PrNumber 8
  worker = WorkerIdle (ThreadId "worker-thread")
  rejectsStaleCompletion state =
    expectRight (issueImplementObserve state (ObservedImplementationCompleted stalePr Nothing)) \tick ->
      issueImplementTickEvent tick == IssueImplementationCompletedEvent stalePr Nothing
        && somePhase tick.issueImplementTickState == Blocked
        && hasEffect RecordBlockedTag tick.issueImplementTickEffects
        && SomeEffect StopDaemon `elem` tick.issueImplementTickEffects

prop_issueImplementWatcherMergedStartsPostMergeReview :: IssueConfig -> PrNumber -> ThreadId -> ThreadId -> Bool
prop_issueImplementWatcherMergedStartsPostMergeReview config prNumber workerThread reviewerThread =
  let state = SomeWatcherState (IssueWaitingForPrMerge config prNumber (WorkerIdle workerThread) (Just (ReviewerIdle reviewerThread)))
   in expectRight (issueImplementObserve state (ObservedPullRequestMerged prNumber)) \tick ->
        issueImplementTickEvent tick == IssuePullRequestMergedEvent prNumber
          && somePhase tick.issueImplementTickState == Implementing
          && lacksEffect CloseIssueTag tick.issueImplementTickEffects
          && lacksEffect StopDaemonTag tick.issueImplementTickEffects
          && case tick.issueImplementTickState of
            SomeWatcherState (IssuePostMergeReviewReady _ _ _ (ReviewerIdle readyReviewerThread)) ->
              readyReviewerThread == reviewerThread
            _ -> False

prop_issueImplementPostMergeFollowUpUsesNextAttemptBranch :: IssueConfig -> PrNumber -> ThreadId -> ThreadId -> TurnId -> CommitSha -> Bool
prop_issueImplementPostMergeFollowUpUsesNextAttemptBranch config prNumber workerThread reviewerThread reviewerTurn reviewedCommit =
  let evidence = reviewEvidenceFromSummaries ("needs follow-up" :| []) reviewedCommit
      state =
        SomeWatcherState
          ( IssuePostMergeReviewing
              config
              prNumber
              (WorkerIdle workerThread)
              reviewedCommit
              (ReviewerActive (ActiveTurn reviewerThread reviewerTurn))
          )
      expectedBranch =
        unBranchName config.issueBranch <> "-2"
   in expectRight (issueImplementObserve state (ObservedPostMergeReviewerOutcome (IssueFinalReviewRework evidence))) \tick ->
        issueImplementTickEvent tick == IssuePostMergeReviewFollowUpEvent evidence
          && hasEffect UpdateIssueFollowUpTag tick.issueImplementTickEffects
          && lacksEffect CloseIssueTag tick.issueImplementTickEffects
          && case tick.issueImplementTickState of
            SomeWatcherState (IssueImplementationReady followUpConfig Nothing (WorkerIdle returnedWorker)) ->
              returnedWorker == workerThread
                && followUpConfig.issueRepo == config.issueRepo
                && followUpConfig.issueNumber == config.issueNumber
                && followUpConfig.issueBranch /= config.issueBranch
                && unBranchName followUpConfig.issueBranch == expectedBranch
            _ -> False

prop_issueImplementPostMergeFollowUpIncrementsAttemptBranch :: Bool
prop_issueImplementPostMergeFollowUpIncrementsAttemptBranch =
  let repo = RepoName "soulomoon/mlf2"
      config = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42-3")
      prNumber = PrNumber 7
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      reviewerTurn = TurnId "review"
      reviewedCommit = CommitSha "0123456789ab"
      evidence = reviewEvidenceFromSummaries ("needs rework" :| []) reviewedCommit
      state =
        SomeWatcherState
          ( IssuePostMergeReviewing
              config
              prNumber
              (WorkerIdle workerThread)
              reviewedCommit
              (ReviewerActive (ActiveTurn reviewerThread reviewerTurn))
          )
   in expectRight (issueImplementObserve state (ObservedPostMergeReviewerOutcome (IssueFinalReviewRework evidence))) \tick ->
        case tick.issueImplementTickState of
          SomeWatcherState (IssueImplementationReady followUpConfig Nothing (WorkerIdle returnedWorker)) ->
            returnedWorker == workerThread
              && unBranchName followUpConfig.issueBranch == "codex/issue-42-4"
          _ -> False

prop_issueImplementWatcherIssueClosedCompletes :: IssueConfig -> PrNumber -> Bool
prop_issueImplementWatcherIssueClosedCompletes config prNumber =
  let state = SomeWatcherState (IssueWaitingForIssueClose config prNumber)
   in expectRight (issueImplementObserve state (ObservedIssueClosed prNumber)) \tick ->
        issueImplementTickEvent tick == IssueClosedEvent prNumber
          && somePhase tick.issueImplementTickState == Complete
          && SomeEffect StopDaemon `elem` tick.issueImplementTickEffects

prop_issueImplementWatcherBlockedStops :: IssueConfig -> PrNumber -> ThreadId -> TurnId -> BlockedReason -> Bool
prop_issueImplementWatcherBlockedStops config prNumber workerThread implementationTurn reason =
  let state = SomeWatcherState (IssueImplementing config (Just prNumber) (WorkerActive (ActiveTurn workerThread implementationTurn)))
   in expectRight (issueImplementObserve state (ObservedImplementationBlocked reason)) \tick ->
        issueImplementTickEvent tick == IssueImplementationBlockedEvent reason
          && somePhase tick.issueImplementTickState == Blocked
          && hasEffect RecordBlockedTag tick.issueImplementTickEffects
          && SomeEffect StopDaemon `elem` tick.issueImplementTickEffects

prop_issueImplementationCompatibilityWritesPrUrl :: Bool
prop_issueImplementationCompatibilityWritesPrUrl =
  let config = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 26) (BranchName "codex/replacement-issue-26")
      prNumber = PrNumber 31
      threadId = ThreadId "issue-worker-26"
      activeTurn = ActiveTurn threadId (TurnId "implement-turn")
      states =
        [ SomeWatcherState (IssueImplementationReady config (Just prNumber) (WorkerIdle threadId))
        , SomeWatcherState (IssueImplementing config (Just prNumber) (WorkerActive activeTurn))
        , SomeWatcherState (IssueWaitingForPrMerge config prNumber (WorkerIdle threadId) Nothing)
        , SomeWatcherState (IssueWaitingForIssueClose config prNumber)
        ]
   in all issueStateHasPrUrl states
 where
  issueStateHasPrUrl state =
    case [value | CompatibilityWrite path value <- compatibilityStateWrites "/tmp/state" state, path == "/tmp/state/issue-state.json"] of
      [value] ->
        lookupValue "pr_number" value == Just (toJSON (31 :: Int))
          && lookupValue "pr_url" value == Just (String "https://github.com/soulomoon/mlf2/pull/31")
      _ -> False

prop_prReviewCompatibilityClearsCheckerState :: Bool
prop_prReviewCompatibilityClearsCheckerState =
  let config = PrConfig (RepoName "soulomoon/mlf2") (PrNumber 32) (BranchName "codex/replacement-issue-27")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      commit = CommitSha "abc123"
      states =
        [ SomeWatcherState (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
        , SomeWatcherState (PrReviewingClean config commit normalReviewContext (WorkerIdle workerThread) (ReviewerActive (ActiveTurn reviewerThread (TurnId "reviewer-turn"))))
        , SomeWatcherState (PrWaitingForMergeability config (CleanReviewEvidence commit "LGTM") (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
        , SomeWatcherState (PrMerging config (CleanReviewEvidence commit "LGTM"))
        ]
   in all checkerStateIsClear states
 where
  checkerStateIsClear state =
    case [value | CompatibilityWrite path value <- compatibilityStateWrites "/tmp/state" state, path == "/tmp/state/checker-state.json"] of
      [value] ->
        lookupValue "has_unresolved" value == Just (Bool False)
          && lookupValue "unresolved_count" value == Just (toJSON (0 :: Int))
          && lookupValue "unresolved_thread_ids" value == Just (toJSON ([] :: [Text]))
      _ -> False

prop_eventLogFullIssuePlanningPathReturnsReady :: PlannerConfig -> ThreadId -> TurnId -> Bool
prop_eventLogFullIssuePlanningPathReturnsReady config plannerThread plannerTurn =
  case replayEventLog
    [ IssuePlanningInitialized config
    , IssuePlanningTurnStarted plannerThread plannerTurn
    , IssuePlanningTurnCompleted
    ] of
    Right replay ->
      someDomain replay.replayState == IssuePlanning
        && somePhase replay.replayState == Complete
    Left _ -> False

prop_eventLogIssuePlanningIssueCreationReturnsReady :: PlannerConfig -> ThreadId -> TurnId -> IssueCreationRequest -> Bool
prop_eventLogIssuePlanningIssueCreationReturnsReady config plannerThread plannerTurn request =
  case replayEventLog
    [ IssuePlanningInitialized config
    , IssuePlanningTurnStarted plannerThread plannerTurn
    , IssuePlanningIssuesRequested (request :| [])
    ] of
    Right replay ->
      someDomain replay.replayState == IssuePlanning
        && somePhase replay.replayState == Initialized
        && case replay.replayEffects of
          _initialEffects : _startEffects : creationEffects : _ ->
            creationEffects == [SomeEffect (CreateIssue (plannerRepo config) request), SomeEffect SleepUntilNextPoll]
          _ -> False
    Left _ -> False

prop_eventLogIssuePlanningGraphWaitsForReadyIssues :: PlannerConfig -> ThreadId -> TurnId -> Bool
prop_eventLogIssuePlanningGraphWaitsForReadyIssues config plannerThread plannerTurn =
  let graph = validPlanningGraphForConfig config
   in
  case replayEventLog
    [ IssuePlanningInitialized config
    , IssuePlanningTurnStarted plannerThread plannerTurn
    , IssuePlanningGraphUpdated graph
    ] of
    Right replay ->
      someDomain replay.replayState == IssuePlanning
        && somePhase replay.replayState == Initialized
        && case replay.replayEffects of
          _initialEffects : _startEffects : graphEffects : _ ->
            hasEffect RecordPlanningGraphTag graphEffects
              && SomeEffect SleepUntilNextPoll `elem` graphEffects
              && not (SomeEffect StopDaemon `elem` graphEffects)
          _ -> False
    Left _ -> False

prop_eventLogAllowsScopedPlanningDependencyClosure :: ThreadId -> TurnId -> Bool
prop_eventLogAllowsScopedPlanningDependencyClosure plannerThread plannerTurn =
  let config = PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) [IssueNumber 8]
      graph =
        PlanningGraph
          [IssueNumber 15]
          [BlockedPlanningIssue (IssueNumber 8) [IssueNumber 15, IssueNumber 16] "split work"]
          [ IssueDependency (IssueNumber 8) [IssueNumber 15, IssueNumber 16]
          , IssueDependency (IssueNumber 16) [IssueNumber 15]
          ]
   in
  case replayEventLog
    [ IssuePlanningInitialized config
    , IssuePlanningTurnStarted plannerThread plannerTurn
    , IssuePlanningGraphUpdated graph
    ] of
    Right replay ->
      someDomain replay.replayState == IssuePlanning
        && somePhase replay.replayState == Initialized
        && case replay.replayEffects of
          _initialEffects : _startEffects : graphEffects : _ ->
            hasEffect RecordPlanningGraphTag graphEffects
          _ -> False
    Left _ -> False

prop_eventLogIssuePlanningReadyIssuesFixedReentersPlanning :: PlannerConfig -> ThreadId -> TurnId -> Bool
prop_eventLogIssuePlanningReadyIssuesFixedReentersPlanning config plannerThread plannerTurn =
  let graph = validPlanningGraphForConfig config
   in
  case replayEventLog
    [ IssuePlanningInitialized config
    , IssuePlanningTurnStarted plannerThread plannerTurn
    , IssuePlanningGraphUpdated graph
    , IssuePlanningReadyIssuesFixed
    ] of
    Right replay ->
      someDomain replay.replayState == IssuePlanning
        && somePhase replay.replayState == Initialized
    Left _ -> False

prop_eventLogIssuePlanningRetryReentersPlanning :: PlannerConfig -> ThreadId -> TurnId -> BlockedReason -> Bool
prop_eventLogIssuePlanningRetryReentersPlanning config plannerThread plannerTurn reason =
  case replayEventLog
    [ IssuePlanningInitialized config
    , IssuePlanningTurnStarted plannerThread plannerTurn
    , IssuePlanningTurnRetryRequested reason
    ] of
    Right replay ->
      someDomain replay.replayState == IssuePlanning
        && somePhase replay.replayState == Initialized
        && case replay.replayEffects of
          _initialEffects : _startEffects : retryEffects : _ ->
            retryEffects == [SomeEffect SleepUntilNextPoll]
          _ -> False
    Left _ -> False

prop_eventLogCannotCompletePlanningBeforeStart :: PlannerConfig -> Bool
prop_eventLogCannotCompletePlanningBeforeStart config =
  case replayEventLog
    [ IssuePlanningInitialized config
    , IssuePlanningTurnCompleted
    ] of
    Left _ -> True
    Right _ -> False

prop_issuePlanningWatcherStartsAndCompletesTurn :: PlannerConfig -> ThreadId -> TurnId -> Bool
prop_issuePlanningWatcherStartsAndCompletesTurn config threadId turnId =
  let ready = SomeWatcherState (PlanningReady config)
   in case issuePlanningObserve ready (ObservedPlanningTurnStarted threadId turnId) of
        Right started ->
          case issuePlanningObserve started.issuePlanningTickState ObservedPlanningTurnCompleted of
            Right completed ->
              issuePlanningTickEvent started == IssuePlanningTurnStarted threadId turnId
                && somePhase started.issuePlanningTickState == PlanMode
                && hasEffect StartPlannerTurnTag started.issuePlanningTickEffects
                && issuePlanningTickEvent completed == IssuePlanningTurnCompleted
                && somePhase completed.issuePlanningTickState == Complete
            Left _ -> False
        Left _ -> False

prop_issuePlanningWatcherRetriesTurn :: PlannerConfig -> ThreadId -> TurnId -> BlockedReason -> Bool
prop_issuePlanningWatcherRetriesTurn config threadId turnId reason =
  let ready = SomeWatcherState (PlanningReady config)
   in case issuePlanningObserve ready (ObservedPlanningTurnStarted threadId turnId) of
        Right started ->
          case issuePlanningObserve started.issuePlanningTickState (ObservedPlanningTurnRetryRequested reason) of
            Right retried ->
              issuePlanningTickEvent retried == IssuePlanningTurnRetryRequested reason
                && somePhase retried.issuePlanningTickState == Initialized
                && issuePlanningTickEffects retried == [SomeEffect SleepUntilNextPoll]
            Left _ -> False
        Left _ -> False

prop_issuePlanningWatcherCreatesIssuesBeforeReplanning :: PlannerConfig -> ThreadId -> TurnId -> IssueCreationRequest -> Bool
prop_issuePlanningWatcherCreatesIssuesBeforeReplanning config threadId turnId request =
  let ready = SomeWatcherState (PlanningReady config)
   in case issuePlanningObserve ready (ObservedPlanningTurnStarted threadId turnId) of
        Right started ->
          case issuePlanningObserve started.issuePlanningTickState (ObservedPlanningIssuesRequested (request :| [])) of
            Right requested ->
              issuePlanningTickEvent requested == IssuePlanningIssuesRequested (request :| [])
                && somePhase requested.issuePlanningTickState == Initialized
                && hasEffect CreateIssueTag requested.issuePlanningTickEffects
                && issuePlanningTickEffects requested == [SomeEffect (CreateIssue (plannerRepo config) request), SomeEffect SleepUntilNextPoll]
            Left _ -> False
        Left _ -> False

prop_issuePlanningWatcherRecordsGraphBeforeFanoutAndWaits :: PlannerConfig -> ThreadId -> TurnId -> Bool
prop_issuePlanningWatcherRecordsGraphBeforeFanoutAndWaits config threadId turnId =
  let ready = SomeWatcherState (PlanningReady config)
      graph = validPlanningGraphForConfig config
   in case issuePlanningObserve ready (ObservedPlanningTurnStarted threadId turnId) of
        Right started ->
          case issuePlanningObserve started.issuePlanningTickState (ObservedPlanningGraphUpdated graph) of
            Right graphed ->
              issuePlanningTickEvent graphed == IssuePlanningGraphUpdated graph
                && somePhase graphed.issuePlanningTickState == Initialized
                && hasEffect RecordPlanningGraphTag graphed.issuePlanningTickEffects
                && SomeEffect SleepUntilNextPoll `elem` graphed.issuePlanningTickEffects
                && case issuePlanningObserve graphed.issuePlanningTickState ObservedPlanningReadyIssuesFixed of
                    Right fixed ->
                      issuePlanningTickEvent fixed == IssuePlanningReadyIssuesFixed
                        && somePhase fixed.issuePlanningTickState == Initialized
                    Left _ -> False
            Left _ -> False
        Left _ -> False

prop_issuePlanningWatcherBlocksOutOfScopeGraph :: ThreadId -> TurnId -> Bool
prop_issuePlanningWatcherBlocksOutOfScopeGraph threadId turnId =
  let config = PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) [IssueNumber 12]
      ready = SomeWatcherState (PlanningReady config)
      graph = PlanningGraph [IssueNumber 26] [] []
   in case issuePlanningObserve ready (ObservedPlanningTurnStarted threadId turnId) of
        Right started ->
          case issuePlanningObserve started.issuePlanningTickState (ObservedPlanningGraphUpdated graph) of
            Right graphed ->
              issuePlanningTickEvent graphed == WatcherBlocked (BlockedReason "planning graph references issue #26 outside configured scope")
                && somePhase graphed.issuePlanningTickState == Blocked
                && hasEffect RecordBlockedTag graphed.issuePlanningTickEffects
            Left _ -> False
        Left _ -> False

prop_issuePlanningWatcherAllowsScopedDependencyClosure :: ThreadId -> TurnId -> Bool
prop_issuePlanningWatcherAllowsScopedDependencyClosure threadId turnId =
  let config = PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) [IssueNumber 8]
      ready = SomeWatcherState (PlanningReady config)
      graph =
        PlanningGraph
          [IssueNumber 15]
          [BlockedPlanningIssue (IssueNumber 8) [IssueNumber 15, IssueNumber 16] "split work"]
          [ IssueDependency (IssueNumber 8) [IssueNumber 15, IssueNumber 16]
          , IssueDependency (IssueNumber 16) [IssueNumber 15]
          ]
   in case issuePlanningObserve ready (ObservedPlanningTurnStarted threadId turnId) of
        Right started ->
          case issuePlanningObserve started.issuePlanningTickState (ObservedPlanningGraphUpdated graph) of
            Right graphed ->
              issuePlanningTickEvent graphed == IssuePlanningGraphUpdated graph
                && somePhase graphed.issuePlanningTickState == Initialized
                && hasEffect RecordPlanningGraphTag graphed.issuePlanningTickEffects
            Left _ -> False
        Left _ -> False

prop_canonicalPlanningGraphUsesDependencyHintsAndOpenChildren :: Bool
prop_canonicalPlanningGraphUsesDependencyHintsAndOpenChildren =
  canonicalPlanningGraph plannerConfig facts plannerOutput == expected
 where
  plannerConfig = PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) [IssueNumber 12, IssueNumber 26, IssueNumber 27]
  facts =
    [ PlanningIssueFact (IssueNumber 12) False Nothing [IssueNumber 26, IssueNumber 27]
    , PlanningIssueFact (IssueNumber 26) False (Just (IssueNumber 12)) []
    , PlanningIssueFact (IssueNumber 27) False (Just (IssueNumber 12)) []
    ]
  plannerOutput =
    PlanningGraph
      { planningReadyIssues = []
      , planningBlockedIssues = []
      , planningDependencies = [IssueDependency (IssueNumber 27) [IssueNumber 26]]
      }
  expected =
    PlanningGraph
      { planningReadyIssues = [IssueNumber 26]
      , planningBlockedIssues =
          [ BlockedPlanningIssue
              (IssueNumber 12)
              [IssueNumber 26, IssueNumber 27]
              "waiting for open dependencies: #26, #27"
          , BlockedPlanningIssue
              (IssueNumber 27)
              [IssueNumber 26]
              "waiting for open dependencies: #26"
          ]
      , planningDependencies =
          [ IssueDependency (IssueNumber 12) [IssueNumber 26, IssueNumber 27]
          , IssueDependency (IssueNumber 26) []
          , IssueDependency (IssueNumber 27) [IssueNumber 26]
          ]
      }

prop_issuePlanningSelectionRespectsMaxParallelAndSkipsActive :: Bool
prop_issuePlanningSelectionRespectsMaxParallelAndSkipsActive =
  let config = PlannerConfig (RepoName "owner/name") (maxParallelForTest 3) []
      active = [IssueNumber 2]
      open = [IssueNumber 1, IssueNumber 2, IssueNumber 3, IssueNumber 4]
   in selectIssueImplementationStarts config active open == [IssueNumber 1, IssueNumber 3]

prop_issuePlanningFanoutBuildsLaunchPlans :: Bool
prop_issuePlanningFanoutBuildsLaunchPlans =
  let plannerConfig = PlannerConfig (RepoName "owner/name") (maxParallelForTest 3) []
      fanoutConfig =
        (defaultIssuePlanningFanoutConfig "/tmp/implementers")
          { fanoutWorkdirRoot = Just "/tmp/worktrees"
          }
      launches = planIssueImplementerLaunches fanoutConfig plannerConfig [IssueNumber 2] [IssueNumber 1, IssueNumber 2, IssueNumber 3, IssueNumber 4]
      launchIssues = fmap (issueNumberOfConfig . launchIssueConfig) launches
   in case launches of
        firstLaunch : _ ->
          let createdThreadLaunch = withLaunchThreadId (ThreadId "created-thread") firstLaunch
           in
          launchIssues == [IssueNumber 1, IssueNumber 3]
            && launchStateDir firstLaunch == "/tmp/implementers/owner_name__issue1"
            && launchEventsPath firstLaunch == "/tmp/implementers/owner_name__issue1/events.jsonl"
            && launchWorkdir firstLaunch == Just "/tmp/worktrees/owner_name__issue1"
            && issueImplementerWorkdirSetupCommands firstLaunch
              == [ RawCommand "gh" ["repo", "clone", "owner/name", "/tmp/worktrees/owner_name__issue1"] Nothing
                 , RawCommand "git" ["remote", "set-url", "origin", "https://github.com/owner/name.git"] (Just "/tmp/worktrees/owner_name__issue1")
                 , RawCommand "git" ["checkout", "-B", "codex/issue-1"] (Just "/tmp/worktrees/owner_name__issue1")
                 , RawCommand "git" ["config", "user.email", "codex-watcher@users.noreply.github.com"] (Just "/tmp/worktrees/owner_name__issue1")
                 , RawCommand "git" ["config", "user.name", "codex-watcher"] (Just "/tmp/worktrees/owner_name__issue1")
                 ]
            && launchInitialEvent firstLaunch == IssueImplementInitialized (launchIssueConfig firstLaunch) (launchThreadId firstLaunch)
            && length (launchCompatibilityWrites firstLaunch) == 2
            && lookupValue "threadId" (launchConfigJson firstLaunch) == Just (String "issue-worker-1")
            && lookupValue "branch" (launchConfigJson firstLaunch) == Just (String "codex/issue-1")
            && launchThreadId createdThreadLaunch == ThreadId "created-thread"
            && launchInitialEvent createdThreadLaunch == IssueImplementInitialized (launchIssueConfig createdThreadLaunch) (ThreadId "created-thread")
            && lookupValue "threadId" (launchConfigJson createdThreadLaunch) == Just (String "created-thread")
        [] -> False
 where
  issueNumberOfConfig (IssueConfig _ issue _) = issue

prop_issuePlanningFanoutRetriesTransientCloneFailures :: Bool
prop_issuePlanningFanoutRetriesTransientCloneFailures =
  retryableLaunchCommandFailure cloneCommand tlsCloneFailure
    && retryableLaunchCommandFailure cloneCommand dnsCloneFailure
    && not (retryableLaunchCommandFailure cloneCommand authCloneFailure)
    && not (retryableLaunchCommandFailure checkoutCommand tlsCloneFailure)
 where
  cloneCommand = RawCommand "gh" ["repo", "clone", "owner/name", "/tmp/worktrees/owner_name__issue1"] Nothing
  checkoutCommand = RawCommand "git" ["checkout", "-B", "codex/issue-1"] (Just "/tmp/worktrees/owner_name__issue1")
  tlsCloneFailure =
    CommandReport
      { ok = False
      , status = Just 128
      , stdout = ""
      , stderr = "fatal: unable to access 'https://github.com/owner/name.git/': gnutls_handshake() failed: The TLS connection was non-properly terminated."
      , errorMessage = Nothing
      }
  dnsCloneFailure =
    CommandReport
      { ok = False
      , status = Just 128
      , stdout = ""
      , stderr = "fatal: unable to access 'https://github.com/owner/name.git/': Could not resolve host: github.com"
      , errorMessage = Nothing
      }
  authCloneFailure =
    CommandReport
      { ok = False
      , status = Just 1
      , stdout = ""
      , stderr = "HTTP 403: Resource not accessible by integration"
      , errorMessage = Nothing
      }

prop_issuePlanningFanoutParsesImplementerConfig :: Bool
prop_issuePlanningFanoutParsesImplementerConfig =
  let issueConfig = IssueConfig (RepoName "owner/name") (IssueNumber 42) (BranchName "codex/issue-42")
      validConfig = issueImplementerConfigJson issueConfig (ThreadId "thread-42") "/tmp/state" Nothing
      invalidConfig = object ["repoFullName" .= ("owner/name" :: Text), "issueNumber" .= (0 :: Int)]
   in parseIssueImplementerConfigIssue validConfig == Right (RepoName "owner/name", IssueNumber 42)
        && case parseIssueImplementerConfigIssue invalidConfig of
          Left _ -> True
          Right _ -> False

prop_issuePlanningFanoutDetectsCompletionBoundary :: Bool
prop_issuePlanningFanoutDetectsCompletionBoundary =
  let config = PlannerConfig (RepoName "owner/name") (maxParallelForTest 3) []
      planningReady = SomeWatcherState (PlanningReady config)
      planningActive = SomeWatcherState (PlanningTurnActive config (ActiveTurn (ThreadId "planner-thread") (TurnId "planner-turn")))
      planningWaiting = SomeWatcherState (PlanningWaitingForReadyIssues config graph)
      issueState = SomeWatcherState (IssuePlanReady (IssueConfig (RepoName "owner/name") (IssueNumber 42) (BranchName "codex/issue-42")) (PrNumber 7) (WorkerIdle (ThreadId "worker-thread")))
      graph = PlanningGraph [IssueNumber 1] [BlockedPlanningIssue (IssueNumber 2) [IssueNumber 1] "wait"] [IssueDependency (IssueNumber 2) [IssueNumber 1]]
   in plannerConfigFromState planningReady == Just config
        && plannerConfigFromState planningActive == Just config
        && plannerConfigFromState planningWaiting == Just config
        && plannerConfigFromState issueState == Nothing
        && issuePlanningCompletionEvent (IssuePlanningGraphUpdated graph)
        && not (issuePlanningCompletionEvent (IssuePlanningTurnRetryRequested (BlockedReason "retry")) )
        && not (issuePlanningCompletionEvent IssuePlanningTurnCompleted)
        && not (issuePlanningCompletionEvent (IssuePlanningIssuesRequested (IssueCreationRequest "subissue" "details" Nothing :| [])))
        && not (issuePlanningCompletionEvent (IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn")))

issuePlanningFanoutRoutesTerminalWritesThroughIndexedProjection :: IO Bool
issuePlanningFanoutRoutesTerminalWritesThroughIndexedProjection = do
  source <- TextIO.readFile "src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs"
  sequenceAnd
    [ assert "issue planning fanout ready-issues marker uses indexed projection" $
        "projectIssuePlanningReadyIssuesFixedObservation" `Text.isInfixOf` source
    , assert "issue planning fanout blocked marker uses indexed projection" $
        "projectIssuePlanningBlockedWaitingReadyIssuesObservation" `Text.isInfixOf` source
    , assert "issue planning fanout writes compatibility from projected final state after append" $
        "appendWatcherEvent ioRuntimeInterpreter cli.loopCliEventsPath projection.issuePlanningIndexedProjectionPlanned.plannedEvent" `Text.isInfixOf` source
          && "compatibilityStateWrites cli.loopCliStateDir projection.issuePlanningIndexedProjectionFinalState" `Text.isInfixOf` source
    , assert "issue planning fanout no longer derives terminal writes through compatibility observer" $
        not ("issuePlanningObserve" `Text.isInfixOf` source)
    ]

prop_issuePlanningFanoutUsesOnlyReadyIssues :: Bool
prop_issuePlanningFanoutUsesOnlyReadyIssues =
  let plannerConfig = PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) []
      fanoutConfig = defaultIssuePlanningFanoutConfig "/tmp/implementers"
      ready = [IssueNumber 10, IssueNumber 12]
      active = [IssueNumber 12]
      launchIssues = fmap (issueNumberOfConfig . launchIssueConfig) (planIssueImplementerLaunches fanoutConfig plannerConfig active ready)
   in launchIssues == [IssueNumber 10]
 where
  issueNumberOfConfig (IssueConfig _ issue _) = issue

issuePlanningFanoutDiscoversOnlyRunningImplementers :: IO Bool
issuePlanningFanoutDiscoversOnlyRunningImplementers = do
  let root = "/tmp/moifold-active-implementers"
      repo = RepoName "owner/name"
      runningIssue = IssueNumber 19
      stoppedIssue = IssueNumber 20
      staleIssue = IssueNumber 21
      runningConfig = IssueConfig repo runningIssue (BranchName "codex/issue-19")
      stoppedConfig = IssueConfig repo stoppedIssue (BranchName "codex/issue-20")
      staleConfig = IssueConfig repo staleIssue (BranchName "codex/issue-21")
      writeConfig targetStateDir issueConfig threadId =
        LazyByteString.writeFile
          (targetStateDir </> "config.json")
          (encode (issueImplementerConfigJson issueConfig threadId targetStateDir Nothing))
      writeEvents targetStateDir events =
        LazyByteString.writeFile (targetStateDir </> "events.jsonl") (mconcat (fmap (\event -> encode event <> "\n") events))
      stateDir issue =
        issueImplementerStateDir root repo issue
  exists <- doesDirectoryExist root
  when exists (removePathForcibly root)
  createDirectoryIfMissing True (stateDir runningIssue)
  createDirectoryIfMissing True (stateDir stoppedIssue)
  createDirectoryIfMissing True (stateDir staleIssue)
  writeConfig (stateDir runningIssue) runningConfig (ThreadId "thread-19")
  writeConfig (stateDir stoppedIssue) stoppedConfig (ThreadId "thread-20")
  writeConfig (stateDir staleIssue) staleConfig (ThreadId "thread-21")
  pid <- getProcessID
  writeFile (stateDir runningIssue </> "issue-watcher.pid") (show pid <> "\n")
  writeEvents
    (stateDir stoppedIssue)
    [ IssueImplementInitialized stoppedConfig (ThreadId "thread-20")
    , WatcherStopped (StopReason "done")
    ]
  active <- resolveFanoutActiveIssues Nothing repo root
  explicit <- resolveFanoutActiveIssues (Just [staleIssue]) repo root
  removePathForcibly root
  results <-
    sequence
      [ assert "active discovery includes only running issue implementers" (active == [runningIssue])
      , assert "explicit active issues still override runtime discovery" (explicit == [staleIssue])
      ]
  pure (and results)

prop_issuePlanningReadyFanoutDoesNotRecreateExistingImplementers :: Bool
prop_issuePlanningReadyFanoutDoesNotRecreateExistingImplementers =
  let plannerConfig = PlannerConfig (RepoName "owner/name") (maxParallelForTest 2) []
      fanoutConfig = defaultIssuePlanningFanoutConfig "/tmp/implementers"
      terminalOnly =
        planReadyIssueFanout
          fanoutConfig
          plannerConfig
          []
          [(IssueNumber 26, ReadyIssueTerminal)]
      mixed =
        planReadyIssueFanout
          fanoutConfig
          plannerConfig
          []
          [(IssueNumber 26, ReadyIssueTerminal), (IssueNumber 27, ReadyIssueMissing)]
      stopped =
        planReadyIssueFanout
          fanoutConfig
          plannerConfig
          []
          [(IssueNumber 28, ReadyIssueActiveStopped)]
   in null terminalOnly.readyIssueLaunches
        && null terminalOnly.readyIssueRestarts
        && terminalOnly.readyIssuesAllTerminal
        && fmap (issueNumberOfConfig . launchIssueConfig) mixed.readyIssueLaunches == [IssueNumber 27]
        && not mixed.readyIssuesAllTerminal
        && null stopped.readyIssueLaunches
        && fmap (issueNumberOfConfig . launchIssueConfig) stopped.readyIssueRestarts == [IssueNumber 28]
        && not stopped.readyIssuesAllTerminal
 where
  issueNumberOfConfig (IssueConfig _ issue _) = issue

prop_issuePlanningFanoutTreatsClosedReadyIssuesAsTerminal :: Bool
prop_issuePlanningFanoutTreatsClosedReadyIssuesAsTerminal =
  let plannerConfig = PlannerConfig (RepoName "owner/name") (maxParallelForTest 3) []
      fanoutConfig = defaultIssuePlanningFanoutConfig "/tmp/implementers"
      rawStatuses =
        [ (IssueNumber 64, WatcherActiveStopped)
        , (IssueNumber 65, WatcherMissing)
        , (IssueNumber 69, WatcherMissing)
        ]
      reconciledStatuses =
        completeClosedReadyIssueStatuses [IssueNumber 64, IssueNumber 65] rawStatuses
      fanoutPlan =
        planReadyIssueFanout
          fanoutConfig
          plannerConfig
          []
          (fmap (fmap readyIssueStatusFromRuntime) reconciledStatuses)
   in reconciledStatuses
        == [ (IssueNumber 64, WatcherTerminal TerminalComplete)
           , (IssueNumber 65, WatcherTerminal TerminalComplete)
           , (IssueNumber 69, WatcherMissing)
           ]
        && fmap (issueNumberOfConfig . launchIssueConfig) fanoutPlan.readyIssueLaunches == [IssueNumber 69]
        && null fanoutPlan.readyIssueRestarts
        && not fanoutPlan.readyIssuesAllTerminal
        && readyIssueStatusesNeedReplanning reconciledStatuses
        && not (readyIssueStatusesNeedReplanning [(IssueNumber 69, WatcherMissing), (IssueNumber 70, WatcherActiveRunning)])
 where
  issueNumberOfConfig (IssueConfig _ issue _) = issue

prop_issuePlanningFanoutDefaultsToStartingChildWatchers :: IO Bool
prop_issuePlanningFanoutDefaultsToStartingChildWatchers = do
  let endpoint = AppServerEndpoint "127.0.0.1" 4500 "/"
      pollSeconds = pollSecondsForTest 17
  dryRunLaunch <- issueImplementerChildLaunchMode (Just pollSeconds) DryRunActions (Just endpoint)
  executeLaunch <- issueImplementerChildLaunchMode (Just pollSeconds) ExecuteActions (Just endpoint)
  sequenceAnd
    [ assert "dry-run fanout prints child watcher launch commands by default" $
        dryRunLaunch == PrintChildLaunchCommands endpoint pollSeconds
    , assert "execute fanout starts child watcher daemons by default" $
        executeLaunch == StartChildLaunches endpoint pollSeconds
    ]

issueImplementerLaunchLifecycleManifestsAndDryRunCommand :: IO Bool
issueImplementerLaunchLifecycleManifestsAndDryRunCommand = do
  let endpoint = AppServerEndpoint "127.0.0.1" 4500 "/api/codex"
      pollSeconds = pollSecondsForTest 17
      plannerConfig = PlannerConfig (RepoName "owner/name") (maxParallelForTest 3) []
      fanoutConfig =
        (defaultIssuePlanningFanoutConfig "/tmp/implementers")
          { fanoutWorkdirRoot = Just "/tmp/worktrees"
          }
      launch =
        withLaunchThreadId (ThreadId "thread-created") $
          issueImplementerLaunchPlan fanoutConfig plannerConfig (IssueNumber 42)
      pending = issueImplementerLaunchManifest "pending" (PrintChildLaunchCommands endpoint pollSeconds) launch
      finalized = issueImplementerLaunchManifest "finalized" (StartChildLaunches endpoint pollSeconds) launch
      args = issueImplementerChildArgs endpoint pollSeconds launch
  sequenceAnd
    [ assert "pending launch manifest preserves status and launch kind" $
        lookupValue "status" pending == Just (String "pending")
          && lookupValue "launchKind" pending == Just (String "issue-implementer")
    , assert "launch plan writes initialized event and compatibility facade files" $
        launchInitialEvent launch == IssueImplementInitialized (launchIssueConfig launch) (ThreadId "thread-created")
          && fmap compatibilityWritePath launch.launchCompatibilityWrites
            == [ "/tmp/implementers/owner_name__issue42/issue-state.json"
               , "/tmp/implementers/owner_name__issue42/daemon-state.json"
               ]
          && lookupValue "threadId" launch.launchConfigJson == Just (String "thread-created")
    , assert "pending launch manifest preserves issue identity and paths" $
        lookupValue "repo" pending == Just (String "owner/name")
          && lookupValue "issueNumber" pending == Just (Number 42)
          && lookupValue "workdir" pending == Just (String "/tmp/worktrees/owner_name__issue42")
          && lookupValue "stateDir" pending == Just (String "/tmp/implementers/owner_name__issue42")
          && lookupValue "configPath" pending == Just (String "/tmp/implementers/owner_name__issue42/config.json")
          && lookupValue "eventsPath" pending == Just (String "/tmp/implementers/owner_name__issue42/events.jsonl")
    , assert "pending launch manifest preserves intended thread and child launch mode" $
        case lookupValue "intendedThreadRoles" pending of
          Just (Array _) ->
            lookupValue "threadId" pending == Just (String "thread-created")
              && lookupValue "childLaunch" pending == Just (String "print")
          _ ->
            False
    , assert "finalized launch manifest preserves finalized status and start mode" $
        lookupValue "status" finalized == Just (String "finalized")
          && lookupValue "childLaunch" finalized == Just (String "start")
    , assert "dry-run child command keeps run-issue-implement runtime shape" $
        args
          == [ "run-issue-implement"
             , "--events"
             , "/tmp/implementers/owner_name__issue42/events.jsonl"
             , "--state-dir"
             , "/tmp/implementers/owner_name__issue42"
             , "--repo"
             , "owner/name"
             , "--workdir"
             , "/tmp/worktrees/owner_name__issue42"
             , "--app-server-host"
             , "127.0.0.1"
             , "--app-server-port"
             , "4500"
             , "--poll-seconds"
             , "17"
             , "--execute"
             , "--loop"
             , "--pid-file"
             , "/tmp/implementers/owner_name__issue42/issue-watcher.pid"
             , "--app-server-path"
             , "/api/codex"
             ]
    ]

issueImplementerLaunchSourcePreservesWriteOrdering :: IO Bool
issueImplementerLaunchSourcePreservesWriteOrdering = do
  source <- TextIO.readFile "src/CodexWatcher/Cli/Command/IssueFanout.hs"
  sequenceAnd
    [ assert "launch write appends event before compatibility writes" $
        textNeedlesInOrder
          [ "writeJsonValue launch.launchConfigPath launch.launchConfigJson"
          , "appendWatcherEvent ioRuntimeInterpreter launch.launchEventsPath launch.launchInitialEvent"
          , "mapM_ (writeCompatibility ioRuntimeInterpreter) launch.launchCompatibilityWrites"
          ]
          source
    , assert "execute launch writes pending manifest before config/events and finalizes before start" $
        textNeedlesInOrder
          [ "writeIssueImplementerLaunchPending childLaunch launch"
          , "writeIssueImplementerLaunch preparedLaunch"
          , "writeIssueImplementerLaunchFinalized childLaunch preparedLaunch"
          , "startIssueImplementerChildDetailed childLaunch preparedLaunch"
          ]
          source
    , assert "child start classification treats terminal complete before ready as complete and running as started" $
        textNeedlesInOrder
          [ "WatcherTerminal TerminalComplete ->"
          , "IssueImplementerChildCompletedBeforeReady issue"
          , "WatcherActiveRunning ->"
          , "IssueImplementerChildStarted issue"
          , "IssueImplementerChildStartProblem issue detail status"
          ]
          source
    ]

prop_issuePlanningFanoutAllowsScopedDependencyClosure :: Bool
prop_issuePlanningFanoutAllowsScopedDependencyClosure =
  let plannerConfig = PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) [IssueNumber 8]
      graph =
        PlanningGraph
          [IssueNumber 15]
          [BlockedPlanningIssue (IssueNumber 8) [IssueNumber 15, IssueNumber 16] "wait"]
          [ IssueDependency (IssueNumber 8) [IssueNumber 15, IssueNumber 16]
          , IssueDependency (IssueNumber 15) []
          , IssueDependency (IssueNumber 16) [IssueNumber 15]
          ]
   in readyIssueAllowedByPlannerScope plannerConfig (Just graph) (IssueNumber 15)
        && not (readyIssueAllowedByPlannerScope plannerConfig (Just graph) (IssueNumber 99))
        && not (readyIssueAllowedByPlannerScope plannerConfig Nothing (IssueNumber 15))

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

prop_eventLogCanonicalJsonRoundTrips :: Bool
prop_eventLogCanonicalJsonRoundTrips =
  all roundTrips canonicalEventExamples
 where
  roundTrips event =
    (eitherDecodeStrict' (LazyByteString.toStrict (encode event)) :: Either String WatcherEvent)
      == Right event

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

prop_eventLogCanonicalIssuePlanStartName :: TurnId -> Bool
prop_eventLogCanonicalIssuePlanStartName turnId =
  lookupValue "type" (toJSON (IssuePlanTurnStartedEvent turnId)) == Just (String "issue_plan_turn_started")

prop_eventLogRejectsLegacyIssuePlanAliases :: Bool
prop_eventLogRejectsLegacyIssuePlanAliases =
  all rejects legacyAliasValues
 where
  rejects value =
    case eitherDecodeStrict' (LazyByteString.toStrict (encode value)) :: Either String WatcherEvent of
      Left _ -> True
      Right _ -> False
  legacyAliasValues =
    [ object ["type" .= ("issue_plan_started" :: Text), "planTurnId" .= ("turn-plan" :: Text)]
    , object ["type" .= ("issue_implement_plan_turn_started" :: Text), "planTurnId" .= ("turn-plan" :: Text)]
    ]

prop_eventLogRejectsEmptyReviewThreads :: Bool
prop_eventLogRejectsEmptyReviewThreads =
  case eitherDecodeStrict' (LazyByteString.toStrict (encode value)) :: Either String WatcherEvent of
    Left _ -> True
    Right _ -> False
 where
  value =
    object
      [ "type" .= ("pr_review_unresolved_found" :: Text)
      , "reviewThreadIds" .= ([] :: [Text])
      , "commitSha" .= ("0123456789abcdef" :: Text)
      , "workerTurnId" .= ("turn-worker" :: Text)
    ]

prop_eventLogRepairIssue26MissingPlanReentersImplementation :: Bool
prop_eventLogRepairIssue26MissingPlanReentersImplementation =
  let issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 26) (BranchName "codex/issue-26")
      workerThread = ThreadId "019db372-3514-73e0-9a0c-cded70672e15"
      prNumber' = PrNumber 29
      invalidEvents =
        [ IssueImplementInitialized issueConfig workerThread
        , IssuePullRequestCreatedEvent prNumber'
        , IssueImplementationCompletedEvent prNumber' Nothing
        ]
   in case repairIssueImplementEventLog invalidEvents of
        Left _ -> False
        Right plan ->
          any isRecovery plan.repairInsertedEvents
            && IssueImplementationCompletedEvent prNumber' Nothing `elem` plan.repairDroppedEvents
            && case replayEventLog plan.repairRepairedEvents of
              Right replay ->
                case replay.replayState of
                  SomeWatcherState (IssuePlanReady _ repairedPr (WorkerIdle repairedThread)) ->
                    repairedPr == prNumber' && repairedThread == workerThread
                  _ -> False
              Left _ -> False
 where
  isRecovery = \case
    WatcherRecoveredInvalidState {} -> True
    _ -> False

prop_eventLogRepairDropsCompletionWithoutImplementationTurn :: Bool
prop_eventLogRepairDropsCompletionWithoutImplementationTurn =
  let issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
      workerThread = ThreadId "worker-thread"
      prNumber' = PrNumber 7
      legacyEvents =
        [ IssueImplementInitialized issueConfig workerThread
        , IssuePullRequestCreatedEvent prNumber'
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        , IssueImplementationCompletedEvent prNumber' Nothing
        ]
   in expectLeft (replayEventLog legacyEvents)
        && case repairIssueImplementEventLog legacyEvents of
          Left _ -> False
          Right plan ->
            IssueImplementationCompletedEvent prNumber' Nothing `elem` plan.repairDroppedEvents
              && any isRecovery plan.repairInsertedEvents
              && case replayEventLog plan.repairRepairedEvents of
                Right replay ->
                  case replay.replayState of
                    SomeWatcherState (IssuePlanReady _ repairedPr (WorkerIdle repairedThread)) ->
                      repairedPr == prNumber' && repairedThread == workerThread
                    _ -> False
                Left _ -> False
 where
  isRecovery = \case
    WatcherRecoveredInvalidState {} -> True
    _ -> False

prop_eventLogRepairDropsStalePlanningReadyIssuesFixed :: Bool
prop_eventLogRepairDropsStalePlanningReadyIssuesFixed =
  let config = PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) [IssueNumber 12]
      plannerThread = ThreadId "planner-thread"
      firstTurn = TurnId "planner-turn-1"
      secondTurn = TurnId "planner-turn-2"
      graph = PlanningGraph [IssueNumber 12] [] []
      invalidEvents =
        [ IssuePlanningInitialized config
        , IssuePlanningTurnStarted plannerThread firstTurn
        , IssuePlanningGraphUpdated graph
        , IssuePlanningReadyIssuesFixed
        , IssuePlanningTurnStarted plannerThread secondTurn
        , IssuePlanningReadyIssuesFixed
        ]
   in case repairIssueImplementEventLog invalidEvents of
        Left _ -> False
        Right plan ->
          plan.repairDroppedEvents == [IssuePlanningReadyIssuesFixed]
            && case replayEventLog plan.repairRepairedEvents of
              Right replay -> someDomain replay.replayState == IssuePlanning && somePhase replay.replayState == PlanMode
              Left _ -> False

prop_eventLogRepairRejectsValidEventLog :: IssueConfig -> ThreadId -> TurnId -> TurnId -> PrNumber -> Bool
prop_eventLogRepairRejectsValidEventLog config workerThread planTurn implementationTurn prNumber' =
  let reviewerThread = ThreadId "issue-post-merge-reviewer"
      reviewedCommit = CommitSha "0123456789abcdef"
      reviewerTurn = TurnId "post-merge-review"
   in case repairIssueImplementEventLog
        [ IssueImplementInitialized config workerThread
        , IssuePullRequestCreatedEvent prNumber'
        , IssuePlanTurnStartedEvent planTurn
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        , IssuePullRequestBodyUpdatedEvent prNumber'
        , IssueImplementationTurnStartedEvent implementationTurn
        , IssueImplementationCompletedEvent prNumber' Nothing
        , IssueReviewHandoffInitializedEvent prNumber'
        , IssueReviewHandoffStartedEvent prNumber'
        , IssuePullRequestMergedEvent prNumber'
        , IssueReviewerThreadReadyEvent reviewerThread
        , IssuePostMergeReviewStartedEvent reviewedCommit reviewerTurn
        , IssuePostMergeReviewCleanEvent (CleanReviewEvidence reviewedCommit "LGTM")
        , IssueClosedEvent prNumber'
        ] of
        Left _ -> True
        Right _ -> False

issueImplementEventLogRepairCliPreservesDryRunAndExecuteContract :: IO Bool
issueImplementEventLogRepairCliPreservesDryRunAndExecuteContract = do
  replaySource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Cli" </> "Command" </> "Replay.hs")
  repairSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "EventLogRepair.hs")
  sequenceAnd
    [ assert "repair CLI dry-run reports strategy, failed index, event counts, and phase before mutation" $
        textNeedlesInOrder
          [ "putStrLn (\"repair strategy: \""
          , "putStrLn (\"failed event index: \""
          , "putStrLn (\"inserted events: \""
          , "putStrLn (\"dropped events: \""
          , "putStrLn (\"repaired phase: \""
          , "if options.repairCliExecute"
          , "putStrLn \"dry-run: pass --execute to archive and rewrite events.jsonl\""
          ]
          replaySource
    , assert "repair execute archives, rewrites events, writes repair state, rewrites compatibility, then removes block state" $
        textNeedlesInOrder
          [ "archivePath <- archiveEventLog options.repairCliEventsPath"
          , "writeWatcherEventsFile options.repairCliEventsPath plan.repairRepairedEvents"
          , "writeRepairSummary options.repairCliStateDir archivePath plan"
          , "writeCompatibilityFiles options.repairCliStateDir plan.repairReplayResult.replayState"
          , "removeFileIfExists (options.repairCliStateDir </> \"block-state.json\")"
          ]
          replaySource
    , assert "repair rules keep stale marker and unsafe completion drops deterministic" $
        all
          (`Text.isInfixOf` repairSource)
          [ "repairStalePlanningReadyIssuesFixed"
          , "dropped stale planning ready-issues marker"
          , "dropUnsafeImplementationCompletions"
          , "dropped unsafe completion and re-entered implementation"
          , "inserted missing issue plan events and re-entered implementation before marking complete"
          ]
    ]

prop_protocolPrReviewWorkerCompletedReturnsToChecking :: PrConfig -> ThreadId -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> Bool
prop_protocolPrReviewWorkerCompletedReturnsToChecking config workerThread reviewerThread reviewThreadIds reviewedCommit workerTurn =
  let evidence = reviewEvidenceFromThreads reviewThreadIds reviewedCommit
      session = newPrReviewWorkerSession config workerThread evidence
      (_finished, events) = runPrReviewWorkerProtocol workerTurn WorkerCompleted session
   in case replayEventLog (PrReviewInitialized config workerThread reviewerThread : events) of
        Right replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == CheckingReviews
        Left _ -> False

prop_protocolPrReviewWorkerIncompleteReturnsToChecking :: PrConfig -> ThreadId -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> BlockedReason -> Bool
prop_protocolPrReviewWorkerIncompleteReturnsToChecking config workerThread reviewerThread reviewThreadIds reviewedCommit workerTurn reason =
  let evidence = reviewEvidenceFromThreads reviewThreadIds reviewedCommit
      session = newPrReviewWorkerSession config workerThread evidence
      (_finished, events) = runPrReviewWorkerProtocol workerTurn (WorkerIncomplete (unBlockedReason reason)) session
   in case replayEventLog (PrReviewInitialized config workerThread reviewerThread : events) of
        Right replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == CheckingReviews
        Left _ -> False

prop_protocolPrReviewWorkerBlockedStopsInBlocked :: PrConfig -> ThreadId -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> BlockedReason -> Bool
prop_protocolPrReviewWorkerBlockedStopsInBlocked config workerThread reviewerThread reviewThreadIds reviewedCommit workerTurn reason =
  let evidence = reviewEvidenceFromThreads reviewThreadIds reviewedCommit
      session = newPrReviewWorkerSession config workerThread evidence
      (_finished, events) = runPrReviewWorkerProtocol workerTurn (WorkerBlocked reason) session
   in case replayEventLog (PrReviewInitialized config workerThread reviewerThread : events) of
        Right replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == Blocked
        Left _ -> False

prop_protocolPrReviewWorkerEmitsStartThenTerminalEvent :: PrConfig -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> Bool
prop_protocolPrReviewWorkerEmitsStartThenTerminalEvent config workerThread reviewThreadIds reviewedCommit workerTurn =
  let evidence = reviewEvidenceFromThreads reviewThreadIds reviewedCommit
      session = newPrReviewWorkerSession config workerThread evidence
      (_finished, events) = runPrReviewWorkerProtocol workerTurn WorkerCompleted session
   in case events of
        [PrReviewFeedbackFound emittedEvidence emittedTurn, PrReviewFixCompleted] ->
          emittedEvidence == evidence
            && emittedTurn == workerTurn
        _ -> False

prop_protocolPrReviewReviewerCleanWaitsForMergeability :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> CleanReviewEvidence -> Bool
prop_protocolPrReviewReviewerCleanWaitsForMergeability config workerThread reviewerThread reviewTarget reviewerTurn cleanEvidence =
  let session = newPrReviewReviewerSession config reviewerThread reviewTarget
      (_finished, events) = runPrReviewReviewerProtocol reviewerTurn (ReviewerClean cleanEvidence []) session
   in case replayEventLog (PrReviewInitialized config workerThread reviewerThread : events) of
        Right replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == WaitingMergeability
        Left _ -> False

prop_protocolPrReviewReviewerBlockedStopsInBlocked :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> BlockedReason -> Bool
prop_protocolPrReviewReviewerBlockedStopsInBlocked config workerThread reviewerThread reviewTarget reviewerTurn reason =
  let session = newPrReviewReviewerSession config reviewerThread reviewTarget
      (_finished, events) = runPrReviewReviewerProtocol reviewerTurn (ReviewerBlocked reason) session
   in case replayEventLog (PrReviewInitialized config workerThread reviewerThread : events) of
        Right replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == Blocked
        Left _ -> False

prop_protocolPrReviewReviewerProblemsReturnToChecking :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> Bool
prop_protocolPrReviewReviewerProblemsReturnToChecking config workerThread reviewerThread reviewTarget reviewerTurn =
  let session = newPrReviewReviewerSession config reviewerThread reviewTarget
      evidence = reviewEvidenceFromSummaries ("reviewer reported problems" :| []) reviewTarget
      (_finished, events) = runPrReviewReviewerProtocol reviewerTurn (ReviewerProblemsAdded evidence []) session
   in case replayEventLog (PrReviewInitialized config workerThread reviewerThread : events) of
        Right replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == CheckingReviews
        Left _ -> False

prop_protocolPrReviewReviewerIncompleteReturnsToChecking :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> BlockedReason -> Bool
prop_protocolPrReviewReviewerIncompleteReturnsToChecking config workerThread reviewerThread reviewTarget reviewerTurn reason =
  let session = newPrReviewReviewerSession config reviewerThread reviewTarget
      (_finished, events) = runPrReviewReviewerProtocol reviewerTurn (ReviewerIncomplete (unBlockedReason reason)) session
   in case replayEventLog (PrReviewInitialized config workerThread reviewerThread : events) of
        Right replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == CheckingReviews
        Left _ -> False

prop_protocolPrReviewReviewerEmitsStartThenCleanEvent :: PrConfig -> ThreadId -> CommitSha -> TurnId -> CleanReviewEvidence -> Bool
prop_protocolPrReviewReviewerEmitsStartThenCleanEvent config reviewerThread reviewTarget reviewerTurn cleanEvidence =
  let session = newPrReviewReviewerSession config reviewerThread reviewTarget
      (_finished, events) = runPrReviewReviewerProtocol reviewerTurn (ReviewerClean cleanEvidence []) session
   in case events of
        [PrReviewNoUnresolvedFound emittedCommit emittedTurn, PrReviewCleanFound emittedEvidence resolvedThreadIds] ->
          emittedCommit == reviewTarget
            && emittedTurn == reviewerTurn
            && emittedEvidence == cleanEvidence
            && null resolvedThreadIds
        _ -> False

prop_protocolPrReviewWorkerThenReviewerThenMergeCompletes :: PrConfig -> ThreadId -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> TurnId -> TurnId -> MergeCommit -> Bool
prop_protocolPrReviewWorkerThenReviewerThenMergeCompletes config workerThread reviewerThread reviewThreadIds commit workerTurn verificationTurn finalReviewTurn mergeCommit =
  let reviewEvidence = reviewEvidenceFromThreads reviewThreadIds commit
      workerSession = newPrReviewWorkerSession config workerThread reviewEvidence
      (_workerFinished, workerEvents) = runPrReviewWorkerProtocol workerTurn WorkerCompleted workerSession
      cleanEvidence = CleanReviewEvidence commit "LGTM"
      reviewerEvents =
        [ PrReviewFixVerificationStarted reviewEvidence commit verificationTurn
        , PrReviewCleanFound cleanEvidence (Foldable.toList reviewThreadIds)
        , PrReviewNoUnresolvedFound commit finalReviewTurn
        , PrReviewCleanFound cleanEvidence []
        ]
      events = PrReviewInitialized config workerThread reviewerThread : workerEvents <> reviewerEvents <> [PrReviewMergeabilityClean commit, PrReviewMergeCompleted mergeCommit]
   in case replayEventLog events of
        Right replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == Complete
        Left _ -> False

reviewThreadsReport :: [ReviewThreadId] -> ReviewThreadsReport
reviewThreadsReport unresolved =
  ReviewThreadsReport
    { reviewThreads = unresolvedThreads <> [resolvedThread]
    , unresolvedReviewThreads = unresolvedThreads
    }
 where
  unresolvedThreads =
    fmap
      (\threadId -> ReviewThread threadId False False (Just "src/File.hs") (Just 12) Nothing [] Nothing)
      unresolved
  resolvedThread =
    ReviewThread (ReviewThreadId "resolved-thread") True False Nothing Nothing Nothing [] Nothing

prop_prReviewWatcherUnresolvedStartsWorker :: PrConfig -> ThreadId -> ThreadId -> ReviewThreadId -> CommitSha -> TurnId -> Bool
prop_prReviewWatcherUnresolvedStartsWorker config workerThread reviewerThread reviewThreadId commit turnId =
  let state = SomeWatcherState (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      observation = ObservedReviewThreads (reviewThreadsReport [reviewThreadId]) commit turnId
   in case prReviewObserve state observation of
        Right tick ->
          prReviewTickEvent tick == PrReviewUnresolvedFound (reviewThreadId :| []) commit turnId
            && somePhase tick.prReviewTickState == FixingReviews
            && hasEffect StartWorkerTurnTag tick.prReviewTickEffects
        Left _ -> False

prop_prReviewWatcherUnresolvedSendsThreadSummaryToWorker :: PrConfig -> ThreadId -> ThreadId -> ReviewThreadId -> CommitSha -> TurnId -> Bool
prop_prReviewWatcherUnresolvedSendsThreadSummaryToWorker config workerThread reviewerThread reviewThreadId commit turnId =
  let state = SomeWatcherState (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      unresolvedThread =
        ReviewThread
          reviewThreadId
          False
          False
          (Just "src/File.hs")
          (Just 12)
          Nothing
          [ReviewComment "comment-1" "please fix this path" Nothing Nothing (Just "reviewer") (Just "https://github.com/soulomoon/mlf2/pull/1#discussion_r1")]
          (Just "https://github.com/soulomoon/mlf2/pull/1#discussion_r1")
      report =
        ReviewThreadsReport
          { reviewThreads = [unresolvedThread]
          , unresolvedReviewThreads = [unresolvedThread]
          }
      observation = ObservedReviewThreads report commit turnId
      expectedThreadSummary = "src/File.hs:12 | reviewer: please fix this path"
   in case prReviewObserve state observation of
        Right tick ->
          case startWorkerEvidenceFromEffects tick.prReviewTickEffects of
            Just evidence ->
              reviewEvidenceThreadComments evidence == [(reviewThreadId, expectedThreadSummary)]
                && reviewEvidenceThreadIds evidence == [reviewThreadId]
            Nothing -> False
        Left _ -> False

prop_prReviewWatcherCleanStartsReviewer :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> Bool
prop_prReviewWatcherCleanStartsReviewer config workerThread reviewerThread commit turnId =
  let state = SomeWatcherState (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      observation = ObservedReviewThreads (reviewThreadsReport []) commit turnId
   in case prReviewObserve state observation of
        Right tick ->
          prReviewTickEvent tick == PrReviewNoUnresolvedFound commit turnId
            && somePhase tick.prReviewTickState == ReviewingClean
            && hasEffect StartReviewerTurnTag tick.prReviewTickEffects
        Left _ -> False

prop_prReviewWatcherWorkerIncompleteReturnsToChecking :: PrConfig -> ThreadId -> ThreadId -> ReviewThreadId -> CommitSha -> TurnId -> BlockedReason -> Bool
prop_prReviewWatcherWorkerIncompleteReturnsToChecking config workerThread reviewerThread reviewThreadId commit turnId reason =
  let state =
        SomeWatcherState
          ( PrFixingReviews
              config
              (reviewEvidenceFromThreads (reviewThreadId :| []) commit)
              (WorkerActive (ActiveTurn workerThread turnId))
              (ReviewerIdle reviewerThread)
          )
   in case prReviewObserve state (ObservedWorkerOutcome (WorkerIncomplete (unBlockedReason reason))) of
        Right tick ->
          prReviewTickEvent tick == PrReviewFixIncomplete (unBlockedReason reason)
            && somePhase tick.prReviewTickState == CheckingReviews
            && lacksEffect MergePullRequestTag tick.prReviewTickEffects
        Left _ -> False

prop_prReviewWatcherCleanReviewerWaitsForMergeability :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> CleanReviewEvidence -> Bool
prop_prReviewWatcherCleanReviewerWaitsForMergeability config workerThread reviewerThread commit turnId evidence =
  let state =
        SomeWatcherState
          ( PrReviewingClean
              config
              commit
              normalReviewContext
              (WorkerIdle workerThread)
              (ReviewerActive (ActiveTurn reviewerThread turnId))
          )
   in case prReviewObserve state (ObservedReviewerOutcome (ReviewerClean evidence [])) of
        Right tick ->
          prReviewTickEvent tick == PrReviewCleanFound evidence []
            && somePhase tick.prReviewTickState == WaitingMergeability
            && hasEffect SleepUntilNextPollTag tick.prReviewTickEffects
            && lacksEffect MergePullRequestTag tick.prReviewTickEffects
        Left _ -> False

prReviewingCleanVerificationState :: PrConfig -> ReviewEvidence -> ThreadId -> ThreadId -> CommitSha -> TurnId -> SomeWatcherState
prReviewingCleanVerificationState config evidence workerThread reviewerThread reviewTarget turnId =
  SomeWatcherState
    ( PrReviewingClean
        config
        reviewTarget
        (verificationReviewContext evidence)
        (WorkerIdle workerThread)
        (ReviewerActive (ActiveTurn reviewerThread turnId))
    )

prop_prReviewVerificationCleanResolvesFixedThreadsAndRechecks :: PrConfig -> ThreadId -> ThreadId -> ReviewThreadId -> CommitSha -> CommitSha -> TurnId -> Bool
prop_prReviewVerificationCleanResolvesFixedThreadsAndRechecks config workerThread reviewerThread reviewThreadId oldCommit reviewTarget turnId =
  let evidence = reviewEvidenceFromThreads (reviewThreadId :| []) oldCommit
      cleanEvidence = CleanReviewEvidence reviewTarget "LGTM"
      state = prReviewingCleanVerificationState config evidence workerThread reviewerThread reviewTarget turnId
   in case prReviewObserve state (ObservedReviewerOutcome (ReviewerClean cleanEvidence [reviewThreadId])) of
        Right tick ->
          prReviewTickEvent tick == PrReviewCleanFound cleanEvidence [reviewThreadId]
            && somePhase tick.prReviewTickState == CheckingReviews
            && hasEffect ResolveReviewThreadTag tick.prReviewTickEffects
            && hasEffect ReadReviewThreadsTag tick.prReviewTickEffects
            && lacksEffect MergePullRequestTag tick.prReviewTickEffects
        Left _ -> False

prop_prReviewVerificationCleanRechecksSummaryOnlyEvidence :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> CommitSha -> TurnId -> Bool
prop_prReviewVerificationCleanRechecksSummaryOnlyEvidence config workerThread reviewerThread oldCommit reviewTarget turnId =
  let evidence = reviewEvidenceFromSummaries ("GitHub reports reviewDecision=CHANGES_REQUESTED" :| []) oldCommit
      cleanEvidence = CleanReviewEvidence reviewTarget "LGTM"
      state = prReviewingCleanVerificationState config evidence workerThread reviewerThread reviewTarget turnId
   in case prReviewObserve state (ObservedReviewerOutcome (ReviewerClean cleanEvidence [])) of
        Right tick ->
          prReviewTickEvent tick == PrReviewCleanFound cleanEvidence []
            && somePhase tick.prReviewTickState == CheckingReviews
            && hasEffect ReadReviewThreadsTag tick.prReviewTickEffects
            && lacksEffect ResolveReviewThreadTag tick.prReviewTickEffects
            && lacksEffect SleepUntilNextPollTag tick.prReviewTickEffects
            && lacksEffect MergePullRequestTag tick.prReviewTickEffects
        Left _ -> False

prop_prReviewVerificationCleanRequiresResolvedThreadIds :: PrConfig -> ThreadId -> ThreadId -> ReviewThreadId -> CommitSha -> CommitSha -> TurnId -> Bool
prop_prReviewVerificationCleanRequiresResolvedThreadIds config workerThread reviewerThread reviewThreadId oldCommit reviewTarget turnId =
  let evidence = reviewEvidenceFromThreads (reviewThreadId :| []) oldCommit
      cleanEvidence = CleanReviewEvidence reviewTarget "LGTM"
      state = prReviewingCleanVerificationState config evidence workerThread reviewerThread reviewTarget turnId
   in case prReviewObserve state (ObservedReviewerOutcome (ReviewerClean cleanEvidence [])) of
        Right tick ->
          case prReviewTickEvent tick of
            PrReviewReviewIncomplete reason ->
              "did not mark fixed prior review threads as resolved" `Text.isInfixOf` reason
                && lacksEffect ResolveReviewThreadTag tick.prReviewTickEffects
            _ -> False
        Left _ -> False

prop_prReviewRemainingThreadsReplyAndQueueWorker :: PrConfig -> ThreadId -> ThreadId -> ReviewThreadId -> ReviewThreadId -> CommitSha -> CommitSha -> TurnId -> Bool
prop_prReviewRemainingThreadsReplyAndQueueWorker config workerThread reviewerThread solvedThreadId remainingThreadId oldCommit reviewTarget turnId =
  let oldEvidence = reviewEvidenceFromThreads (solvedThreadId :| []) oldCommit
      remainingEvidence = reviewEvidenceFromThreadComments ((remainingThreadId, "still applies") :| []) reviewTarget
      state =
        PrReviewingClean
          config
          reviewTarget
          (verificationReviewContext oldEvidence)
          (WorkerIdle workerThread)
          (ReviewerActive (ActiveTurn reviewerThread turnId))
   in case step state (ReviewerFoundProblems remainingEvidence [solvedThreadId]) of
        Decision nextState effects ->
          somePhase (SomeWatcherState nextState) == CheckingReviews
            && effects
              == [ SomeEffect (ResolveReviewThread solvedThreadId)
                 , SomeEffect (ReplyReviewThread remainingThreadId "still applies")
                 , SomeEffect SleepUntilNextPoll
                 ]

jsonText :: Value -> Text
jsonText =
  Text.Encoding.decodeUtf8 . LazyByteString.toStrict . encode

reviewerStateOutput :: Text -> Text -> CommitSha -> Text -> Int -> Maybe Text -> [Text] -> [Text] -> Maybe Text -> Text
reviewerStateOutput priorStatus newStatus commit promptVersion commentCount lgtmComment priorFindings newFindings blockedReason =
  reviewerStateOutputWithRemaining priorStatus newStatus commit promptVersion commentCount lgtmComment priorFindings newFindings blockedReason []

reviewerStateOutputWithRemaining :: Text -> Text -> CommitSha -> Text -> Int -> Maybe Text -> [Text] -> [Text] -> Maybe Text -> [(ReviewThreadId, Text)] -> Text
reviewerStateOutputWithRemaining priorStatus newStatus commit promptVersion commentCount lgtmComment priorFindings newFindings blockedReason remainingThreads =
  reviewerStateOutputWithSolvedAndRemaining priorStatus newStatus commit promptVersion commentCount lgtmComment priorFindings newFindings blockedReason [] remainingThreads

reviewerStateOutputWithSolvedAndRemaining :: Text -> Text -> CommitSha -> Text -> Int -> Maybe Text -> [Text] -> [Text] -> Maybe Text -> [(ReviewThreadId, Text)] -> [(ReviewThreadId, Text)] -> Text
reviewerStateOutputWithSolvedAndRemaining priorStatus newStatus commit promptVersion commentCount lgtmComment priorFindings newFindings blockedReason solvedThreads remainingThreads =
  jsonText
    ( object
        [ "reviewed_commit_sha" .= unCommitSha commit
        , "reviewer_prompt_version" .= promptVersion
        , "added_review_comment_count" .= commentCount
        , "prior_findings_status" .= priorStatus
        , "new_findings_status" .= newStatus
        , "lgtm_comment" .= lgtmComment
        , "prior_findings_summary" .= priorFindings
        , "new_findings_summary" .= newFindings
        , "blocked_reason" .= blockedReason
        , "solved_threads" .= solvedReviewThreadsJson solvedThreads
        , "remaining_review_threads" .= remainingReviewThreadsJson remainingThreads
        ]
    )

solvedReviewThreadsJson :: [(ReviewThreadId, Text)] -> [Value]
solvedReviewThreadsJson =
  fmap \(threadId, summary) ->
    object
      [ "thread_id" .= unReviewThreadId threadId
      , "resolution_summary" .= summary
      ]

remainingReviewThreadsJson :: [(ReviewThreadId, Text)] -> [Value]
remainingReviewThreadsJson =
  fmap \(threadId, summary) ->
    object
      [ "thread_id" .= unReviewThreadId threadId
      , "comment" .= summary
      ]

issueFinalReviewOutput :: Text -> CommitSha -> Text -> Bool -> Bool -> Bool -> Bool -> [Text] -> [Text] -> Maybe Text -> Maybe Text -> Text
issueFinalReviewOutput status commit promptVersion issueSolved planImplemented testsSufficient reworkRequired verification findings blockedReason lgtmComment =
  jsonText
    ( object
        [ "completion_status" .= status
        , "reviewed_commit_sha" .= unCommitSha commit
        , "reviewer_prompt_version" .= promptVersion
        , "issue_solved" .= issueSolved
        , "plan_implemented" .= planImplemented
        , "tests_sufficient" .= testsSufficient
        , "rework_required" .= reworkRequired
        , "verification_summary" .= verification
        , "findings_summary" .= findings
        , "blocked_reason" .= blockedReason
        , "lgtm_comment" .= lgtmComment
        ]
    )

prop_turnClassifierCompletionStates :: Bool
prop_turnClassifierCompletionStates =
  classifyTurnCompletion (AppServerTurn (TurnId "running") "running" Nothing) == TurnStillRunning
    && classifyTurnCompletion (AppServerTurn (TurnId "done") "completed" (Just "complete")) == TurnCompleted (Just "complete")
    && classifyTurnCompletion (AppServerTurn (TurnId "failed") "failed" (Just "blocked by CI")) == TurnFailed "blocked by CI"

prop_turnClassifierMapsDomainOutputs :: Bool
prop_turnClassifierMapsDomainOutputs =
  let reviewerCommit = CommitSha "abc123"
      cleanReviewOutput = reviewerStateOutput "not_applicable" "none" reviewerCommit reviewerPromptVersion 0 (Just "LGTM") [] [] Nothing
      cleanFinalReviewOutput = issueFinalReviewOutput "clean" reviewerCommit reviewerPromptVersion True True True False ["validated issue and plan"] [] Nothing (Just "LGTM")
   in
  classifyIssuePlanningTurn (AppServerTurn (TurnId "planning") "completed" (Just "stable issue set")) == Just (ObservedPlanningBlocked (BlockedReason "planning turn completed without structured outcome"))
    && classifyIssuePlanTurn (AppServerTurn (TurnId "plan") "completed" (Just "plan written")) == Just (ObservedIssueImplementBlocked (BlockedReason "plan turn completed without structured plan output"))
    && classifyIssueImplementationTurn (Just (PrNumber 7)) Nothing (AppServerTurn (TurnId "impl") "completed" (Just "ready for review")) == Just (ObservedImplementationIncomplete "implementation turn completed without structured outcome")
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker") "completed" (Just "resolved")) == Just (ObservedWorkerOutcome (WorkerIncomplete "worker turn completed without structured outcome"))
    && classifyPrReviewReviewerTurn reviewerCommit (AppServerTurn (TurnId "reviewer") "completed" (Just cleanReviewOutput)) == Just (ObservedReviewerOutcome (ReviewerClean (CleanReviewEvidence reviewerCommit "LGTM") []))
    && classifyIssueFinalReviewTurn reviewerCommit (AppServerTurn (TurnId "final-reviewer") "completed" (Just cleanFinalReviewOutput)) == Just (IssueFinalReviewClean (CleanReviewEvidence reviewerCommit "LGTM"))

prop_turnClassifierPrefersStructuredOutputs :: Bool
prop_turnClassifierPrefersStructuredOutputs =
  let issueRequest = IssueCreationRequest "Subissue A" "Split from parent" Nothing
      subissueRequest = IssueCreationRequest "Subissue B" "Split from existing parent" (Just (IssueNumber 8))
      planningGraph =
        PlanningGraph
          [IssueNumber 15]
          [BlockedPlanningIssue (IssueNumber 16) [IssueNumber 15] "wait"]
          [IssueDependency (IssueNumber 16) [IssueNumber 15]]
      remainingThreadEvidence =
        reviewEvidenceFromThreadComments ((ReviewThreadId "thread-1", "still not fixed") :| []) (CommitSha "abc123")
      combinedPriorAndNewEvidence =
        ReviewEvidence
          ( ReviewThreadCommentFinding (ReviewThreadId "thread-1") Nothing "still not fixed"
              :| [ReviewSummaryFinding "new summary finding"]
          )
          (CommitSha "abc123")
   in parseStructuredTurnOutcome "{\"outcome\":\"blocked\",\"reason\":\"schema blocker\"}" == Just (StructuredBlocked "schema blocker")
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning") "completed" (Just "{\"outcome\":\"complete\",\"issues_to_create\":[{\"title\":\"Subissue A\",\"body\":\"Split from parent\"}]}")) == Just (ObservedPlanningIssuesRequested (issueRequest :| []))
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-subissue") "completed" (Just "{\"outcome\":\"complete\",\"subissues_to_create\":[{\"title\":\"Subissue B\",\"body\":\"Split from existing parent\",\"parentIssueNumber\":8}]}")) == Just (ObservedPlanningIssuesRequested (subissueRequest :| []))
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-invalid-subissue") "completed" (Just "{\"outcome\":\"complete\",\"subissues_to_create\":[{\"title\":\"Subissue B\",\"parentIssueNumber\":8}]}")) == Just (ObservedPlanningBlocked (BlockedReason "planning turn returned invalid issue creation payload"))
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-graph") "completed" (Just "{\"outcome\":\"complete\",\"ready_issues\":[15],\"blocked_issues\":[{\"issueNumber\":16,\"blockedBy\":[15],\"reason\":\"wait\"}],\"dependencies\":[{\"issueNumber\":16,\"dependsOn\":[15]}]}")) == Just (ObservedPlanningGraphUpdated planningGraph)
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-graph-with-empty-issue-requests") "completed" (Just "{\"outcome\":\"complete\",\"issues_to_create\":[],\"subissues_to_create\":[],\"ready_issues\":[15],\"blocked_issues\":[{\"issueNumber\":16,\"blockedBy\":[15],\"reason\":\"wait\"}],\"dependencies\":[{\"issueNumber\":16,\"dependsOn\":[15]}],\"reason\":\"\",\"summary\":\"graph ready\"}")) == Just (ObservedPlanningGraphUpdated planningGraph)
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-graph-rich") "completed" (Just "{\"outcome\":\"complete\",\"ready_issues\":[{\"number\":15,\"title\":\"ready\"}],\"blocked_issues\":[{\"number\":16,\"blocked_by\":[15],\"reason\":\"wait\"}],\"dependencies\":[{\"issue\":16,\"depends_on\":[15]}]}")) == Just (ObservedPlanningGraphUpdated planningGraph)
    && parseStructuredTurnOutcome "{\"outcome\":\"blocked\"}" == Nothing
    && classifyIssuePlanTurn (AppServerTurn (TurnId "plan") "completed" (Just "{\"outcome\":\"complete\",\"reason\":\"\",\"summary\":\"plan ready\",\"plan_markdown\":\"Implement the issue in small verified steps.\"}")) == Just (ObservedPlanCompleted sampleIssuePlanMarkdown Nothing)
    && classifyIssueImplementationTurn (Just (PrNumber 7)) Nothing (AppServerTurn (TurnId "impl") "completed" (Just "{\"outcome\":\"complete\",\"summary\":\"ready\"}")) == Just (ObservedImplementationCompleted (PrNumber 7) Nothing)
    && classifyIssueImplementationTurn (Just (PrNumber 7)) Nothing (AppServerTurn (TurnId "impl-clean") "completed" (Just "{\"outcome\":\"clean\",\"summary\":\"review-only\"}")) == Just (ObservedImplementationIncomplete "implementation turn completed without structured outcome")
    && classifyIssueImplementationTurn (Just (PrNumber 7)) Nothing (AppServerTurn (TurnId "impl-problems") "completed" (Just "{\"outcome\":\"problems\",\"summary\":\"review-only\"}")) == Just (ObservedImplementationIncomplete "implementation turn completed without structured outcome")
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker") "completed" (Just "{\"outcome\":\"incomplete\",\"reason\":\"tests still failing\"}")) == Just (ObservedWorkerOutcome (WorkerIncomplete "tests still failing"))
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker-failed-complete") "failed" (Just "{\"comment\":\"fix applied\",\"evidence\":\"\",\"outcome\":\"complete\",\"reason\":\"\",\"summary\":\"\"}")) == Just (ObservedWorkerOutcome WorkerCompleted)
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker-failed-incomplete") "failed" (Just "{\"outcome\":\"incomplete\",\"reason\":\"tests still failing\"}")) == Just (ObservedWorkerOutcome (WorkerIncomplete "tests still failing"))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer") "completed" (Just (reviewerStateOutput "not_applicable" "none" (CommitSha "abc123") reviewerPromptVersion 0 (Just "LGTM") [] [] Nothing))) == Just (ObservedReviewerOutcome (ReviewerClean (CleanReviewEvidence (CommitSha "abc123") "LGTM") []))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-clean-null-comment") "completed" (Just (reviewerStateOutput "not_applicable" "none" (CommitSha "abc123") reviewerPromptVersion 0 Nothing [] [] Nothing))) == Just (ObservedReviewerOutcome (ReviewerClean (CleanReviewEvidence (CommitSha "abc123") "LGTM") []))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-resolved-prior-summary") "completed" (Just (reviewerStateOutput "resolved" "none" (CommitSha "abc123") reviewerPromptVersion 0 (Just "LGTM") ["resolved prior summary finding"] [] Nothing))) == Just (ObservedReviewerOutcome (ReviewerClean (CleanReviewEvidence (CommitSha "abc123") "LGTM") []))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-missing-state") "completed" (Just "{\"result\":\"clean\",\"comment\":\"schema LGTM\"}")) == Just (ObservedReviewerOutcome (ReviewerIncomplete "reviewer state missing required fields: reviewed_commit_sha, reviewer_prompt_version, added_review_comment_count, prior_findings_status, new_findings_status, lgtm_comment, prior_findings_summary, new_findings_summary, blocked_reason, solved_threads, remaining_review_threads"))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-new-findings") "completed" (Just (reviewerStateOutput "not_applicable" "found" (CommitSha "abc123") reviewerPromptVersion 0 Nothing [] ["left summary finding"] Nothing))) == Just (ObservedReviewerOutcome (ReviewerProblemsAdded (reviewEvidenceFromSummaries ("left summary finding" :| []) (CommitSha "abc123")) []))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-remaining-thread") "completed" (Just (reviewerStateOutputWithRemaining "unresolved" "none" (CommitSha "abc123") reviewerPromptVersion 0 Nothing [] [] Nothing [(ReviewThreadId "thread-1", "still not fixed")]))) == Just (ObservedReviewerOutcome (ReviewerProblemsAdded remainingThreadEvidence []))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-prior-and-new-findings") "completed" (Just (reviewerStateOutputWithSolvedAndRemaining "unresolved" "found" (CommitSha "abc123") reviewerPromptVersion 0 Nothing [] ["new summary finding"] Nothing [(ReviewThreadId "thread-fixed", "fixed")] [(ReviewThreadId "thread-1", "still not fixed")]))) == Just (ObservedReviewerOutcome (ReviewerProblemsAdded combinedPriorAndNewEvidence [ReviewThreadId "thread-fixed"]))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-not-applicable-solved-thread") "completed" (Just (reviewerStateOutputWithSolvedAndRemaining "not_applicable" "none" (CommitSha "abc123") reviewerPromptVersion 0 Nothing [] [] Nothing [(ReviewThreadId "thread-fixed", "fixed")] []))) == Just (ObservedReviewerOutcome (ReviewerIncomplete "solved_threads require prior_findings_status=resolved or unresolved"))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-sha-mismatch") "completed" (Just (reviewerStateOutput "not_applicable" "none" (CommitSha "def456") reviewerPromptVersion 0 (Just "LGTM") [] [] Nothing))) == Just (ObservedReviewerOutcome (ReviewerIncomplete "reviewer inspected def456, expected abc123"))
    && classifyIssueFinalReviewTurn (CommitSha "abc123") (AppServerTurn (TurnId "final-review-clean") "completed" (Just (issueFinalReviewOutput "clean" (CommitSha "abc123") reviewerPromptVersion True True True False ["validated issue and plan"] [] Nothing Nothing))) == Just (IssueFinalReviewClean (CleanReviewEvidence (CommitSha "abc123") "LGTM"))
    && classifyIssueFinalReviewTurn (CommitSha "abc123") (AppServerTurn (TurnId "final-review-clean-with-findings") "completed" (Just (issueFinalReviewOutput "clean" (CommitSha "abc123") reviewerPromptVersion True True True False ["validated issue and plan"] ["follow-up needed"] Nothing Nothing))) == Just (IssueFinalReviewIncomplete "clean final review must leave findings_summary empty; use verification_summary for successful validation evidence")
    && classifyIssueFinalReviewTurn (CommitSha "abc123") (AppServerTurn (TurnId "final-review-rework") "completed" (Just (issueFinalReviewOutput "rework_required" (CommitSha "abc123") reviewerPromptVersion False True True True [] ["issue not solved"] Nothing Nothing))) == Just (IssueFinalReviewRework (reviewEvidenceFromSummaries ("issue not solved" :| []) (CommitSha "abc123")))
    && classifyIssueFinalReviewTurn (CommitSha "abc123") (AppServerTurn (TurnId "final-review-missing-state") "completed" (Just "{\"result\":\"clean\"}")) == Just (IssueFinalReviewIncomplete "final review state missing required fields: completion_status, reviewed_commit_sha, reviewer_prompt_version, issue_solved, plan_implemented, tests_sufficient, rework_required, verification_summary, findings_summary, blocked_reason, lgtm_comment")
    && classifyIssueFinalReviewTurn (CommitSha "abc123") (AppServerTurn (TurnId "final-review-sha-mismatch") "completed" (Just (issueFinalReviewOutput "clean" (CommitSha "def456") reviewerPromptVersion True True True False ["validated issue and plan"] [] Nothing (Just "LGTM")))) == Just (IssueFinalReviewIncomplete "final reviewer inspected def456, expected abc123")

prop_turnClassifierBlocksMissingOutputs :: Bool
prop_turnClassifierBlocksMissingOutputs =
  classifyIssuePlanningTurn (AppServerTurn (TurnId "planning") "completed" Nothing) == Just (ObservedPlanningBlocked (BlockedReason "planning turn completed without output"))
    && classifyIssuePlanTurn (AppServerTurn (TurnId "plan") "completed" Nothing) == Just (ObservedIssueImplementBlocked (BlockedReason "plan turn completed without output"))
    && classifyIssueImplementationTurn (Just (PrNumber 7)) Nothing (AppServerTurn (TurnId "impl") "completed" Nothing) == Just (ObservedImplementationBlocked (BlockedReason "implementation turn completed without output"))
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker") "completed" Nothing) == Just (ObservedWorkerOutcome (WorkerBlocked (BlockedReason "worker turn completed without output")))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer") "completed" (Just "  ")) == Just (ObservedReviewerOutcome (ReviewerBlocked (BlockedReason "reviewer turn completed without output")))
    && classifyIssueFinalReviewTurn (CommitSha "abc123") (AppServerTurn (TurnId "final-reviewer") "completed" (Just "  ")) == Just (IssueFinalReviewBlocked (BlockedReason "final reviewer turn completed without output"))

effectRuntimeConfig :: RepoName -> FilePath -> Int -> EffectRuntimeConfig
effectRuntimeConfig repo workdir requestId =
  EffectRuntimeConfig
    { effectRuntimeRepo = repo
    , effectRuntimeWorkdir = runtimeWorkdir
    , effectRuntimeStateDir = runtimeStateDir
    , effectRuntimeMergeMethod = "merge"
    , effectRuntimeNextRequestId = RequestId requestId
    , effectRuntimePlannerThreadInstructions = "planner developer instructions"
    , effectRuntimePlannerTurn = mkTurnRuntime (RuntimeStateDirCwd runtimeStateDir) "planner prompt" Nothing
    , effectRuntimeWorkerTurn = turnRuntime "worker prompt" Nothing
    , effectRuntimeIssuePlanTurn = turnRuntime "issue plan prompt" Nothing
    , effectRuntimeIssueImplementationTurn = turnRuntime "issue implementation prompt" Nothing
    , effectRuntimeReviewerTurn = turnRuntime "reviewer prompt" Nothing
    }
 where
  runtimeWorkdir = RuntimeWorkdir workdir
  runtimeStateDir = RuntimeStateDir (workdir </> ".watcher")
  mkTurnRuntime cwd input collaborationMode =
    TurnRuntimeConfig
      { turnRuntimeCwd = cwd
      , turnRuntimeModel = defaultModel
      , turnRuntimeEffort = defaultEffort
      , turnRuntimeApprovalPolicy = defaultApprovalPolicy
      , turnRuntimeSandboxPolicy = defaultSandboxPolicy
      , turnRuntimeInput = input
      , turnRuntimeOutputSchema = Nothing
      , turnRuntimeCollaborationMode = collaborationMode
      }
  turnRuntime = mkTurnRuntime (RuntimeWorkdirCwd runtimeWorkdir)

actionIsTurnStartFor :: ThreadId -> PlannedAction -> Bool
actionIsTurnStartFor threadId = \case
  PlannedAppServerRequest request ->
    request.requestMethod == "turn/start"
      && lookupValue "threadId" request.requestParams == Just (String (unThreadId threadId))
  _ -> False

actionIsTurnStartWithInput :: ThreadId -> Text -> PlannedAction -> Bool
actionIsTurnStartWithInput threadId input action =
  actionIsTurnStartFor threadId action
    && case action of
      PlannedAppServerRequest request ->
        lookupValue "input" request.requestParams == Just (toJSON [object ["type" .= ("text" :: Text), "text" .= input]])
      _ -> False

actionTurnInputText :: PlannedAction -> Maybe Text
actionTurnInputText = \case
  PlannedAppServerRequest request -> do
    Array items <- lookupValue "input" request.requestParams
    Object firstItem <- case Foldable.toList items of
      first : _ -> Just first
      [] -> Nothing
    case KeyMap.lookup "text" firstItem of
      Just (String text) -> Just text
      _ -> Nothing
  _ -> Nothing

actionTurnOutputSchema :: PlannedAction -> Maybe Value
actionTurnOutputSchema = \case
  PlannedAppServerRequest request ->
    case lookupValue "outputSchema" request.requestParams of
      Just Null -> Nothing
      other -> other
  _ ->
    Nothing

actionTurnCollaborationMode :: PlannedAction -> Maybe Value
actionTurnCollaborationMode = \case
  PlannedAppServerRequest request ->
    lookupValue "collaborationMode" request.requestParams
  _ ->
    Nothing

actionThreadCwd :: PlannedAction -> Maybe Text
actionThreadCwd = \case
  PlannedAppServerRequest request ->
    case lookupValue "cwd" request.requestParams of
      Just (String cwd) -> Just cwd
      _ -> Nothing
  _ ->
    Nothing

prop_effectInterpreterIssuePlanCompletionRecordsPlan :: IssueConfig -> PrNumber -> ActiveTurn -> ActiveTurn -> Bool
prop_effectInterpreterIssuePlanCompletionRecordsPlan config prNumber planningTurn implementationTurn =
  case step (IssueInPlanMode config prNumber (WorkerActive planningTurn)) (IssuePlanCompleted sampleIssuePlanMarkdown (Just implementationTurn)) of
    Decision _state effects ->
      let compiled =
            compileEffectPlan
              (effectRuntimeConfig (issueRepo config) "/tmp/work" 10)
              effects
          actions = compiled.compiledActions
       in actions
            == [ PlannedWriteText "/tmp/work/.watcher/issue-plan.md" (sampleIssuePlanFile config prNumber)
               , PlannedSleepUntilNextPoll
               ]
            && compiled.compiledNextRequestId == RequestId 10

prop_effectInterpreterPrBodyUpdateUsesIssuePlan :: IssueConfig -> PrNumber -> Bool
prop_effectInterpreterPrBodyUpdateUsesIssuePlan issueConfig prNumber =
  let config = effectRuntimeConfig issueConfig.issueRepo "/tmp/work" 11
      compiled = compileEffectPlan config [SomeEffect (UpdatePullRequestBody issueConfig prNumber)]
   in compiled.compiledActions == [PlannedCommand (GhUpdatePullRequestBody "/tmp/work" issueConfig prNumber "/tmp/work/.watcher/issue-plan.md")]
        && compiled.compiledNextRequestId == RequestId 11

prop_effectInterpreterIssueTurnsUsePhaseSpecificPrompts :: ThreadId -> Bool
prop_effectInterpreterIssueTurnsUsePhaseSpecificPrompts threadId =
  let issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 26) (BranchName "codex/issue-26")
      prNumber = PrNumber 29
      reviewEvidence = reviewEvidenceFromSummaries ("review feedback" :| []) (CommitSha "abc123")
      compiled =
        compileEffectPlan
          (effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 16)
          [ SomeEffect (StartIssuePlanWorkerTurn issueConfig prNumber threadId)
          , SomeEffect (StartIssueImplementationWorkerTurn threadId)
          , SomeEffect (StartWorkerTurn reviewEvidence threadId)
          ]
      actions = compiled.compiledActions
   in length actions == 3
        && actionIsTurnStartFor threadId (actions !! 0)
        && maybe
          False
          ( \input ->
              promptContainsAll
                input
                [ "dedicated English-only issue planner"
                , "#26"
                , "Existing PR: #29"
                , "/tmp/work/.watcher/issue-plan.md"
                , "issue plan prompt"
                ]
          )
          (actionTurnInputText (actions !! 0))
        && actionTurnCollaborationMode (actions !! 0) == Nothing
        && actionIsTurnStartWithInput threadId "issue implementation prompt" (actions !! 1)
        && maybe
          False
          ( \input ->
              promptContainsAll
                input
                [ "worker prompt"
                , "Watcher-provided review feedback to address in this turn"
                , "review feedback"
                ]
          )
          (actionTurnInputText (actions !! 2))
            && compiled.compiledNextRequestId == RequestId 19

prop_defaultEffectRuntimeConfigUsesStructuredOutputSchemas :: Bool
prop_defaultEffectRuntimeConfigUsesStructuredOutputSchemas =
  let repo = RepoName "soulomoon/mlf2"
      issueConfig = IssueConfig repo (IssueNumber 26) (BranchName "codex/issue-26")
      prConfig = PrConfig repo (PrNumber 29) (BranchName "codex/issue-26")
      issuePrNumber = PrNumber 29
      plannerThread = ThreadId "planner"
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      reviewEvidence = reviewEvidenceFromSummaries ("review feedback" :| []) (CommitSha "abc123")
      compiled =
        compileEffectPlan
          (defaultEffectRuntimeConfig repo "/tmp/work" "/tmp/state")
          [ SomeEffect (StartPlannerTurn plannerThread)
          , SomeEffect (StartIssuePlanWorkerTurn issueConfig issuePrNumber workerThread)
          , SomeEffect (StartIssueImplementationWorkerTurn workerThread)
          , SomeEffect (StartWorkerTurn reviewEvidence workerThread)
          , SomeEffect (StartReviewerTurn prConfig (CommitSha "abc123") reviewerThread)
          , SomeEffect (StartIssueFinalReviewTurn issueConfig issuePrNumber (CommitSha "abc123") reviewerThread)
          ]
      actions = compiled.compiledActions
   in length actions == 6
        && map actionTurnOutputSchema actions
          == [ Just plannerTurnOutputSchema
             , Just issuePlanTurnOutputSchema
             , Just issueImplementationTurnOutputSchema
             , Just prReviewWorkerTurnOutputSchema
             , Just reviewerTurnOutputSchema
             , Just issueFinalReviewTurnOutputSchema
             ]
        && maybe
          False
          ( \input ->
              promptContainsAll
                input
                [ "Read the current issue snapshot and return the issue-planning decision JSON for the current scope."
                , "Inspect existing GitHub issues and sub-issues when needed before deciding."
                , "Return only JSON matching the active output schema. Plain prose completion is not accepted."
                , "Include every schema field, using empty arrays, empty strings, or null parentIssueNumber when a field is not applicable."
                ]
          )
          (actionTurnInputText (actions !! 0))
        && fmap actionThreadCwd actions
          == [ Just "/tmp/state"
             , Just "/tmp/work"
             , Just "/tmp/work"
             , Just "/tmp/work"
             , Just "/tmp/work"
             , Just "/tmp/work"
             ]
        && maybe
          False
          ( \input ->
              promptContainsAll
                input
                [ "Read the PR body and linked issue"
                , "Treat the PR body implementation plan as part of the review target"
                , "Verify that the current head actually satisfies the PR plan and the linked issue acceptance criteria"
                , "Do not report clean solely because the PR diff is empty"
                ]
          )
          (actionTurnInputText (actions !! 4))
        && maybe
          False
          ( \input ->
              promptContainsAll
                input
                [ "Final-review the merged implementation for issue #26 and PR #29"
                , "Decide whether the implementation truly solved the issue and whether the PR plan was actually implemented"
                , "Do not treat an empty PR diff against the base branch as clean by itself"
                , "completion_status=rework_required"
                ]
          )
          (actionTurnInputText (actions !! 5))
        && all (== Nothing) (map actionTurnCollaborationMode actions)

prop_turnOutputSchemasRequireStructuredDetails :: Bool
prop_turnOutputSchemasRequireStructuredDetails =
  all
    schemaRequiresOutcomeReasonSummary
    [ plannerTurnOutputSchema
    , issuePlanTurnOutputSchema
    , issueImplementationTurnOutputSchema
    , prReviewWorkerTurnOutputSchema
    ]
    && all
      schemaRequiresEveryObjectProperty
      [ plannerTurnOutputSchema
      , issuePlanTurnOutputSchema
      , issueImplementationTurnOutputSchema
      , prReviewWorkerTurnOutputSchema
      , reviewerTurnOutputSchema
      , issueFinalReviewTurnOutputSchema
      ]
    && schemaRequiredFields plannerTurnOutputSchema
      == [ "outcome"
         , "reason"
         , "summary"
         , "issues_to_create"
         , "subissues_to_create"
         , "ready_issues"
         , "blocked_issues"
         , "dependencies"
         ]
    && "plan_markdown" `elem` schemaRequiredFields issuePlanTurnOutputSchema
    && schemaRequiredFields reviewerTurnOutputSchema
      == [ "reviewed_commit_sha"
         , "reviewer_prompt_version"
         , "added_review_comment_count"
         , "prior_findings_status"
         , "new_findings_status"
         , "lgtm_comment"
         , "prior_findings_summary"
         , "new_findings_summary"
         , "blocked_reason"
         , "solved_threads"
         , "remaining_review_threads"
         ]
    && schemaRequiredFields issueFinalReviewTurnOutputSchema
      == [ "completion_status"
         , "reviewed_commit_sha"
         , "reviewer_prompt_version"
         , "issue_solved"
         , "plan_implemented"
         , "tests_sufficient"
         , "rework_required"
         , "verification_summary"
         , "findings_summary"
         , "blocked_reason"
         , "lgtm_comment"
         ]

schemaRequiresOutcomeReasonSummary :: Value -> Bool
schemaRequiresOutcomeReasonSummary schema =
  let requiredFields = schemaRequiredFields schema
   in all (`elem` requiredFields) ["outcome", "reason", "summary"]

schemaRequiresEveryObjectProperty :: Value -> Bool
schemaRequiresEveryObjectProperty schema@(Object objectValue)
  | KeyMap.lookup (Key.fromString "type") objectValue == Just (String "object") =
      case KeyMap.lookup (Key.fromString "properties") objectValue of
        Just (Object properties) ->
          let requiredFields = schemaRequiredFields schema
              propertyKeys = fmap Key.toText (KeyMap.keys properties)
           in all (`elem` requiredFields) propertyKeys
                && all schemaRequiresEveryObjectProperty (KeyMap.elems properties)
        _ ->
          False
  | KeyMap.lookup (Key.fromString "type") objectValue == Just (String "array") =
      maybe True schemaRequiresEveryObjectProperty (KeyMap.lookup (Key.fromString "items") objectValue)
  | otherwise =
      True
schemaRequiresEveryObjectProperty _ =
  True

schemaRequiredFields :: Value -> [Text]
schemaRequiredFields (Object objectValue)
  | Just (Array fields) <- KeyMap.lookup (Key.fromString "required") objectValue =
      [field | String field <- Foldable.toList fields]
schemaRequiredFields _ =
  []

prop_threadDeveloperPromptTemplatesPortNodeProtocols :: Bool
prop_threadDeveloperPromptTemplatesPortNodeProtocols =
  let prConfig = PrConfig (RepoName "soulomoon/mlf2") (PrNumber 29) (BranchName "codex/issue-26")
      issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 26) (BranchName "codex/issue-26")
      workerPrompt = prReviewThreadDeveloperInstructions "/tmp/work" "/tmp/state/pr29" prConfig "worker"
      reviewerPrompt = prReviewThreadDeveloperInstructions "/tmp/work" "/tmp/state/pr29" prConfig "reviewer"
      issuePrompt = issueImplementerThreadDeveloperInstructions "/tmp/work" "/tmp/state/issue26" issueConfig
      plannerPrompt = issuePlanningThreadDeveloperInstructions "/tmp/state/planner" (RepoName "soulomoon/mlf2") [IssueNumber 12]
      plannerTurnPrompt = plannerTurnInputForScope [IssueNumber 12]
      planModePrompt = issuePlanModeDeveloperInstructions "/tmp/work" "/tmp/state/issue26" issueConfig (PrNumber 31)
   in promptContainsAll
        workerPrompt
        [ "Publishing protocol, required for this environment:"
        , "gh auth setup-git"
        , "Return final status only through the active structured turn output."
        , "Do not write watcher state files"
        , "Stage only files related to the current issue/PR"
        , "never stage watcher state or runtime files"
        , "If unrelated dirty changes make safe staging unclear"
        ]
        && promptContainsAll
          reviewerPrompt
          [ "dedicated English-only PR reviewer"
          , "add inline GitHub PR review comments"
          , "PR body/implementation plan, linked issue"
          , "Empty PR diffs are not automatically clean"
          , "Do not edit files, commit, push, resolve review threads, or submit an approval review"
          ]
        && promptContainsAll
          issuePrompt
          [ "dedicated English-only issue implementer"
          , "There is no triage turn"
          , "plan_markdown"
          , "/tmp/state/issue26/issue-plan.md"
          , "gh auth setup-git"
          , "PR review watcher handles review threads after handoff"
          , "The watcher owns /tmp/state/issue26/issue-state.json"
          , "structured turn output"
          , "Ignore repository-local legacy orchestrator prompts"
          , "Do not write `issue_status: \"complete\"`"
          , "reserves terminal state for after the GitHub issue is closed"
          , "watcher verifies PR merge before final terminal success"
          , "stage only files related to this issue"
          ]
        && promptContainsAll
          plannerPrompt
          [ "dedicated English-only issue planning coordinator"
          , "Return structured JSON outcomes only when asked by the watcher turn."
          , "Treat existing issue implementer watchers as already owned work"
          , "concrete body with scope, acceptance criteria"
          , "Ignore repository-local legacy orchestrator prompts"
          , "12"
          ]
        && promptContainsAll
          plannerTurnPrompt
          [ "Read the current issue snapshot and return the issue-planning decision JSON for the current scope."
          , "Inspect existing GitHub issues and sub-issues when needed before deciding."
          , "Return only JSON matching the active output schema"
          , "Include every schema field, using empty arrays, empty strings, or null parentIssueNumber when a field is not applicable."
          , "dependencies is the authoritative planning graph input"
          , "dependencies must use {\"issueNumber\": 27, \"dependsOn\": [26]}"
          , "ready_issues and blocked_issues are optional hints only; they are not authoritative."
          , "Target scope:"
          , "12"
          ]
        && promptContainsAll
          planModePrompt
          [ "dedicated English-only issue planner"
          , "Existing PR: #31"
          , "https://github.com/soulomoon/mlf2/pull/31"
          , "Do not edit implementation files"
          , "/tmp/state/issue26/issue-state.json"
          , "Do not write /tmp/state/issue26/issue-state.json"
          , "Ignore repository-local legacy orchestrator prompts"
          , "canonical front matter for issue 26, PR 31, and branch codex/issue-26"
          , "planning-only ordinary Codex turn"
          , "plan_markdown"
          ]
        && all
          promptHasAgentPrincipleFrame
          [ workerPrompt
          , reviewerPrompt
          , issuePrompt
          , planModePrompt
          , issuePlanTurnInput
          , issueImplementationTurnInput
          , prReviewWorkerTurnInput
          ]
        && "{{" `Text.isInfixOf` workerPrompt == False
        && "{{" `Text.isInfixOf` reviewerPrompt == False
        && "{{" `Text.isInfixOf` issuePrompt == False
        && "{{" `Text.isInfixOf` plannerPrompt == False
        && "{{" `Text.isInfixOf` planModePrompt == False

prop_structuredTurnOutcomeInstructionsFollowAgentPrinciple :: Bool
prop_structuredTurnOutcomeInstructionsFollowAgentPrinciple =
  promptContainsAll
    structuredTurnOutcomeInstructions
    [ "Return only JSON matching the active output schema"
    , "Every schema includes outcome, reason, and summary"
    , "include every schema field, using empty strings or arrays when a field is not applicable"
    , "Plain prose completion is not accepted"
    , "outcome=blocked with a non-empty reason"
    , "outcome=incomplete with a non-empty reason"
    , "outcome=complete with a non-empty summary"
    ]
    && reviewerPromptVersion == "haskell-pro-style-v10-split-review-findings"

prop_promptPipelineAlignmentContracts :: Bool
prop_promptPipelineAlignmentContracts =
  let plannerPrompt = plannerTurnInputForScope []
   in promptContainsAll
        plannerPrompt
        [ "Read the current issue snapshot"
        , "return the issue-planning decision JSON"
        , "Inspect existing GitHub issues and sub-issues when needed"
        ]
        && promptContainsNone
          plannerPrompt
          [ "For fanout decisions, return one JSON object with outcome=complete, reason, summary, and dependencies"
          , "Minimal {\"outcome\":\"complete\",\"reason\":\"\",\"summary\":\"all scoped work finished\"}"
          ]
        && promptContainsAll
          issueImplementationTurnInput
          [ "Never mutate watcher events.jsonl"
          , "pid/lock/runtime-owner files"
          , "Do not write watcher state files"
          , "structured turn output"
          , "optional evidence field for validation and publish details"
          ]
        && promptContainsAll
          prReviewWorkerTurnInput
          [ "Never mutate watcher events.jsonl"
          , "pid/lock/runtime-owner files"
          , "Do not write watcher state files"
          , "optional evidence field for validation, publish, and review-thread check details"
          ]

prop_effectInterpreterIssuePlanTurnUsesIssuePlanModeDeveloperInstructions :: Bool
prop_effectInterpreterIssuePlanTurnUsesIssuePlanModeDeveloperInstructions =
  let issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 26) (BranchName "codex/issue-26")
      threadId = ThreadId "issue-worker-26"
      compiled =
        compileEffectPlan
          (effectRuntimeConfig issueConfig.issueRepo "/tmp/work" 40)
          [SomeEffect (StartIssuePlanWorkerTurn issueConfig (PrNumber 31) threadId)]
   in case compiled.compiledActions of
        [action@(PlannedAppServerRequest request)] ->
          lookupValue "threadId" request.requestParams == Just (String (unThreadId threadId))
            && maybe
              False
              ( \input ->
                  promptContainsAll
                    input
                    [ "dedicated English-only issue planner"
                    , "#26"
                    , "Existing PR: #31"
                    , "https://github.com/soulomoon/mlf2/pull/31"
                    , "/tmp/work"
                    , "/tmp/work/.watcher/issue-plan.md"
                    , "issue plan prompt"
                    ]
              )
              (actionTurnInputText action)
            && lookupValue "collaborationMode" request.requestParams == Nothing
            && compiled.compiledNextRequestId == RequestId 41
        _ -> False

promptContainsAll :: Text -> [Text] -> Bool
promptContainsAll prompt =
  all (`Text.isInfixOf` prompt)

promptContainsNone :: Text -> [Text] -> Bool
promptContainsNone prompt =
  all (not . (`Text.isInfixOf` prompt))

promptHasAgentPrincipleFrame :: Text -> Bool
promptHasAgentPrincipleFrame prompt =
  promptContainsAll
    prompt
    [ "Role:"
    , "Mission:"
    , "Operating principles:"
    , "Tool and workflow rules:"
    , "Hard constraints:"
    , "Output contract:"
    , "Prioritize correctness, safety, usefulness, efficiency, and clarity."
    , "do not invent facts, file contents, tool results, or user preferences."
    , "prefer fundamental root-cause changes over superficial patches, validate, then report."
    ]

prop_effectInterpreterTwoTurnStartsUseMonotonicRequestIds :: ThreadId -> ThreadId -> Bool
prop_effectInterpreterTwoTurnStartsUseMonotonicRequestIds workerThread reviewerThread =
  let reviewEvidence = reviewEvidenceFromSummaries ("review feedback" :| []) (CommitSha "abc123")
      compiled =
        compileEffectPlan
          (effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 20)
          [ SomeEffect (StartWorkerTurn reviewEvidence workerThread)
          , SomeEffect (StartReviewerTurn (PrConfig (RepoName "soulomoon/mlf2") (PrNumber 7) (BranchName "codex/issue-7")) (CommitSha "abc123") reviewerThread)
          ]
   in fmap appServerRequestId compiled.compiledActions == [Just 20, Just 21]
        && compiled.compiledNextRequestId == RequestId 22

prop_effectInterpreterRecordBlockedWritesBlockState :: BlockedReason -> Bool
prop_effectInterpreterRecordBlockedWritesBlockState reason =
  let config = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 30
      compiled = compileEffectPlan config [SomeEffect (RecordBlocked reason)]
      expectedPath = runtimeStateDirFile config.effectRuntimeStateDir "block-state.json"
      expectedJson = object ["blocked" .= True, "reason" .= unBlockedReason reason]
   in compiled.compiledActions == [PlannedWriteJson expectedPath expectedJson]
        && compiled.compiledNextRequestId == RequestId 30

prop_effectInterpreterRecordPlanningGraphWritesState :: PlanningGraph -> Bool
prop_effectInterpreterRecordPlanningGraphWritesState graph =
  let config = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 32
      compiled = compileEffectPlan config [SomeEffect (RecordPlanningGraph graph)]
      expectedPath = runtimeStateDirFile config.effectRuntimeStateDir "planning-state.json"
   in compiled.compiledActions == [PlannedWriteJson expectedPath (toJSON graph)]
        && compiled.compiledNextRequestId == RequestId 32

prop_effectInterpreterCreateIssueUsesConfiguredEffect :: RepoName -> IssueCreationRequest -> Bool
prop_effectInterpreterCreateIssueUsesConfiguredEffect repo request =
  let config = effectRuntimeConfig repo "/tmp/work" 35
      compiled = compileEffectPlan config [SomeEffect (CreateIssue repo request)]
   in compiled.compiledActions == [PlannedCommand (GhIssueCreate repo request)]
        && compiled.compiledNextRequestId == RequestId 35

prop_effectInterpreterMergeUsesConfiguredRepoAndMethod :: PrNumber -> CleanReviewEvidence -> Bool
prop_effectInterpreterMergeUsesConfiguredRepoAndMethod prNumber cleanEvidence =
  let repo = RepoName "soulomoon/mlf2"
      config = (effectRuntimeConfig repo "/tmp/work" 40) {effectRuntimeMergeMethod = "squash"}
      compiled = compileEffectPlan config [SomeEffect (MergePullRequest prNumber cleanEvidence)]
   in compiled.compiledActions == [PlannedCommand (GhPrCleanReviewAndMerge repo prNumber cleanEvidence "squash")]

prop_actionExecutorDryRunPreservesActionOrder :: Bool
prop_actionExecutorDryRunPreservesActionOrder =
  let reviewEvidence = reviewEvidenceFromSummaries ("review feedback" :| []) (CommitSha "abc123")
      compiled =
        compileEffectPlan
          (effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 50)
          [ SomeEffect (PushBranch (BranchName "codex/example"))
          , SomeEffect (StartWorkerTurn reviewEvidence (ThreadId "worker-thread"))
          , SomeEffect (RecordBlocked (BlockedReason "blocked"))
          , SomeEffect SleepUntilNextPoll
          , SomeEffect StopDaemon
          ]
      reports = dryRunCompiledEffectPlan compiled
   in fmap actionExecutionAction reports == compiled.compiledActions
        && all ((== DryRunActions) . actionExecutionMode) reports
        && all ((== DryRunActionResult) . actionExecutionResult) reports

prop_runtimeOwnerJsonAndParsing :: Bool
prop_runtimeOwnerJsonAndParsing =
  parseRuntimeOwner "HASKELL" == Right HaskellRuntime
    && parseRuntimeOwner "node" /= Right HaskellRuntime
    && parseRuntimeOwner "unknown" /= Right HaskellRuntime
    && lookupValue "owner" (runtimeLeaseJson exampleLease) == Nothing
    && lookupValue "runtime" (runtimeLeaseValue exampleLease) == Just (String "haskell")
 where
  exampleTime = UTCTime (fromGregorian 2026 1 1) (secondsToDiffTime 0)
  exampleLease =
    RuntimeLease
      { runtimeLeaseOwner = HaskellRuntime
      , runtimeLeasePid = "1"
      , runtimeLeaseHost = "test-host"
      , runtimeLeaseClaimedAt = exampleTime
      , runtimeLeaseExpiresAt = exampleTime
      , runtimeLeaseEventLogHeadHash = "head"
      }
  runtimeLeaseValue lease =
    case lookupValue "lease" (runtimeLeaseJson lease) of
      Just value -> value
      Nothing -> Null

runtimeOwnerLeaseParsingRejectsOwnerOnlyJson :: IO Bool
runtimeOwnerLeaseParsingRejectsOwnerOnlyJson = do
  let stateDir = "/tmp/moifold-runtime-owner"
      ownerPath = stateDir </> "runtime-owner.json"
  exists <- doesDirectoryExist stateDir
  when exists (removePathForcibly stateDir)
  createDirectoryIfMissing True stateDir
  LazyByteString.writeFile ownerPath (encode (object ["owner" .= ("haskell" :: Text)]))
  ownerOnly <- readRuntimeOwnerMarker stateDir
  now <- getCurrentTime
  let oldLeaseJson =
        object
          [ "owner" .= ("haskell" :: Text)
          , "lease"
              .= object
                [ "pid" .= ("123456" :: Text)
                , "hostname" .= ("test-host" :: Text)
                , "claimedAt" .= now
                , "expiresAt" .= addUTCTime 60 now
                , "eventLogHeadHash" .= ("head" :: Text)
                ]
          ]
  LazyByteString.writeFile ownerPath (encode oldLeaseJson)
  oldLeased <- readRuntimeOwnerMarker stateDir
  let lease =
        RuntimeLease
          { runtimeLeaseOwner = HaskellRuntime
          , runtimeLeasePid = "123456"
          , runtimeLeaseHost = "test-host"
          , runtimeLeaseClaimedAt = now
          , runtimeLeaseExpiresAt = addUTCTime 60 now
          , runtimeLeaseEventLogHeadHash = "head"
          }
  LazyByteString.writeFile ownerPath (encode (runtimeLeaseJson lease))
  leased <- readRuntimeOwnerMarker stateDir
  removePathForcibly stateDir
  results <-
    sequence
      [ assert "runtime owner rejects owner-only JSON" (case ownerOnly of Left _ -> True; _ -> False)
      , assert "runtime owner rejects old top-level owner lease JSON" (case oldLeased of Left _ -> True; _ -> False)
      , assert "runtime owner parses lease-only marker" (case leased of Right (Just (RuntimeOwnerLeased parsed)) -> parsed.runtimeLeasePid == "123456" && parsed.runtimeLeaseEventLogHeadHash == "head"; _ -> False)
      ]
  pure (and results)

runtimeOwnerClearRejectsRunningLease :: IO Bool
runtimeOwnerClearRejectsRunningLease = do
  let stateDir = "/tmp/moifold-runtime-owner-clear"
      ownerPath = stateDir </> "runtime-owner.json"
  exists <- doesDirectoryExist stateDir
  when exists (removePathForcibly stateDir)
  createDirectoryIfMissing True stateDir
  now <- getCurrentTime
  currentPid <- Text.pack . show <$> getProcessID
  let lease =
        RuntimeLease
          { runtimeLeaseOwner = HaskellRuntime
          , runtimeLeasePid = currentPid
          , runtimeLeaseHost = "test-host"
          , runtimeLeaseClaimedAt = now
          , runtimeLeaseExpiresAt = addUTCTime 60 now
          , runtimeLeaseEventLogHeadHash = "head"
          }
  LazyByteString.writeFile ownerPath (encode (runtimeLeaseJson lease))
  clearResult <- try (clearRuntimeLease stateDir) :: IO (Either ExitCode ())
  removePathForcibly stateDir
  results <-
    sequence
      [ assert "runtime owner clear rejects running lease" (case clearResult of Left (ExitFailure _) -> True; _ -> False)
      ]
  pure (and results)

runtimeOwnerCleanupClearsOnlyCurrentProcessLease :: IO Bool
runtimeOwnerCleanupClearsOnlyCurrentProcessLease = do
  let stateDir = "/tmp/moifold-runtime-owner-cleanup"
      ownerPath = stateDir </> "runtime-owner.json"
  exists <- doesDirectoryExist stateDir
  when exists (removePathForcibly stateDir)
  createDirectoryIfMissing True stateDir
  now <- getCurrentTime
  currentPid <- Text.pack . show <$> getProcessID
  let currentLease =
        RuntimeLease
          { runtimeLeaseOwner = HaskellRuntime
          , runtimeLeasePid = currentPid
          , runtimeLeaseHost = "test-host"
          , runtimeLeaseClaimedAt = now
          , runtimeLeaseExpiresAt = addUTCTime 60 now
          , runtimeLeaseEventLogHeadHash = "head"
          }
      otherLease = currentLease {runtimeLeasePid = "999999999"}
  LazyByteString.writeFile ownerPath (encode (runtimeLeaseJson currentLease))
  clearRuntimeLeaseIfOwnedByCurrentProcess stateDir ExecuteActions
  currentCleared <- not <$> doesFileExist ownerPath
  LazyByteString.writeFile ownerPath (encode (runtimeLeaseJson otherLease))
  clearRuntimeLeaseIfOwnedByCurrentProcess stateDir ExecuteActions
  otherPreserved <- doesFileExist ownerPath
  clearRuntimeLeaseIfOwnedByCurrentProcess stateDir DryRunActions
  dryRunPreserved <- doesFileExist ownerPath
  removePathForcibly stateDir
  results <-
    sequence
      [ assert "runtime owner cleanup clears current process lease" currentCleared
      , assert "runtime owner cleanup preserves other process lease" otherPreserved
      , assert "runtime owner cleanup is a no-op in dry-run" dryRunPreserved
      ]
  pure (and results)

restoreOwnedPidFileRepairsMissingAndStalePid :: IO Bool
restoreOwnedPidFileRepairsMissingAndStalePid = do
  let stateDir = "/tmp/moifold-pid-restore"
      pidPath = stateDir </> "watcher.pid"
  exists <- doesDirectoryExist stateDir
  when exists (removePathForcibly stateDir)
  createDirectoryIfMissing True stateDir
  currentPid <- Text.pack . show <$> getProcessID
  restoreOwnedPidFile pidPath currentPid
  restoredMissing <- readPidFile pidPath
  writeFile pidPath "999999999\n"
  restoreOwnedPidFile pidPath currentPid
  restoredStale <- readPidFile pidPath
  removePathForcibly stateDir
  results <-
    sequence
      [ assert "restoreOwnedPidFile writes missing pid file" (restoredMissing == Just currentPid)
      , assert "restoreOwnedPidFile replaces stale non-running pid file" (restoredStale == Just currentPid)
      ]
  pure (and results)

prop_supervisorRendersRestartAndLogrotate :: Bool
prop_supervisorRendersRestartAndLogrotate =
  let config =
        WatcherServiceConfig
          { serviceName = "watcher-one"
          , serviceDescription = "Codex watcher one"
          , serviceExecutable = "/tmp/codex watcher"
          , serviceArguments = ["run-pr-review", "--loop", "--execute"]
          , serviceWorkingDirectory = "/tmp/work"
          , serviceLogDirectory = "/tmp/logs"
          , serviceRestartSeconds = 5
          , serviceLogRotateCount = 7
          }
      service = renderSystemdService config
      logrotate = renderLogrotateConfig config
   in "Restart=always" `Text.isInfixOf` service
        && "RestartSec=5" `Text.isInfixOf` service
        && "StandardOutput=append:/tmp/logs/watcher-one.log" `Text.isInfixOf` service
        && "\"/tmp/codex watcher\"" `Text.isInfixOf` service
        && "rotate 7" `Text.isInfixOf` logrotate

runnerGuardIgnoresMissingPidForCompletePlanning :: IO Bool
runnerGuardIgnoresMissingPidForCompletePlanning = do
  let stateDir = "/tmp/moifold-runner-guard-complete"
      eventsPath = stateDir </> "events.jsonl"
      pidPath = stateDir </> "watcher.pid"
      events =
        [ IssuePlanningInitialized (PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) [])
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn")
        , IssuePlanningTurnCompleted
        ]
      config :: RunnerGuardConfig 'IssuePlanning
      config =
        RunnerGuardConfig
          { guardRepo = RepoName "owner/name"
          , guardEventsPath = eventsPath
          , guardStateDir = stateDir
          , guardWatcherPidFile = pidPath
          , guardAppServerEndpoint = AppServerEndpoint "127.0.0.1" 9 "/"
          , guardStaleSeconds = staleSecondsForTest 1
          , guardRepairCwd = stateDir
          , guardRestartWatcherCommand = ""
          , guardRestartGuardCommand = ""
          }
  exists <- doesDirectoryExist stateDir
  when exists (removePathForcibly stateDir)
  createDirectoryIfMissing True stateDir
  writeFile eventsPath (unlines (fmap (Text.unpack . Text.Encoding.decodeUtf8 . LazyByteString.toStrict . encode) events))
  guardProblem <- checkRunnerGuard config
  removePathForcibly stateDir
  assert "runner guard ignores missing pid after planning complete" (guardProblem == Nothing)

runnerGuardRestartsMissingPidForIncompletePlanning :: IO Bool
runnerGuardRestartsMissingPidForIncompletePlanning = do
  let stateDir = "/tmp/moifold-runner-guard-restart"
      eventsPath = stateDir </> "events.jsonl"
      pidPath = stateDir </> "watcher.pid"
      events = [IssuePlanningInitialized (PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) [])]
      config :: RunnerGuardConfig 'IssuePlanning
      config =
        RunnerGuardConfig
          { guardRepo = RepoName "owner/name"
          , guardEventsPath = eventsPath
          , guardStateDir = stateDir
          , guardWatcherPidFile = pidPath
          , guardAppServerEndpoint = AppServerEndpoint "127.0.0.1" 9 "/"
          , guardStaleSeconds = staleSecondsForTest 999999
          , guardRepairCwd = stateDir
          , guardRestartWatcherCommand = "restart watcher"
          , guardRestartGuardCommand = "restart guard"
          }
  exists <- doesDirectoryExist stateDir
  when exists (removePathForcibly stateDir)
  createDirectoryIfMissing True stateDir
  writeFile eventsPath (unlines (fmap (Text.unpack . Text.Encoding.decodeUtf8 . LazyByteString.toStrict . encode) events))
  guardProblem <- checkRunnerGuard config
  removePathForcibly stateDir
  assert "runner guard asks to restart watcher when pid is missing and planning is incomplete" $
    case guardProblem of
      Just problem' -> runnerGuardProblemAction problem' == RestartWatcher
      Nothing -> False

runnerGuardRestartsMissingPidForWaitingPlanning :: IO Bool
runnerGuardRestartsMissingPidForWaitingPlanning = do
  let stateDir = "/tmp/moifold-runner-guard-waiting"
      eventsPath = stateDir </> "events.jsonl"
      pidPath = stateDir </> "watcher.pid"
      events =
        [ IssuePlanningInitialized (PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) [])
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn")
        , IssuePlanningGraphUpdated (PlanningGraph [IssueNumber 42] [] [])
        ]
      config :: RunnerGuardConfig 'IssuePlanning
      config =
        RunnerGuardConfig
          { guardRepo = RepoName "owner/name"
          , guardEventsPath = eventsPath
          , guardStateDir = stateDir
          , guardWatcherPidFile = pidPath
          , guardAppServerEndpoint = AppServerEndpoint "127.0.0.1" 9 "/"
          , guardStaleSeconds = staleSecondsForTest 999999
          , guardRepairCwd = stateDir
          , guardRestartWatcherCommand = "restart watcher"
          , guardRestartGuardCommand = "restart guard"
          }
  exists <- doesDirectoryExist stateDir
  when exists (removePathForcibly stateDir)
  createDirectoryIfMissing True stateDir
  writeFile eventsPath (unlines (fmap (Text.unpack . Text.Encoding.decodeUtf8 . LazyByteString.toStrict . encode) events))
  guardProblem <- checkRunnerGuard config
  removePathForcibly stateDir
  assert "runner guard restarts missing pid while planning waits for ready issues" $
    case guardProblem of
      Just problem' -> runnerGuardProblemAction problem' == RestartWatcher
      Nothing -> False

runnerGuardRepairsInvalidPlanningEventLog :: IO Bool
runnerGuardRepairsInvalidPlanningEventLog = do
  let stateDir = "/tmp/moifold-runner-guard-repair"
      eventsPath = stateDir </> "events.jsonl"
      pidPath = stateDir </> "watcher.pid"
      events =
        [ IssuePlanningInitialized (PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) [])
        , IssuePlanningTurnCompleted
        ]
      config :: RunnerGuardConfig 'IssuePlanning
      config =
        RunnerGuardConfig
          { guardRepo = RepoName "owner/name"
          , guardEventsPath = eventsPath
          , guardStateDir = stateDir
          , guardWatcherPidFile = pidPath
          , guardAppServerEndpoint = AppServerEndpoint "127.0.0.1" 9 "/"
          , guardStaleSeconds = staleSecondsForTest 999999
          , guardRepairCwd = stateDir
          , guardRestartWatcherCommand = "restart watcher"
          , guardRestartGuardCommand = "restart guard"
          }
  exists <- doesDirectoryExist stateDir
  when exists (removePathForcibly stateDir)
  createDirectoryIfMissing True stateDir
  writeFile pidPath "1\n"
  writeFile eventsPath (unlines (fmap (Text.unpack . Text.Encoding.decodeUtf8 . LazyByteString.toStrict . encode) events))
  guardProblem <- checkRunnerGuard config
  removePathForcibly stateDir
  assert "runner guard asks repair thread for invalid event logs" $
    case guardProblem of
      Just problem' -> runnerGuardProblemAction problem' == LaunchRepairThread
      Nothing -> False

runtimeStatusHelperCoversCommonCases :: IO Bool
runtimeStatusHelperCoversCommonCases = do
  let stateDir = "/tmp/moifold-runtime-status"
      configPath = stateDir </> "config.json"
      eventsPath = stateDir </> "events.jsonl"
      pidPath = stateDir </> "watcher.pid"
      plannerConfig = PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) []
      stoppedEvents =
        [ IssuePlanningInitialized plannerConfig
        , WatcherStopped (StopReason "done")
        ]
      blockedEvents =
        [ IssuePlanningInitialized plannerConfig
        , WatcherBlocked (BlockedReason "blocked")
        ]
      completeEvents =
        [ IssuePlanningInitialized plannerConfig
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn")
        , IssuePlanningTurnCompleted
        ]
      status missingIsTerminal terminalIsTerminal =
        let statusConfig :: WatcherRuntimeStatusConfig 'IssuePlanning
            statusConfig =
              WatcherRuntimeStatusConfig
                { watcherRuntimeConfigPath = configPath
                , watcherRuntimeEventsPath = eventsPath
                , watcherRuntimePidPath = pidPath
                , watcherRuntimeMissingIsTerminal = pure missingIsTerminal
                , watcherRuntimeReplayTerminalIsTerminal = \replay ->
                    pure $
                      terminalIsTerminal
                        && isTerminalState replay.replayState
                }
         in watcherRuntimeStatus statusConfig
  exists <- doesDirectoryExist stateDir
  when exists (removePathForcibly stateDir)
  missing <- status False True
  createDirectoryIfMissing True stateDir
  writeFile configPath "{}"
  activeStopped <- status False True
  pid <- getProcessID
  writeFile pidPath (show pid <> "\n")
  activeRunning <- status False True
  writeFile eventsPath "not-json\n"
  invalidRunning <- status False True
  LazyByteString.writeFile eventsPath (mconcat (fmap (\event -> encode event <> "\n") stoppedEvents))
  terminal <- status False True
  LazyByteString.writeFile eventsPath (mconcat (fmap (\event -> encode event <> "\n") blockedEvents))
  terminalBlocked <- status False True
  LazyByteString.writeFile eventsPath (mconcat (fmap (\event -> encode event <> "\n") completeEvents))
  terminalComplete <- status False True
  terminalPolicyFalse <- status False False
  removePathForcibly stateDir
  results <-
    sequence
      [ assert "runtime status reports missing watcher" (missing == WatcherMissing)
      , assert "runtime status reports stopped without event log" (activeStopped == WatcherActiveStopped)
      , assert "runtime status reports running without event log" (activeRunning == WatcherActiveRunning)
      , assert "runtime status treats invalid event log as active when pid runs" (invalidRunning == WatcherActiveRunning)
      , assert "runtime status reports terminal replay" (terminal == WatcherTerminal (TerminalStopped "done"))
      , assert "runtime status reports blocked terminal reason" (terminalBlocked == WatcherTerminal (TerminalBlocked "blocked"))
      , assert "runtime status reports complete terminal" (terminalComplete == WatcherTerminal TerminalComplete)
      , assert "only complete runtime status maps ready issue terminal" (readyIssueStatusFromRuntime terminalBlocked == ReadyIssueActiveStopped && readyIssueStatusFromRuntime terminalComplete == ReadyIssueTerminal)
      , assert "runtime status keeps rejected terminal replay active while pid runs" (terminalPolicyFalse == WatcherActiveRunning)
      ]
  pure (and results)

runtimeStatusIssueImplementTerminalRequiresIssueCloseVerifier :: IO Bool
runtimeStatusIssueImplementTerminalRequiresIssueCloseVerifier = do
  let stateDir = "/tmp/moifold-runtime-status-issue-implement"
      configPath = stateDir </> "config.json"
      eventsPath = stateDir </> "events.jsonl"
      pidPath = stateDir </> "issue-watcher.pid"
      issueConfig = IssueConfig (RepoName "owner/name") (IssueNumber 42) (BranchName "codex/issue-42")
      prNumber' = PrNumber 7
      completeEvents =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssuePullRequestCreatedEvent prNumber'
        , IssuePlanTurnStartedEvent (TurnId "plan-turn")
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        , IssuePullRequestBodyUpdatedEvent prNumber'
        , IssueImplementationTurnStartedEvent (TurnId "implementation-turn")
        , IssueImplementationCompletedEvent prNumber' Nothing
        , IssueReviewHandoffInitializedEvent prNumber'
        , IssueReviewHandoffStartedEvent prNumber'
        , IssuePullRequestMergedEvent prNumber'
        , IssueReviewerThreadReadyEvent (ThreadId "reviewer-thread")
        , IssuePostMergeReviewStartedEvent (CommitSha "0123456789abcdef") (TurnId "review-turn")
        , IssuePostMergeReviewCleanEvent (CleanReviewEvidence (CommitSha "0123456789abcdef") "LGTM")
        , IssueClosedEvent prNumber'
        ]
      status missingIsTerminal terminalIsTerminal =
        let statusConfig :: WatcherRuntimeStatusConfig 'IssueImplement
            statusConfig =
              WatcherRuntimeStatusConfig
                { watcherRuntimeConfigPath = configPath
                , watcherRuntimeEventsPath = eventsPath
                , watcherRuntimePidPath = pidPath
                , watcherRuntimeMissingIsTerminal = pure missingIsTerminal
                , watcherRuntimeReplayTerminalIsTerminal = \_replay -> pure terminalIsTerminal
                }
         in watcherRuntimeStatus statusConfig
  exists <- doesDirectoryExist stateDir
  when exists (removePathForcibly stateDir)
  missing <- status False True
  missingClosed <- status True True
  createDirectoryIfMissing True stateDir
  writeFile configPath "{}"
  LazyByteString.writeFile eventsPath (mconcat (fmap (\event -> encode event <> "\n") completeEvents))
  completeRejected <- status False False
  completeAccepted <- status False True
  removePathForcibly stateDir
  sequenceAnd
    [ assert "missing issue implementer remains missing before remote issue-close verifier succeeds" $
        missing == WatcherMissing
    , assert "missing issue implementer is terminal only when remote issue-close verifier succeeds" $
        missingClosed == WatcherTerminal TerminalComplete
    , assert "IssueComplete replay remains stopped until issue-close verifier succeeds" $
        completeRejected == WatcherActiveStopped
    , assert "IssueComplete replay becomes terminal complete when issue-close verifier succeeds" $
        completeAccepted == WatcherTerminal TerminalComplete
    ]

appServerRequestId :: PlannedAction -> Maybe Int
appServerRequestId = \case
  PlannedAppServerRequest request -> Just (unRequestId request.requestId)
  _ -> Nothing

lookupValue :: Text -> Value -> Maybe Value
lookupValue key (Object object') =
  KeyMap.lookup (Key.fromText key) object'
lookupValue _ _ =
  Nothing

assert :: String -> Bool -> IO Bool
assert assertionName condition = do
  if condition
    then putStrLn ("PASS " <> assertionName)
    else putStrLn ("FAIL " <> assertionName)
  pure condition

goldenReplayPr6Merged :: IO Bool
goldenReplayPr6Merged =
  goldenReplayCase "golden/pr-review/mlf2-pr6-merged" PrReview Complete True

goldenReplayCase :: FilePath -> Domain -> Phase -> Bool -> IO Bool
goldenReplayCase fixture expectedDomain expectedPhase expectWarnings = do
  loaded <- loadNodeSnapshot fixture
  case loaded of
    Left err -> do
      putStrLn ("FAIL golden decode " <> fixture <> ": " <> err)
      pure False
    Right snapshot -> do
      let replayed = replayNodeSnapshot snapshot
      case replayed of
        Left err -> do
          putStrLn ("FAIL golden replay " <> fixture <> ": " <> Text.unpack err)
          pure False
        Right replay -> do
          results <-
            sequence
              [ assert (fixture <> " domain") (someDomain replay.replayState == expectedDomain)
              , assert (fixture <> " phase") (somePhase replay.replayState == expectedPhase)
              , assert (fixture <> " warning expectation") (not (null replay.replayWarnings) == expectWarnings)
              ]
          pure (and results)

goldenReplayCases :: IO Bool
goldenReplayCases = do
  results <-
    sequence
      [ goldenReplayPr6Merged
      , goldenReplayCase "golden/pr-review/mlf2-pr6-unresolved" PrReview CheckingReviews True
      , goldenReplayCase "golden/pr-review/mlf2-pr6-blocked" PrReview Blocked False
      , goldenReplayCase "golden/pr-review/mlf2-pr6-clean-ready" PrReview WaitingMergeability False
      , goldenReplayCase "golden/issue-implement/mlf2-issue42-plan-ready" IssueImplement Implementing False
      , goldenReplayCase "golden/issue-implement/mlf2-issue42-incomplete" IssueImplement Implementing True
      , goldenReplayCase "golden/issue-implement/mlf2-issue42-blocked" IssueImplement Blocked False
      ]
  pure (and results)

goldenEventLogCase :: FilePath -> Domain -> Phase -> IO Bool
goldenEventLogCase path expectedDomain expectedPhase = do
  loaded <- loadEventLogFile path
  case loaded of
    Left err -> do
      putStrLn ("FAIL event log decode " <> path <> ": " <> err)
      pure False
    Right events ->
      case replayEventLog events of
        Left err -> do
          putStrLn ("FAIL event log replay " <> path <> ": " <> show err)
          pure False
        Right replay -> do
          results <-
            sequence
              [ assert (path <> " domain") (someDomain replay.replayState == expectedDomain)
              , assert (path <> " phase") (somePhase replay.replayState == expectedPhase)
              ]
          pure (and results)

goldenEventLogCases :: IO Bool
goldenEventLogCases = do
  results <-
    traverse
      (\(path, expectedDomain, expectedPhase) -> goldenEventLogCase path expectedDomain expectedPhase)
      goldenEventLogFixtures
  pure (and results)

goldenEventLogFixtures :: [(FilePath, Domain, Phase)]
goldenEventLogFixtures =
  [ ("golden/event-log/pr-review/mlf2-pr6-merged/events.jsonl", PrReview, Complete)
  , ("golden/event-log/pr-review/mlf2-pr6-reviewer-comments/events.jsonl", PrReview, CheckingReviews)
  , ("golden/event-log/pr-review/mlf2-pr6-worker-incomplete/events.jsonl", PrReview, CheckingReviews)
  , ("golden/event-log/pr-review/mlf2-pr6-reviewer-incomplete/events.jsonl", PrReview, CheckingReviews)
  , ("golden/event-log/issue-implement/mlf2-issue42-complete/events.jsonl", IssueImplement, Complete)
  , ("golden/event-log/issue-implement/mlf2-issue42-pr-created/events.jsonl", IssueImplement, Implementing)
  , ("golden/event-log/issue-implement/mlf2-issue42-pr-reused/events.jsonl", IssueImplement, Implementing)
  , ("golden/event-log/issue-implement/mlf2-issue42-incomplete-then-complete/events.jsonl", IssueImplement, Complete)
  , ("golden/event-log/issue-implement/mlf2-issue42-implementation-blocked/events.jsonl", IssueImplement, Blocked)
  , ("golden/event-log/issue-planning/mlf2-planning-ready/events.jsonl", IssuePlanning, Complete)
  ]

goldenEventLogFixturePaths :: [FilePath]
goldenEventLogFixturePaths =
  fmap (\(path, _domain, _phase) -> path) goldenEventLogFixtures

goldenBootstrapCase :: FilePath -> IO Bool
goldenBootstrapCase fixture = do
  loaded <- loadNodeSnapshot fixture
  case loaded of
    Left err -> do
      putStrLn ("FAIL golden bootstrap decode " <> fixture <> ": " <> err)
      pure False
    Right snapshot ->
      case (replayNodeSnapshot snapshot, replayEventLog (bootstrapNodeSnapshotEvents snapshot)) of
        (Left err, _) -> do
          putStrLn ("FAIL golden bootstrap normalized replay " <> fixture <> ": " <> Text.unpack err)
          pure False
        (_, Left err) -> do
          putStrLn ("FAIL golden bootstrap event replay " <> fixture <> ": " <> show err)
          pure False
        (Right normalized, Right bootstrapped) -> do
          let events = bootstrapNodeSnapshotEvents snapshot
              roundTripped =
                traverse
                  (eitherDecodeStrict' . LazyByteString.toStrict . encode)
                  events ::
                  Either String [WatcherEvent]
          results <-
            sequence
              [ assert (fixture <> " bootstrap nonempty") (not (null events))
              , assert (fixture <> " bootstrap json roundtrip") (roundTripped == Right events)
              , assert (fixture <> " bootstrap domain") (someDomain bootstrapped.replayState == someDomain normalized.replayState)
              , assert (fixture <> " bootstrap phase") (somePhase bootstrapped.replayState == somePhase normalized.replayState)
              ]
          pure (and results)

goldenBootstrapCases :: IO Bool
goldenBootstrapCases = do
  results <-
    sequence
      [ goldenBootstrapCase "golden/pr-review/mlf2-pr6-merged"
      , goldenBootstrapCase "golden/pr-review/mlf2-pr6-unresolved"
      , goldenBootstrapCase "golden/pr-review/mlf2-pr6-blocked"
      , goldenBootstrapCase "golden/pr-review/mlf2-pr6-clean-ready"
      , goldenBootstrapCase "golden/issue-implement/mlf2-issue42-plan-ready"
      , goldenBootstrapCase "golden/issue-implement/mlf2-issue42-incomplete"
      , goldenBootstrapCase "golden/issue-implement/mlf2-issue42-blocked"
      ]
  pure (and results)

data FakeActionCall
  = FakeCommand RuntimeCommand
  | FakeReadJson FilePath
  | FakeWriteJson FilePath Value
  | FakeWriteText FilePath Text
  | FakeAppendJsonLine FilePath Value
  | FakeAppServer AppServerRequest
  | FakeSleep
  | FakeStop
  deriving stock (Eq, Show)

fakeActionExecutor :: IO (ActionExecutor IO, IO [FakeActionCall])
fakeActionExecutor =
  fakeActionExecutorWith defaultFakeCommand defaultFakeAppServer

fakeActionExecutorWith :: (RuntimeCommand -> CommandReport) -> (AppServerRequest -> Value) -> IO (ActionExecutor IO, IO [FakeActionCall])
fakeActionExecutorWith =
  fakeActionExecutorWithLogger Log.noopWatcherLogger

fakeActionExecutorWithLogger :: Log.WatcherLogger IO -> (RuntimeCommand -> CommandReport) -> (AppServerRequest -> Value) -> IO (ActionExecutor IO, IO [FakeActionCall])
fakeActionExecutorWithLogger logger commandResponse appServerResponse = do
  calls <- newIORef []
  let record call = modifyIORef' calls (<> [call])
      runtime =
        RuntimeInterpreter
          { runtimeRunCommand = \command -> do
              record (FakeCommand command)
              pure (commandResponse command)
          , runtimeReadJsonValue = \path -> do
              record (FakeReadJson path)
              pure (Left "not implemented in fake")
          , runtimeWriteJsonValue = \path value -> record (FakeWriteJson path value)
          , runtimeWriteTextFile = \path content -> record (FakeWriteText path content)
          , runtimeAppendJsonLine = \path value -> record (FakeAppendJsonLine path value)
          }
      appServer =
        AppServerInterpreter
          { appServerSendRequest = \request -> do
              record (FakeAppServer request)
              pure (appServerResponse request)
          }
      executor =
        ActionExecutor
          { actionRuntime = runtime
          , actionAppServer = appServer
          , actionSleepUntilNextPoll = record FakeSleep
          , actionStopDaemon = record FakeStop
          , actionLogger = logger
          }
  pure (executor, readIORef calls)

fakeActionExecutorWithJsonStore :: (RuntimeCommand -> CommandReport) -> (AppServerRequest -> Value) -> IO (ActionExecutor IO, IO [FakeActionCall])
fakeActionExecutorWithJsonStore commandResponse appServerResponse = do
  calls <- newIORef []
  jsonStore <- newIORef []
  let record call = modifyIORef' calls (<> [call])
      readStoredJson path = lookup path <$> readIORef jsonStore
      writeStoredJson path value =
        modifyIORef' jsonStore \entries -> (path, value) : filter ((/= path) . fst) entries
      runtime =
        RuntimeInterpreter
          { runtimeRunCommand = \command -> do
              record (FakeCommand command)
              pure (commandResponse command)
          , runtimeReadJsonValue = \path -> do
              record (FakeReadJson path)
              stored <- readStoredJson path
              pure (maybe (Left "not found") Right stored)
          , runtimeWriteJsonValue = \path value -> do
              record (FakeWriteJson path value)
              writeStoredJson path value
          , runtimeWriteTextFile = \path content -> record (FakeWriteText path content)
          , runtimeAppendJsonLine = \path value -> record (FakeAppendJsonLine path value)
          }
      appServer =
        AppServerInterpreter
          { appServerSendRequest = \request -> do
              record (FakeAppServer request)
              pure (appServerResponse request)
          }
      executor =
        ActionExecutor
          { actionRuntime = runtime
          , actionAppServer = appServer
          , actionSleepUntilNextPoll = record FakeSleep
          , actionStopDaemon = record FakeStop
          , actionLogger = Log.noopWatcherLogger
          }
  pure (executor, readIORef calls)

collectWatcherLogs :: IO (Log.WatcherLogger IO, IO [Log.WatcherLog])
collectWatcherLogs = do
  logs <- newIORef []
  let logger = Log.watcherLoggerFromFunction \entry -> modifyIORef' logs (<> [entry])
  pure (logger, readIORef logs)

defaultFakeCommand :: RuntimeCommand -> CommandReport
defaultFakeCommand _command =
  CommandReport {ok = True, status = Just 0, stdout = "ok", stderr = "", errorMessage = Nothing}

jsonCommandReport :: Value -> CommandReport
jsonCommandReport value =
  CommandReport {ok = True, status = Just 0, stdout = jsonText value, stderr = "", errorMessage = Nothing}

failedCommandReport :: Text -> CommandReport
failedCommandReport message =
  CommandReport {ok = False, status = Just 1, stdout = "", stderr = message, errorMessage = Just message}

defaultFakeAppServer :: AppServerRequest -> Value
defaultFakeAppServer request
  | request.requestMethod == "thread/start" =
      object ["threadId" .= ("thread-started" :: Text)]
  | request.requestMethod == "turn/start" =
      object ["turnId" .= ("turn-started" :: Text)]
  | otherwise =
      object ["ok" .= True]

actionExecutorDryRunDoesNotCallInterpreters :: IO Bool
actionExecutorDryRunDoesNotCallInterpreters = do
  (executor, getCalls) <- fakeActionExecutor
  let reviewEvidence = reviewEvidenceFromSummaries ("review feedback" :| []) (CommitSha "abc123")
      compiled =
        compileEffectPlan
          (effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 60)
          [ SomeEffect (PushBranch (BranchName "codex/example"))
          , SomeEffect (StartWorkerTurn reviewEvidence (ThreadId "worker-thread"))
          , SomeEffect (RecordBlocked (BlockedReason "blocked"))
          , SomeEffect SleepUntilNextPoll
          , SomeEffect StopDaemon
          ]
  reports <- executeCompiledEffectPlan executor DryRunActions compiled
  calls <- getCalls
  results <-
    sequence
      [ assert "dry-run records every planned action" (length reports == length compiled.compiledActions)
      , assert "dry-run does not call interpreters" (null calls)
      , assert "dry-run reports skipped execution" (all ((== DryRunActionResult) . actionExecutionResult) reports)
      ]
  pure (and results)

actionExecutorExecuteCallsInjectedInterpreters :: IO Bool
actionExecutorExecuteCallsInjectedInterpreters = do
  (executor, getCalls) <- fakeActionExecutor
  let config = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 70
      blockedReason = BlockedReason "blocked"
      reviewEvidence = reviewEvidenceFromSummaries ("review feedback" :| []) (CommitSha "abc123")
      compiled =
        compileEffectPlan
          config
          [ SomeEffect (PushBranch (BranchName "codex/example"))
          , SomeEffect (StartWorkerTurn reviewEvidence (ThreadId "worker-thread"))
          , SomeEffect (RecordBlocked blockedReason)
          , SomeEffect SleepUntilNextPoll
          , SomeEffect StopDaemon
          ]
  reports <- executeCompiledEffectPlan executor ExecuteActions compiled
  calls <- getCalls
  let expectedBlockPath = runtimeStateDirFile config.effectRuntimeStateDir "block-state.json"
      expectedBlockJson = object ["blocked" .= True, "reason" .= unBlockedReason blockedReason]
      expectedWorkerInput = prReviewWorkerTurnInputWithEvidence "worker prompt" reviewEvidence
      expectedCalls =
        [ FakeCommand (GitPush "/tmp/work" (BranchName "codex/example"))
        , FakeAppServer (turnStartRequest (RequestId 70) (defaultTurnStartOptions (ThreadId "worker-thread") "/tmp/work" expectedWorkerInput))
        , FakeWriteJson expectedBlockPath expectedBlockJson
        , FakeSleep
        , FakeStop
        ]
  results <-
    sequence
      [ assert "execute records every planned action" (length reports == length compiled.compiledActions)
      , assert "execute calls injected interpreters in order" (calls == expectedCalls)
      , assert "execute reports executed mode" (all ((== ExecuteActions) . actionExecutionMode) reports)
      ]
  pure (and results)

watcherLogRenderingIncludesTimestampSeverityAndRedacts :: IO Bool
watcherLogRenderingIncludesTimestampSeverityAndRedacts = do
  let timestamp = UTCTime (fromGregorian 2026 4 23) (secondsToDiffTime 42)
      entry =
        Log.watcherLog
          Log.Info
          "runtime_lease"
          "runtime owner lease validated"
          [ "domain" .= ("issue-implement" :: Text)
          , "stdout" .= ("ok token=ghp_secret-token" :: Text)
          , "long" .= Text.replicate 2100 "x"
          ]
      rendered = Log.watcherLogJson timestamp entry
      renderedLine = Text.Encoding.decodeUtf8 (LazyByteString.toStrict (Log.watcherLogJsonLine timestamp entry))
      context = lookupValue "context" rendered
      stdoutValue = context >>= lookupValue "stdout"
      longValue = context >>= lookupValue "long"
  results <-
    sequence
      [ assert "watcher log includes timestamp" (lookupValue "timestamp" rendered /= Nothing)
      , assert "watcher log includes severity" (lookupValue "severity" rendered == Just (String "info"))
      , assert "watcher log includes event name" (lookupValue "event" rendered == Just (String "runtime_lease"))
      , assert "watcher log includes context" (context /= Nothing)
      , assert "watcher log redacts credentials" (stdoutValue == Just (String "ok <redacted-token>") && not ("ghp_secret" `Text.isInfixOf` renderedLine))
      , assert "watcher log caps long text" (case longValue of Just (String text) -> "<truncated>" `Text.isInfixOf` text && Text.length text < 2100; _ -> False)
      ]
  pure (and results)

actionExecutorLogsDryRunWhenLoggerInjected :: IO Bool
actionExecutorLogsDryRunWhenLoggerInjected = do
  (logger, getLogs) <- collectWatcherLogs
  (executor, getCalls) <- fakeActionExecutorWithLogger logger defaultFakeCommand defaultFakeAppServer
  let compiled =
        compileEffectPlan
          (effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 72)
          [ SomeEffect (PushBranch (BranchName "codex/example"))
          , SomeEffect SleepUntilNextPoll
          ]
  reports <- executeCompiledEffectPlan executor DryRunActions compiled
  calls <- getCalls
  logs <- getLogs
  results <-
    sequence
      [ assert "dry-run logging keeps interpreters untouched" (null calls)
      , assert "dry-run logging reports every planned action" (length reports == 2 && length (filter ((== "action_dry_run") . Log.watcherLogEvent) logs) == 2)
      , assert "dry-run logging uses debug level" (all ((== Log.Debug) . Log.watcherLogLevel) logs)
      ]
  pure (and results)

actionExecutorLogsCommandFailure :: IO Bool
actionExecutorLogsCommandFailure = do
  (logger, getLogs) <- collectWatcherLogs
  (executor, _getCalls) <-
    fakeActionExecutorWithLogger
      logger
      ( \case
          GitPush {} -> failedCommandReport "push failed ghp_secret-token"
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let compiled =
        compileEffectPlan
          (effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 73)
          [SomeEffect (PushBranch (BranchName "codex/example"))]
  reports <- executeCompiledEffectPlan executor ExecuteActions compiled
  logs <- getLogs
  let renderedLogs = Text.pack (show logs)
      commandFailed =
        case reports of
          [report] ->
            case report.actionExecutionResult of
              CommandActionResult commandReport -> not commandReport.ok
              _ -> False
          _ -> False
  results <-
    sequence
      [ assert "command failure still returns report" commandFailed
      , assert "command failure logs action start" ("action_started" `elem` fmap Log.watcherLogEvent logs)
      , assert "command failure logs error result" (any (\entry -> Log.watcherLogEvent entry == "action_finished" && Log.watcherLogLevel entry == Log.Error) logs)
      , assert "command failure log redacts command output" (not ("ghp_secret" `Text.isInfixOf` renderedLogs) && "<redacted-token>" `Text.isInfixOf` renderedLogs)
      ]
  pure (and results)

daemonTickDryRunReplaysEventsAndDoesNotExecute :: IO Bool
daemonTickDryRunReplaysEventsAndDoesNotExecute = do
  (executor, getCalls) <- fakeActionExecutor
  let runtimeConfig = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 90
      events =
        [ IssuePlanningInitialized (PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 8) [])
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "turn-plan")
        , IssuePlanningTurnCompleted
        ]
      nextEffects =
        [ SomeEffect (StartPlannerTurn (ThreadId "planner-thread"))
        , SomeEffect SleepUntilNextPoll
        ]
  result <- runDaemonTickWithEvents executor runtimeConfig DryRunActions events nextEffects
  calls <- getCalls
  case result of
    Right tick -> do
      results <-
        sequence
          [ assert "daemon tick replays event log" (someDomain tick.daemonReplayResult.replayState == IssuePlanning && somePhase tick.daemonReplayResult.replayState == Complete)
          , assert "daemon tick compiles supplied effects only" (length tick.daemonCompiledEffects.compiledActions == 2)
          , assert "daemon dry-run does not execute actions" (null calls)
          , assert "daemon dry-run reports actions" (length tick.daemonActionReports == 2 && all ((== DryRunActions) . actionExecutionMode) tick.daemonActionReports)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL daemon tick: " <> Text.unpack (formatDaemonFailure failure))
      pure False

daemonTickExecuteStopsOnCommandFailure :: IO Bool
daemonTickExecuteStopsOnCommandFailure = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GitPush {} -> failedCommandReport "push failed"
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 95
      branch = BranchName "codex/example"
      events = [IssuePlanningInitialized (PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 8) [])]
      nextEffects =
        [ SomeEffect (PushBranch branch)
        , SomeEffect SleepUntilNextPoll
        ]
  result <- runDaemonTickWithEvents executor runtimeConfig ExecuteActions events nextEffects
  calls <- getCalls
  results <-
    sequence
      [ assert "daemon execute stops on failed command" (case result of Left DaemonActionFailed {} -> True; _ -> False)
      , assert "daemon execute does not continue after failed command" (calls == [FakeCommand (GitPush "/tmp/work" branch)])
      ]
  pure (and results)

observedDaemonTickDryRunDoesNotMutate :: IO Bool
observedDaemonTickDryRunDoesNotMutate = do
  (executor, getCalls) <- fakeActionExecutor
  let runtimeConfig = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 100
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      events = [IssuePlanningInitialized (PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 8) [])]
      observation = DaemonIssuePlanningObservation (ObservedPlanningTurnStarted (ThreadId "planner-thread") (TurnId "turn-plan"))
  result <- runObservedDaemonTickWithEvents executor options events observation
  calls <- getCalls
  case result of
    Right tick -> do
      results <-
        sequence
          [ assert "observed dry-run emits canonical event" (daemonObservedEvent tick == IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "turn-plan"))
          , assert "observed dry-run computes compatibility writes" (length tick.daemonObservedCompatibilityWrites == 2)
          , assert "observed dry-run does not mutate" (null calls)
          , assert "observed dry-run reports planned actions" (length tick.daemonObservedActionReports == 1)
          , assert "observed dry-run audit records no committed event" (WorkflowEventLog.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Nothing)
          , assert "observed dry-run audit separates pre-commit reports" $
              WorkflowEventLog.workflowAuditPreCommitReports tick.daemonObservedAudit == tick.daemonObservedActionReports
                && null (WorkflowEventLog.workflowAuditPostCommitReports tick.daemonObservedAudit)
          , assert "observed dry-run audit recommends continuing" (WorkflowEventLog.workflowAuditNextDaemonRecommendation tick.daemonObservedAudit == WorkflowEventLog.WorkflowDaemonContinue)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL observed daemon dry-run: " <> Text.unpack (formatDaemonFailure failure))
      pure False

observedDaemonTickExecuteAppendsWritesAndRunsEffects :: IO Bool
observedDaemonTickExecuteAppendsWritesAndRunsEffects = do
  (executor, getCalls) <- fakeActionExecutor
  let runtimeConfig = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 110
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      events = [IssuePlanningInitialized (PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 8) [])]
      observation = DaemonIssuePlanningObservation (ObservedPlanningTurnStarted (ThreadId "planner-thread") (TurnId "turn-plan"))
  result <- runObservedDaemonTickWithEvents executor options events observation
  calls <- getCalls
  case result of
    Right tick -> do
      let expectedEvent = IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "turn-plan")
      results <-
        sequence
          [ assert "observed execute runs external action before appending event" (case calls of FakeAppServer {} : FakeAppendJsonLine "/tmp/events.jsonl" appended : _ -> appended == toJSON expectedEvent; _ -> False)
          , assert "observed execute writes compatibility state" (length [() | FakeWriteJson {} <- calls] == length tick.daemonObservedCompatibilityWrites)
          , assert "observed execute appends before compatibility writes" $
              let appendCall = FakeAppendJsonLine "/tmp/events.jsonl" (toJSON expectedEvent)
               in all (\write -> callBefore appendCall (FakeWriteJson (compatibilityWritePath write) (compatibilityWriteValue write)) calls) tick.daemonObservedCompatibilityWrites
          , assert "observed execute runs effect actions" (any isFakeAppServer calls)
          , assert "observed execute reaches plan mode" (somePhase tick.daemonObservedState == PlanMode)
          , assert "observed execute audit records committed event" (WorkflowEventLog.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just "issue_planning_turn_started")
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL observed daemon execute: " <> Text.unpack (formatDaemonFailure failure))
      pure False
 where
  isFakeAppServer = \case
    FakeAppServer {} -> True
    _ -> False

observedDaemonTickAuditSeparatesPreAndPostReports :: IO Bool
observedDaemonTickAuditSeparatesPreAndPostReports = do
  (executor, getCalls) <- fakeActionExecutor
  let repo = RepoName "soulomoon/mlf2"
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      prNumber = PrNumber 7
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 112
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      events =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssuePullRequestReusedEvent prNumber
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        ]
      observation = DaemonIssueImplementObservation (ObservedPlanCompleted sampleIssuePlanMarkdown Nothing)
      expectedEvent = IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
  result <- runObservedDaemonTickWithEvents executor options events observation
  calls <- getCalls
  case result of
    Right tick -> do
      let audit = tick.daemonObservedAudit
      results <-
        sequence
          [ assert "observed audit records prior state label" (WorkflowEventLog.workflowAuditPriorStateLabel audit == "IssueImplement/PlanMode")
          , assert "observed audit records observation label" (WorkflowEventLog.workflowAuditObservationLabel audit == Just "DaemonIssueImplementObservation (ObservedPlanCompleted \"Implement the issue in small verified steps.\" Nothing)")
          , assert "observed audit records committed event label" (WorkflowEventLog.workflowAuditCommittedEventLabel audit == Just "issue_plan_completed")
          , assert "observed audit records final state label" (WorkflowEventLog.workflowAuditFinalStateLabel audit == Just "IssueImplement/Implementing")
          , assert "observed audit records pre-commit plan write" (length (WorkflowEventLog.workflowAuditPreCommitReports audit) == 1)
          , assert "observed audit records post-commit sleep" (length (WorkflowEventLog.workflowAuditPostCommitReports audit) == 1)
          , assert "observed audit records no failure" (WorkflowEventLog.workflowAuditFailureClassification audit == Nothing)
          , assert "observed audit recommends continuing" (WorkflowEventLog.workflowAuditNextDaemonRecommendation audit == WorkflowEventLog.WorkflowDaemonContinue)
          , assert "observed audit still appends event before post-commit sleep" (callBefore (FakeAppendJsonLine "/tmp/events.jsonl" (toJSON expectedEvent)) FakeSleep calls)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL observed daemon audit: " <> Text.unpack (formatDaemonFailure failure))
      pure False

observedDaemonTickExecuteCommandFailureDoesNotAppendEvent :: IO Bool
observedDaemonTickExecuteCommandFailureDoesNotAppendEvent = do
  let repo = RepoName "soulomoon/mlf2"
      plannerConfig = PlannerConfig repo (maxParallelForTest 4) []
      issueRequest = IssueCreationRequest "child issue" "body" Nothing
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhIssueCreate {} -> failedCommandReport "issue create failed"
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 115
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      events =
        [ IssuePlanningInitialized plannerConfig
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "turn-plan")
        ]
      observation = DaemonIssuePlanningObservation (ObservedPlanningIssuesRequested (issueRequest :| []))
  result <- runObservedDaemonTickWithEvents executor options events observation
  calls <- getCalls
  results <-
    sequence
      [ assert "observed execute reports detailed pre-commit transaction failure" $
          case result of
            Left (DaemonObservedTransactionFailed failure) ->
              failure.daemonObservedTransactionFailureStage == WorkflowTransaction.WorkflowTransactionPreCommitActionFailure
                && case failure.daemonObservedTransactionFailureReason of
                  DaemonActionFailed {} -> True
                  _ -> False
                && failure.daemonObservedTransactionFailureCommittedEvents == []
                && failure.daemonObservedTransactionFailurePreCommitReports == []
                && (WorkflowEventLog.workflowAuditCommittedEventLabel <$> failure.daemonObservedTransactionFailureAudit) == Just Nothing
            _ -> False
      , assert "observed execute does not append event after command failure" (not (any isAppend calls))
      , assert "observed execute attempted issue creation" (FakeCommand (GhIssueCreate repo issueRequest) `elem` calls)
      ]
  pure (and results)
 where
  isAppend = \case
    FakeAppendJsonLine {} -> True
    _ -> False

observedDaemonTickPreMergeGateRechecksWhenHeadChanged :: IO Bool
observedDaemonTickPreMergeGateRechecksWhenHeadChanged = do
  let repo = RepoName "soulomoon/mlf2"
      prNumber = PrNumber 6
      prConfig = PrConfig repo prNumber (BranchName "codex/example")
      cleanEvidence = CleanReviewEvidence (CommitSha "abc123") "LGTM"
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhPrView {} ->
            jsonCommandReport
              ( object
                  [ "state" .= ("OPEN" :: Text)
                  , "headRefOid" .= ("def456" :: Text)
                  , "mergeStateStatus" .= ("CLEAN" :: Text)
                  ]
              )
          GhReviewThreads {} -> jsonCommandReport emptyReviewThreadsJson
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 116
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events =
        [ PrReviewInitialized prConfig (ThreadId "worker-thread") (ThreadId "reviewer-thread")
        , PrReviewNoUnresolvedFound (cleanReviewCommit cleanEvidence) (TurnId "reviewer-turn")
        , PrReviewCleanFound cleanEvidence []
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          observedPhase = somePhase . daemonObservedState <$> tick.loopObservedTick
      results <-
        sequence
          [ assert "pre-merge gate emits mergeability recheck on head change" (observedEvent == Just (PrReviewMergeabilityRecheck "pre-merge PR head changed from reviewed commit abc123 to def456"))
          , assert "pre-merge gate does not merge changed head" (not (any isMerge calls))
          , assert "pre-merge gate returns to checking reviews" (observedPhase == Just CheckingReviews)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL pre-merge head-change gate: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isMerge = \case
    FakeCommand GhPrCleanReviewAndMerge {} -> True
    _ -> False

observedDaemonTickPreMergeGateMergesWhenClean :: IO Bool
observedDaemonTickPreMergeGateMergesWhenClean = do
  let repo = RepoName "soulomoon/mlf2"
      prNumber = PrNumber 6
      prConfig = PrConfig repo prNumber (BranchName "codex/example")
      cleanEvidence = CleanReviewEvidence (CommitSha "abc123") "LGTM"
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhPrView {} ->
            jsonCommandReport
              ( object
                  [ "state" .= ("OPEN" :: Text)
                  , "headRefOid" .= ("abc123" :: Text)
                  , "mergeStateStatus" .= ("CLEAN" :: Text)
                  ]
              )
          GhReviewThreads {} -> jsonCommandReport emptyReviewThreadsJson
          GhPrChecks {} ->
            jsonCommandReport
              ( toJSON
                  [ object
                      [ "name" .= ("ci/test" :: Text)
                      , "state" .= ("SUCCESS" :: Text)
                      , "bucket" .= ("pass" :: Text)
                      ]
                  ]
              )
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 117
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events =
        [ PrReviewInitialized prConfig (ThreadId "worker-thread") (ThreadId "reviewer-thread")
        , PrReviewNoUnresolvedFound (cleanReviewCommit cleanEvidence) (TurnId "reviewer-turn")
        , PrReviewCleanFound cleanEvidence []
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          observedPhase = somePhase . daemonObservedState <$> tick.loopObservedTick
      results <-
        sequence
          [ assert "pre-merge gate emits mergeability clean event" (observedEvent == Just (PrReviewMergeabilityClean (cleanReviewCommit cleanEvidence)))
          , assert "pre-merge gate reads PR checks" (FakeCommand (GhPrChecks repo prNumber) `elem` calls)
          , assert "pre-merge gate merges after passing checks" (any isMerge calls)
          , assert "pre-merge gate reaches merging state" (observedPhase == Just Merging)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL pre-merge clean gate: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isMerge = \case
    FakeCommand GhPrCleanReviewAndMerge {} -> True
    _ -> False

observedDaemonTickPreMergeGateWaitsWhenUnstable :: IO Bool
observedDaemonTickPreMergeGateWaitsWhenUnstable = do
  let repo = RepoName "soulomoon/mlf2"
      prNumber = PrNumber 6
      prConfig = PrConfig repo prNumber (BranchName "codex/example")
      cleanEvidence = CleanReviewEvidence (CommitSha "abc123") "LGTM"
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhPrView {} ->
            jsonCommandReport
              ( object
                  [ "state" .= ("OPEN" :: Text)
                  , "headRefOid" .= ("abc123" :: Text)
                  , "mergeStateStatus" .= ("UNSTABLE" :: Text)
                  ]
              )
          GhPrChecks {} ->
            jsonCommandReport
              ( toJSON
                  [ object
                      [ "name" .= ("ci/test" :: Text)
                      , "state" .= ("SUCCESS" :: Text)
                      , "bucket" .= ("pass" :: Text)
                      ]
                  ]
              )
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 118
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events =
        [ PrReviewInitialized prConfig (ThreadId "worker-thread") (ThreadId "reviewer-thread")
        , PrReviewNoUnresolvedFound (cleanReviewCommit cleanEvidence) (TurnId "reviewer-turn")
        , PrReviewCleanFound cleanEvidence []
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          observedPhase = somePhase . daemonObservedState <$> tick.loopObservedTick
      results <-
        sequence
          [ assert "pre-merge unstable emits waiting event" (observedEvent == Just (PrReviewMergeabilityWaiting "pre-merge merge state is UNSTABLE"))
          , assert "pre-merge unstable reads PR checks" (FakeCommand (GhPrChecks repo prNumber) `elem` calls)
          , assert "pre-merge unstable does not merge" (not (any isMerge calls))
          , assert "pre-merge unstable remains non-terminal" (observedPhase == Just WaitingMergeability)
          , assert "pre-merge unstable does not write block-state" (not (any isBlockWrite calls))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL pre-merge unstable gate: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isMerge = \case
    FakeCommand GhPrCleanReviewAndMerge {} -> True
    _ -> False
  isBlockWrite = \case
    FakeWriteJson path _ -> path == "/tmp/work/.watcher/block-state.json"
    _ -> False

observedDaemonTickPreMergeGateQueuesWorkerWhenUnstableChecksFail :: IO Bool
observedDaemonTickPreMergeGateQueuesWorkerWhenUnstableChecksFail = do
  let repo = RepoName "soulomoon/mlf2"
      prNumber = PrNumber 6
      prConfig = PrConfig repo prNumber (BranchName "codex/example")
      cleanEvidence = CleanReviewEvidence (CommitSha "abc123") "LGTM"
      expectedEvidence =
        reviewEvidenceFromSummaries
          ("pre-merge PR checks are not successful: Thesis Conformance Gate" :| [])
          (cleanReviewCommit cleanEvidence)
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhPrView {} ->
            jsonCommandReport
              ( object
                  [ "state" .= ("OPEN" :: Text)
                  , "headRefOid" .= ("abc123" :: Text)
                  , "mergeStateStatus" .= ("UNSTABLE" :: Text)
                  ]
              )
          GhPrChecks {} ->
            jsonCommandReport
              ( toJSON
                  [ object
                      [ "name" .= ("Thesis Conformance Gate" :: Text)
                      , "state" .= ("FAILURE" :: Text)
                      , "bucket" .= ("fail" :: Text)
                      ]
                  ]
              )
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 118
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events =
        [ PrReviewInitialized prConfig (ThreadId "worker-thread") (ThreadId "reviewer-thread")
        , PrReviewNoUnresolvedFound (cleanReviewCommit cleanEvidence) (TurnId "reviewer-turn")
        , PrReviewCleanFound cleanEvidence []
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          observedState = daemonObservedState <$> tick.loopObservedTick
      results <-
        sequence
          [ assert "pre-merge unstable failed checks emits worker-fix event" (observedEvent == Just (PrReviewMergeabilityFixRequired expectedEvidence))
          , assert "pre-merge unstable failed checks queues worker fix" (maybe False isFixQueued observedState)
          , assert "pre-merge unstable failed checks reads PR checks" (FakeCommand (GhPrChecks repo prNumber) `elem` calls)
          , assert "pre-merge unstable failed checks does not merge" (not (any isMerge calls))
          , assert "pre-merge unstable failed checks does not write block-state" (not (any isBlockWrite calls))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL pre-merge unstable failed checks gate: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isFixQueued = \case
    SomeWatcherState PrReviewFixQueued {} -> True
    _ -> False
  isMerge = \case
    FakeCommand GhPrCleanReviewAndMerge {} -> True
    _ -> False
  isBlockWrite = \case
    FakeWriteJson path _ -> path == "/tmp/work/.watcher/block-state.json"
    _ -> False

observedDaemonTickPreMergeGateQueuesWorkerWhenDirty :: IO Bool
observedDaemonTickPreMergeGateQueuesWorkerWhenDirty =
  observedDaemonTickPreMergeGateQueuesWorkerForMergeState "DIRTY"

observedDaemonTickPreMergeGateQueuesWorkerWhenConflicting :: IO Bool
observedDaemonTickPreMergeGateQueuesWorkerWhenConflicting =
  observedDaemonTickPreMergeGateQueuesWorkerForMergeState "CONFLICTING"

observedDaemonTickPreMergeGateQueuesWorkerForMergeState :: Text -> IO Bool
observedDaemonTickPreMergeGateQueuesWorkerForMergeState mergeState = do
  let repo = RepoName "soulomoon/mlf2"
      prNumber = PrNumber 6
      prConfig = PrConfig repo prNumber (BranchName "codex/example")
      cleanEvidence = CleanReviewEvidence (CommitSha "abc123") "LGTM"
      expectedFinding =
        "pre-merge merge state is "
          <> mergeState
          <> ": the PR branch is not mergeable with the latest base branch. Merge or rebase the latest base branch into the PR branch, resolve conflicts, rerun validation, and push the fix."
      expectedEvidence = reviewEvidenceFromSummaries (expectedFinding :| []) (cleanReviewCommit cleanEvidence)
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhPrView {} ->
            jsonCommandReport
              ( object
                  [ "state" .= ("OPEN" :: Text)
                  , "headRefOid" .= ("abc123" :: Text)
                  , "mergeStateStatus" .= mergeState
                  ]
              )
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 119
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events =
        [ PrReviewInitialized prConfig (ThreadId "worker-thread") (ThreadId "reviewer-thread")
        , PrReviewNoUnresolvedFound (cleanReviewCommit cleanEvidence) (TurnId "reviewer-turn")
        , PrReviewCleanFound cleanEvidence []
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          observedState = daemonObservedState <$> tick.loopObservedTick
      results <-
        sequence
          [ assert ("pre-merge " <> Text.unpack mergeState <> " emits worker-fix event") (observedEvent == Just (PrReviewMergeabilityFixRequired expectedEvidence))
          , assert ("pre-merge " <> Text.unpack mergeState <> " queues worker fix") (maybe False isFixQueued observedState)
          , assert ("pre-merge " <> Text.unpack mergeState <> " does not merge") (not (any isMerge calls))
          , assert ("pre-merge " <> Text.unpack mergeState <> " does not write block-state") (not (any isBlockWrite calls))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL pre-merge " <> Text.unpack mergeState <> " gate: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isFixQueued = \case
    SomeWatcherState PrReviewFixQueued {} -> True
    _ -> False
  isMerge = \case
    FakeCommand GhPrCleanReviewAndMerge {} -> True
    _ -> False
  isBlockWrite = \case
    FakeWriteJson path _ -> path == "/tmp/work/.watcher/block-state.json"
    _ -> False

observedDaemonTickPreMergeGateRetriesTransientGithubReads :: IO Bool
observedDaemonTickPreMergeGateRetriesTransientGithubReads = do
  let repo = RepoName "soulomoon/mlf2"
      prNumber = PrNumber 6
      prConfig = PrConfig repo prNumber (BranchName "codex/example")
      cleanEvidence = CleanReviewEvidence (CommitSha "abc123") "LGTM"
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhPrView {} ->
            CommandReport {ok = False, status = Just 1, stdout = "", stderr = "GitHub GraphQL EOF", errorMessage = Nothing}
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 120
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events =
        [ PrReviewInitialized prConfig (ThreadId "worker-thread") (ThreadId "reviewer-thread")
        , PrReviewNoUnresolvedFound (cleanReviewCommit cleanEvidence) (TurnId "reviewer-turn")
        , PrReviewCleanFound cleanEvidence []
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          observedPhase = somePhase . daemonObservedState <$> tick.loopObservedTick
      results <-
        sequence
          [ assert "transient GitHub read emits mergeability retry" (observedEvent == Just (PrReviewMergeabilityWaiting "pre-merge PR read failed: GitHub GraphQL EOF"))
          , assert "transient GitHub read stays waiting" (observedPhase == Just WaitingMergeability)
          , assert "transient GitHub read does not block" (not (any isBlockWrite calls))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL pre-merge transient gate: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isBlockWrite = \case
    FakeWriteJson path _ -> path == "/tmp/work/.watcher/block-state.json"
    _ -> False

observedDaemonTickChangesRequestedStartsWorker :: IO Bool
observedDaemonTickChangesRequestedStartsWorker = do
  let repo = RepoName "soulomoon/mlf2"
      prNumber = PrNumber 6
      branch = BranchName "codex/example"
      prConfig = PrConfig repo prNumber branch
      commit = CommitSha "abc123"
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \command ->
          case command of
            GitBranchCurrent {} -> (defaultFakeCommand command) {stdout = unBranchName branch}
            GitRevParseHead {} -> (defaultFakeCommand command) {stdout = unCommitSha commit}
            GitStatusPorcelain {} -> (defaultFakeCommand command) {stdout = ""}
            GitLsRemoteBranch {} -> (defaultFakeCommand command) {stdout = unCommitSha commit <> "\trefs/heads/" <> unBranchName branch}
            GhReviewThreads {} -> jsonCommandReport emptyReviewThreadsJson
            GhPrView {} ->
              jsonCommandReport
                ( object
                    [ "state" .= ("OPEN" :: Text)
                    , "headRefOid" .= unCommitSha commit
                    , "mergeStateStatus" .= ("CLEAN" :: Text)
                    , "reviewDecision" .= ("CHANGES_REQUESTED" :: Text)
                    ]
                )
            _ -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 119
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events =
        [PrReviewInitialized prConfig (ThreadId "worker-thread") (ThreadId "reviewer-thread")]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          observedPhase = somePhase . daemonObservedState <$> tick.loopObservedTick
          turnStartThreadIds =
            [ lookupValue "threadId" request.requestParams
            | FakeAppServer request <- calls
            , request.requestMethod == "turn/start"
            ]
          evidenceMatches = \case
            Just (PrReviewFeedbackFound evidence (TurnId "turn-started")) ->
              reviewedCommit evidence == commit
                && reviewEvidenceThreadIds evidence == []
                && any ("CHANGES_REQUESTED" `Text.isInfixOf`) (reviewEvidenceSummaries evidence)
            _ -> False
      results <-
        sequence
          [ assert "changes-requested reviewDecision emits review feedback" (evidenceMatches observedEvent)
          , assert "changes-requested reviewDecision starts worker" (turnStartThreadIds == [Just (String "worker-thread")])
          , assert "changes-requested reviewDecision moves to fixing reviews" (observedPhase == Just FixingReviews)
          , assert "changes-requested reviewDecision reads PR reviewDecision" (any isGhPrView calls)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL changes-requested reviewDecision worker start: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isGhPrView = \case
    FakeCommand GhPrView {} -> True
    _ -> False

observedDaemonTickCheckingQueuesWorkerWhenChecksFail :: IO Bool
observedDaemonTickCheckingQueuesWorkerWhenChecksFail = do
  let repo = RepoName "soulomoon/mlf2"
      prNumber = PrNumber 6
      branch = BranchName "codex/example"
      prConfig = PrConfig repo prNumber branch
      commit = CommitSha "abc123"
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \command ->
          case command of
            GitBranchCurrent {} -> (defaultFakeCommand command) {stdout = unBranchName branch}
            GitRevParseHead {} -> (defaultFakeCommand command) {stdout = unCommitSha commit}
            GitStatusPorcelain {} -> (defaultFakeCommand command) {stdout = ""}
            GitLsRemoteBranch {} -> (defaultFakeCommand command) {stdout = unCommitSha commit <> "\trefs/heads/" <> unBranchName branch}
            GhReviewThreads {} -> jsonCommandReport emptyReviewThreadsJson
            GhPrChecks {} ->
              jsonCommandReport
                ( toJSON
                    [ object
                        [ "name" .= ("Thesis Conformance Gate" :: Text)
                        , "state" .= ("FAILURE" :: Text)
                        , "bucket" .= ("fail" :: Text)
                        ]
                    , object
                        [ "name" .= ("Build & Test" :: Text)
                        , "state" .= ("SUCCESS" :: Text)
                        , "bucket" .= ("pass" :: Text)
                        ]
                    ]
                )
            GhPrView {} ->
              jsonCommandReport
                ( object
                    [ "state" .= ("OPEN" :: Text)
                    , "headRefOid" .= unCommitSha commit
                    , "mergeStateStatus" .= ("CLEAN" :: Text)
                    , "reviewDecision" .= ("REVIEW_REQUIRED" :: Text)
                    ]
                )
            _ -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 121
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events =
        [PrReviewInitialized prConfig (ThreadId "worker-thread") (ThreadId "reviewer-thread")]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          observedPhase = somePhase . daemonObservedState <$> tick.loopObservedTick
          turnStartThreadIds =
            [ lookupValue "threadId" request.requestParams
            | FakeAppServer request <- calls
            , request.requestMethod == "turn/start"
            ]
          evidenceMatches = \case
            Just (PrReviewFeedbackFound evidence (TurnId "turn-started")) ->
              reviewedCommit evidence == commit
                && reviewEvidenceThreadIds evidence == []
                && any ("pre-merge PR checks are not successful: Thesis Conformance Gate" `Text.isInfixOf`) (reviewEvidenceSummaries evidence)
            _ -> False
      results <-
        sequence
          [ assert "checking failed PR checks emits review feedback" (evidenceMatches observedEvent)
          , assert "checking failed PR checks starts worker" (turnStartThreadIds == [Just (String "worker-thread")])
          , assert "checking failed PR checks moves to fixing reviews" (observedPhase == Just FixingReviews)
          , assert "checking failed PR checks reads review threads" (any isGhReviewThreads calls)
          , assert "checking failed PR checks reads PR checks" (any isGhPrChecks calls)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL checking failed PR checks worker start: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isGhReviewThreads = \case
    FakeCommand GhReviewThreads {} -> True
    _ -> False
  isGhPrChecks = \case
    FakeCommand GhPrChecks {} -> True
    _ -> False

observedDaemonTickCheckingQueuesMergeStateFixBeforeReviewThreads :: IO Bool
observedDaemonTickCheckingQueuesMergeStateFixBeforeReviewThreads = do
  let repo = RepoName "soulomoon/mlf2"
      prNumber = PrNumber 6
      branch = BranchName "codex/example"
      prConfig = PrConfig repo prNumber branch
      commit = CommitSha "abc123"
      expectedFinding =
        "merge state is DIRTY: the PR branch is not mergeable with the latest base branch. Merge or rebase the latest base branch into the PR branch, resolve conflicts, rerun validation, and push the fix."
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \command ->
          case command of
            GitBranchCurrent {} -> (defaultFakeCommand command) {stdout = unBranchName branch}
            GitRevParseHead {} -> (defaultFakeCommand command) {stdout = unCommitSha commit}
            GitStatusPorcelain {} -> (defaultFakeCommand command) {stdout = ""}
            GitLsRemoteBranch {} -> (defaultFakeCommand command) {stdout = unCommitSha commit <> "\trefs/heads/" <> unBranchName branch}
            GhPrView {} ->
              jsonCommandReport
                ( object
                    [ "state" .= ("OPEN" :: Text)
                    , "headRefOid" .= unCommitSha commit
                    , "mergeStateStatus" .= ("DIRTY" :: Text)
                    , "reviewDecision" .= ("CHANGES_REQUESTED" :: Text)
                    ]
                )
            GhReviewThreads {} -> jsonCommandReport emptyReviewThreadsJson
            _ -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 120
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events =
        [PrReviewInitialized prConfig (ThreadId "worker-thread") (ThreadId "reviewer-thread")]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          observedPhase = somePhase . daemonObservedState <$> tick.loopObservedTick
          turnStartThreadIds =
            [ lookupValue "threadId" request.requestParams
            | FakeAppServer request <- calls
            , request.requestMethod == "turn/start"
            ]
          evidenceMatches = \case
            Just (PrReviewFeedbackFound evidence (TurnId "turn-started")) ->
              reviewedCommit evidence == commit
                && reviewEvidenceSummaries evidence == [expectedFinding]
            _ -> False
      results <-
        sequence
          [ assert "checking dirty merge state emits merge-state feedback" (evidenceMatches observedEvent)
          , assert "checking dirty merge state starts worker" (turnStartThreadIds == [Just (String "worker-thread")])
          , assert "checking dirty merge state moves to fixing reviews" (observedPhase == Just FixingReviews)
          , assert "checking dirty merge state reads PR before review threads" (any isGhPrView calls)
          , assert "checking dirty merge state does not read review threads first" (not (any isGhReviewThreads calls))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL checking dirty merge state worker start: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isGhPrView = \case
    FakeCommand GhPrView {} -> True
    _ -> False
  isGhReviewThreads = \case
    FakeCommand GhReviewThreads {} -> True
    _ -> False

observedDaemonTickVerificationQueuesMergeStateFixBeforeReviewer :: IO Bool
observedDaemonTickVerificationQueuesMergeStateFixBeforeReviewer = do
  let repo = RepoName "soulomoon/mlf2"
      prNumber = PrNumber 6
      branch = BranchName "codex/example"
      prConfig = PrConfig repo prNumber branch
      commit = CommitSha "abc123"
      reviewThreadId = ReviewThreadId "thread-1"
      expectedFinding =
        "merge state is BEHIND: the PR branch is not mergeable with the latest base branch. Merge or rebase the latest base branch into the PR branch, resolve conflicts, rerun validation, and push the fix."
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \command ->
          case command of
            GitBranchCurrent {} -> (defaultFakeCommand command) {stdout = unBranchName branch}
            GitRevParseHead {} -> (defaultFakeCommand command) {stdout = unCommitSha commit}
            GitStatusPorcelain {} -> (defaultFakeCommand command) {stdout = ""}
            GitLsRemoteBranch {} -> (defaultFakeCommand command) {stdout = unCommitSha commit <> "\trefs/heads/" <> unBranchName branch}
            GhPrView {} ->
              jsonCommandReport
                ( object
                    [ "state" .= ("OPEN" :: Text)
                    , "headRefOid" .= unCommitSha commit
                    , "mergeStateStatus" .= ("BEHIND" :: Text)
                    ]
                )
            _ -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 121
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events =
        [ PrReviewInitialized prConfig (ThreadId "worker-thread") (ThreadId "reviewer-thread")
        , PrReviewUnresolvedFound (reviewThreadId :| []) commit (TurnId "fix-turn")
        , PrReviewFixCompleted
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          observedPhase = somePhase . daemonObservedState <$> tick.loopObservedTick
          turnStartThreadIds =
            [ lookupValue "threadId" request.requestParams
            | FakeAppServer request <- calls
            , request.requestMethod == "turn/start"
            ]
          evidenceMatches = \case
            Just (PrReviewFeedbackFound evidence (TurnId "turn-started")) ->
              reviewedCommit evidence == commit
                && reviewEvidenceSummaries evidence == [expectedFinding]
            _ -> False
      results <-
        sequence
          [ assert "verification behind merge state emits merge-state feedback" (evidenceMatches observedEvent)
          , assert "verification behind merge state starts worker" (turnStartThreadIds == [Just (String "worker-thread")])
          , assert "verification behind merge state returns to fixing reviews" (observedPhase == Just FixingReviews)
          , assert "verification behind merge state does not start reviewer" (not (any isReviewerTurn calls))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL verification behind merge state worker start: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isReviewerTurn = \case
    FakeAppServer request ->
      request.requestMethod == "turn/start"
        && lookupValue "threadId" request.requestParams == Just (String "reviewer-thread")
    _ -> False

emptyReviewThreadsJson :: Value
emptyReviewThreadsJson =
  object
    [ "data"
        .= object
          [ "repository"
              .= object
                [ "pullRequest"
                    .= object
                      [ "reviewThreads"
                          .= object
                            [ "nodes" .= ([] :: [Value])
                            ]
                      ]
                ]
          ]
    ]

automaticDaemonLoopPlanningDryRunStartsSyntheticTurn :: IO Bool
automaticDaemonLoopPlanningDryRunStartsSyntheticTurn = do
  (executor, getCalls) <- fakeActionExecutor
  let runtimeConfig = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 120
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events = [IssuePlanningInitialized (PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 8) [])]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
      results <-
        sequence
          [ assert "automatic planning dry-run emits a planning start" (observedEvent == Just (IssuePlanningTurnStarted (ThreadId "dry-run-planner-thread-120") (TurnId "dry-run-planner-turn-121")))
          , assert "automatic planning dry-run does not call interpreters" (null calls)
          , assert "automatic planning dry-run reports thread and turn start actions" (length tick.loopActionReports == 2)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic planning dry-run: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart :: IO Bool
automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart = do
  let repo = RepoName "soulomoon/mlf2"
      issueNumber = IssueNumber 12
      issueJson =
        object
          [ "number" .= (12 :: Int)
          , "title" .= ("Root issue" :: Text)
          , "state" .= ("OPEN" :: Text)
          , "closed" .= False
          , "body" .= ("Root body" :: Text)
          , "url" .= ("https://github.com/soulomoon/mlf2/issues/12" :: Text)
          , "labels" .= ([] :: [Value])
          , "assignees" .= ([] :: [Value])
          ]
      subIssuesJson =
        toJSON
          [ object
              [ "number" .= (26 :: Int)
              , "title" .= ("Sub issue" :: Text)
              , "state" .= ("CLOSED" :: Text)
              , "closed" .= True
              , "body" .= ("Sub body" :: Text)
              , "url" .= ("https://github.com/soulomoon/mlf2/issues/26" :: Text)
              , "parentIssueNumber" .= (12 :: Int)
              ]
          ]
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          RawCommand "gh" ["issue", "view", "12", "--repo", "soulomoon/mlf2", "--json", _] Nothing ->
            jsonCommandReport issueJson
          RawCommand "gh" ["api", "repos/soulomoon/mlf2/issues/12/sub_issues", "--paginate", "--jq", _] Nothing ->
            jsonCommandReport subIssuesJson
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 121
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events = [IssuePlanningInitialized (PlannerConfig repo (maxParallelForTest 8) [issueNumber])]
      snapshotPath = runtimeStateDirFile runtimeConfig.effectRuntimeStateDir "issue-snapshot.json"
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          snapshotWrites = [value | FakeWriteJson path value <- calls, path == snapshotPath]
          threadStarts = [request | FakeAppServer request <- calls, request.requestMethod == "thread/start"]
          starts = [request | FakeAppServer request <- calls, request.requestMethod == "turn/start"]
      results <-
        sequence
          [ assert "automatic planning execute writes issue snapshot" (length snapshotWrites == 1)
          , assert "automatic planning execute starts after snapshot" (snapshotWriteBeforeTurnStart snapshotPath calls)
          , assert "automatic planning execute starts one planner thread" (length threadStarts == 1)
          , assert "automatic planning execute starts planner thread in state dir" (all ((== Just "/tmp/work/.watcher") . actionThreadCwd . PlannedAppServerRequest) threadStarts)
          , assert "automatic planning execute emits start event" (observedEvent == Just (IssuePlanningTurnStarted (ThreadId "thread-started") (TurnId "turn-started")))
          , assert "automatic planning execute starts one turn" (length starts == 1)
          , assert "automatic planning execute starts planner turn in state dir" (all ((== Just "/tmp/work/.watcher") . actionThreadCwd . PlannedAppServerRequest) starts)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic planning snapshot: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  snapshotWriteBeforeTurnStart snapshotPath calls =
    case break isTurnStart calls of
      (beforeStart, FakeAppServer {} : _) -> any (isSnapshotWrite snapshotPath) beforeStart
      _ -> False
  isTurnStart = \case
    FakeAppServer request -> request.requestMethod == "turn/start"
    _ -> False
  isSnapshotWrite snapshotPath = \case
    FakeWriteJson path _ -> path == snapshotPath
    _ -> False

automaticDaemonLoopPlanningExecuteStartsFreshPlannerThread :: IO Bool
automaticDaemonLoopPlanningExecuteStartsFreshPlannerThread = do
  let repo = RepoName "soulomoon/mlf2"
      issueNumber = IssueNumber 12
      issueJson =
        object
          [ "number" .= (12 :: Int)
          , "title" .= ("Root issue" :: Text)
          , "state" .= ("OPEN" :: Text)
          , "closed" .= False
          , "body" .= ("Root body" :: Text)
          , "url" .= ("https://github.com/soulomoon/mlf2/issues/12" :: Text)
          , "labels" .= ([] :: [Value])
          , "assignees" .= ([] :: [Value])
          ]
      subIssuesJson = toJSON ([] :: [Value])
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          RawCommand "gh" ["issue", "view", "12", "--repo", "soulomoon/mlf2", "--json", _] Nothing ->
            jsonCommandReport issueJson
          RawCommand "gh" ["api", "repos/soulomoon/mlf2/issues/12/sub_issues", "--paginate", "--jq", _] Nothing ->
            jsonCommandReport subIssuesJson
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 121
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      stalePlannerThread = ThreadId "stale-planner-thread"
      loopConfig = DaemonLoopConfig options (Just stalePlannerThread)
      events = [IssuePlanningInitialized (PlannerConfig repo (maxParallelForTest 8) [issueNumber])]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          threadStarts = [request | FakeAppServer request <- calls, request.requestMethod == "thread/start"]
          turnStarts = [request | FakeAppServer request <- calls, request.requestMethod == "turn/start"]
          turnStartThreadIds = [lookupValue "threadId" request.requestParams | request <- turnStarts]
      results <-
        sequence
          [ assert "automatic planning execute refreshes stale planner thread" (length threadStarts == 1)
          , assert "automatic planning execute starts one turn on fresh planner thread" (turnStartThreadIds == [Just (String "thread-started")])
          , assert "automatic planning execute does not reuse stale planner thread" (Just (String (unThreadId stalePlannerThread)) `notElem` turnStartThreadIds)
          , assert "automatic planning execute emits refreshed planner thread event" (observedEvent == Just (IssuePlanningTurnStarted (ThreadId "thread-started") (TurnId "turn-started")))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic planning fresh planner thread: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn :: IO Bool
automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn = do
  let repo = RepoName "soulomoon/mlf2"
      issueNumber = IssueNumber 12
      issueJson =
        object
          [ "number" .= (12 :: Int)
          , "title" .= ("Root issue" :: Text)
          , "state" .= ("CLOSED" :: Text)
          , "closed" .= True
          , "body" .= ("Root body" :: Text)
          , "url" .= ("https://github.com/soulomoon/mlf2/issues/12" :: Text)
          , "labels" .= ([] :: [Value])
          , "assignees" .= ([] :: [Value])
          ]
      subIssuesJson =
        toJSON
          [ object
              [ "number" .= (26 :: Int)
              , "title" .= ("Sub issue" :: Text)
              , "state" .= ("CLOSED" :: Text)
              , "closed" .= True
              , "body" .= ("Sub body" :: Text)
              , "url" .= ("https://github.com/soulomoon/mlf2/issues/26" :: Text)
              , "parentIssueNumber" .= (12 :: Int)
              ]
          ]
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          RawCommand "gh" ["issue", "view", "12", "--repo", "soulomoon/mlf2", "--json", _] Nothing ->
            jsonCommandReport issueJson
          RawCommand "gh" ["api", "repos/soulomoon/mlf2/issues/12/sub_issues", "--paginate", "--jq", _] Nothing ->
            jsonCommandReport subIssuesJson
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 122
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events = [IssuePlanningInitialized (PlannerConfig repo (maxParallelForTest 8) [issueNumber])]
      snapshotPath = runtimeStateDirFile runtimeConfig.effectRuntimeStateDir "issue-snapshot.json"
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          observedPhase = somePhase . daemonObservedState <$> tick.loopObservedTick
          snapshotWrites = [value | FakeWriteJson path value <- calls, path == snapshotPath]
          threadStarts = [request | FakeAppServer request <- calls, request.requestMethod == "thread/start"]
          turnStarts = [request | FakeAppServer request <- calls, request.requestMethod == "turn/start"]
      results <-
        sequence
          [ assert "closed scope writes issue snapshot" (length snapshotWrites == 1)
          , assert "closed scope emits completion event" (observedEvent == Just IssuePlanningScopeCompleted)
          , assert "closed scope reaches complete phase" (observedPhase == Just Complete)
          , assert "closed scope does not start planner thread" (null threadStarts)
          , assert "closed scope does not start planner turn" (null turnStarts)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic planning closed scope: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

automaticDaemonLoopPlanningIssueCreationRequestsReplanning :: IO Bool
automaticDaemonLoopPlanningIssueCreationRequestsReplanning = do
  let repo = RepoName "soulomoon/mlf2"
      issueRequest = IssueCreationRequest "Subissue A" "Split from parent" Nothing
      plannerOutput =
        jsonText
          ( object
              [ "outcome" .= ("complete" :: Text)
              , "issues_to_create" .= [issueRequest]
              ]
          )
  (executor, getCalls) <-
    fakeActionExecutorWith
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "turns"
                    .= [ object
                          [ "id" .= ("turn-plan" :: Text)
                          , "status" .= ("completed" :: Text)
                          , "output" .= plannerOutput
                          ]
                       ]
                ]
            else defaultFakeAppServer request
      )
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 125
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      loopConfig = DaemonLoopConfig options (Just (ThreadId "planner-thread"))
      events =
        [ IssuePlanningInitialized (PlannerConfig repo (maxParallelForTest 8) [])
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "turn-plan")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          actions = fmap actionExecutionAction tick.loopActionReports
      results <-
        sequence
          [ assert "planning issue creation reads active planner turn" (length [() | FakeAppServer request <- calls, request.requestMethod == "thread/read"] == 1)
          , assert "planning issue creation emits request event" (observedEvent == Just (IssuePlanningIssuesRequested (issueRequest :| [])))
          , assert "planning issue creation returns to planning ready" (maybe False ((== Initialized) . somePhase . daemonObservedState) tick.loopObservedTick)
          , assert "planning issue creation plans gh issue create" (PlannedCommand (GhIssueCreate repo issueRequest) `elem` actions)
          , assert "planning issue creation does not trigger fanout boundary" (maybe True (not . issuePlanningCompletionEvent) observedEvent)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic planning issue creation: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

automaticDaemonLoopPlanningGraphWaitsAndRecords :: IO Bool
automaticDaemonLoopPlanningGraphWaitsAndRecords = do
  let repo = RepoName "soulomoon/mlf2"
      graph =
        PlanningGraph
          [IssueNumber 15]
          [BlockedPlanningIssue (IssueNumber 16) [IssueNumber 15] "wait"]
          [IssueDependency (IssueNumber 16) [IssueNumber 15]]
      plannerOutput = jsonText (toJSON graph)
  (executor, getCalls) <-
    fakeActionExecutorWith
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "turns"
                    .= [ object
                          [ "id" .= ("turn-plan" :: Text)
                          , "status" .= ("completed" :: Text)
                          , "output" .= plannerOutput
                          ]
                       ]
                ]
            else defaultFakeAppServer request
      )
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 126
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options (Just (ThreadId "planner-thread"))
      events =
        [ IssuePlanningInitialized (PlannerConfig repo (maxParallelForTest 8) [])
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "turn-plan")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          expectedPath = runtimeStateDirFile runtimeConfig.effectRuntimeStateDir "planning-state.json"
      results <-
        sequence
          [ assert "planning graph emits graph update event" (observedEvent == Just (IssuePlanningGraphUpdated graph))
          , assert "planning graph waits for ready issues" (maybe False ((== Initialized) . somePhase . daemonObservedState) tick.loopObservedTick)
          , assert "planning graph writes graph state" (FakeWriteJson expectedPath (toJSON graph) `elem` calls)
          , assert "planning graph sleeps instead of stopping" (FakeSleep `elem` calls && not (FakeStop `elem` calls))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic planning graph: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

automaticDaemonLoopPlanningGraphDropsClosedDependencies :: IO Bool
automaticDaemonLoopPlanningGraphDropsClosedDependencies = do
  let repo = RepoName "soulomoon/mlf2"
      graph =
        PlanningGraph
          [IssueNumber 28]
          [BlockedPlanningIssue (IssueNumber 12) [IssueNumber 26, IssueNumber 27, IssueNumber 28] "wait for remaining sub-issue"]
          [ IssueDependency (IssueNumber 28) [IssueNumber 26, IssueNumber 27]
          , IssueDependency (IssueNumber 12) [IssueNumber 26, IssueNumber 27, IssueNumber 28]
          ]
      normalizedGraph =
        PlanningGraph
          [IssueNumber 28]
          [BlockedPlanningIssue (IssueNumber 12) [IssueNumber 28] "wait for remaining sub-issue"]
          [ IssueDependency (IssueNumber 28) []
          , IssueDependency (IssueNumber 12) [IssueNumber 28]
          ]
      plannerOutput = jsonText (toJSON graph)
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhIssueView _ issue _ ->
            jsonCommandReport (object ["state" .= issueState issue, "closed" .= issueClosed issue])
          command -> defaultFakeCommand command
      )
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "turns"
                    .= [ object
                          [ "id" .= ("turn-plan" :: Text)
                          , "status" .= ("completed" :: Text)
                          , "output" .= plannerOutput
                          ]
                       ]
                ]
            else defaultFakeAppServer request
      )
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 127
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options (Just (ThreadId "planner-thread"))
      events =
        [ IssuePlanningInitialized (PlannerConfig repo (maxParallelForTest 8) [IssueNumber 12, IssueNumber 26, IssueNumber 27, IssueNumber 28])
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "turn-plan")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
      results <-
        sequence
          [ assert "planning graph drops closed dependencies before validation" (observedEvent == Just (IssuePlanningGraphUpdated normalizedGraph))
          , assert "planning graph queries closed dependency issues" (FakeCommand (GhIssueView repo (IssueNumber 26) ["state", "closed", "url"]) `elem` calls && FakeCommand (GhIssueView repo (IssueNumber 27) ["state", "closed", "url"]) `elem` calls)
          , assert "planning graph stays non-terminal after closed dependency filtering" (maybe False ((== Initialized) . somePhase . daemonObservedState) tick.loopObservedTick)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic planning graph closed dependency filtering: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  issueClosed issue =
    issue `elem` [IssueNumber 26, IssueNumber 27]
  issueState issue =
    if issueClosed issue then ("CLOSED" :: Text) else "OPEN"

automaticDaemonLoopPlanningGraphCanonicalizesOpenScopeCoverage :: IO Bool
automaticDaemonLoopPlanningGraphCanonicalizesOpenScopeCoverage = do
  let repo = RepoName "soulomoon/mlf2"
      candidateGraph =
        PlanningGraph
          []
          []
          [ IssueDependency (IssueNumber 27) []
          , IssueDependency (IssueNumber 28) []
          , IssueDependency (IssueNumber 12) []
          ]
      expectedGraph =
        PlanningGraph
          [IssueNumber 12]
          []
          [IssueDependency (IssueNumber 12) []]
      plannerOutput = jsonText (toJSON candidateGraph)
  (executor, getCalls) <-
    fakeActionExecutorWith
      planningSnapshotCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "turns"
                    .= [ object
                          [ "id" .= ("turn-plan" :: Text)
                          , "status" .= ("completed" :: Text)
                          , "output" .= plannerOutput
                          ]
                       ]
                ]
            else defaultFakeAppServer request
      )
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 126
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options (Just (ThreadId "planner-thread"))
      events =
        [ IssuePlanningInitialized (PlannerConfig repo (maxParallelForTest 8) [IssueNumber 12, IssueNumber 26, IssueNumber 27, IssueNumber 28])
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "turn-plan")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
      results <-
        sequence
          [ assert "canonical planning graph restores open root as ready" (observedEvent == Just (IssuePlanningGraphUpdated expectedGraph))
          , assert "canonical planning graph records normalized state" (FakeWriteJson (runtimeStateDirFile runtimeConfig.effectRuntimeStateDir "planning-state.json") (toJSON expectedGraph) `elem` calls)
          , assert "canonical planning graph fetches scoped issue snapshot" (fetchedIssue (IssueNumber 12) calls && fetchedSubIssues (IssueNumber 12) calls)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic planning graph canonical coverage: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  planningSnapshotCommand = \case
    RawCommand "gh" ["issue", "view", issue, "--repo", "soulomoon/mlf2", "--json", _] Nothing ->
      jsonCommandReport (issueJson (IssueNumber (read issue)))
    RawCommand "gh" ["api", path, "--paginate", "--jq", _] Nothing
      | Just issue <- subIssuePathIssue path ->
          jsonCommandReport (toJSON (subIssueJsons issue))
    command -> defaultFakeCommand command
  issueJson issue =
    object
      [ "number" .= unIssueNumber issue
      , "title" .= ("Issue " <> Text.pack (show (unIssueNumber issue)) :: Text)
      , "state" .= issueState issue
      , "closed" .= issueClosed issue
      , "body" .= ("" :: Text)
      , "url" .= ("https://github.com/soulomoon/mlf2/issues/" <> Text.pack (show (unIssueNumber issue)) :: Text)
      , "labels" .= ([] :: [Value])
      , "assignees" .= ([] :: [Value])
      ]
  subIssueJsons (IssueNumber 12) =
    [ subIssueJson (IssueNumber 26)
    , subIssueJson (IssueNumber 27)
    , subIssueJson (IssueNumber 28)
    ]
  subIssueJsons _ =
    []
  subIssueJson issue =
    object
      [ "number" .= unIssueNumber issue
      , "title" .= ("Issue " <> Text.pack (show (unIssueNumber issue)) :: Text)
      , "state" .= issueState issue
      , "closed" .= issueClosed issue
      , "body" .= ("" :: Text)
      , "url" .= ("https://github.com/soulomoon/mlf2/issues/" <> Text.pack (show (unIssueNumber issue)) :: Text)
      , "parentIssueNumber" .= (12 :: Int)
      ]
  issueClosed (IssueNumber 12) = False
  issueClosed _ = True
  issueState issue =
    if issueClosed issue then ("CLOSED" :: Text) else "OPEN"
  subIssuePathIssue path =
    case Text.splitOn "/" (Text.pack path) of
      ["repos", "soulomoon", "mlf2", "issues", issueText, "sub_issues"] ->
        IssueNumber <$> readMaybeText issueText
      _ -> Nothing
  readMaybeText text =
    case reads (Text.unpack text) of
      [(number, "")] -> Just number
      _ -> Nothing
  fetchedIssue issue calls =
    FakeCommand (RawCommand "gh" ["issue", "view", show (unIssueNumber issue), "--repo", "soulomoon/mlf2", "--json", "number,title,state,closed,body,url,labels,assignees,createdAt,updatedAt"] Nothing) `elem` calls
  fetchedSubIssues issue calls =
    any (matchesSubIssueFetch issue) calls
  matchesSubIssueFetch issue = \case
    FakeCommand (RawCommand "gh" ["api", path, "--paginate", "--jq", _] Nothing) ->
      path == "repos/soulomoon/mlf2/issues/" <> show (unIssueNumber issue) <> "/sub_issues"
    _ -> False

automaticDaemonLoopExecutePrestartsTurnOnce :: IO Bool
automaticDaemonLoopExecutePrestartsTurnOnce = do
  (executor, getCalls) <- fakeActionExecutor
  let runtimeConfig = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 130
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
      events =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssuePullRequestReusedEvent (PrNumber 7)
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let expectedEvent = IssuePlanTurnStartedEvent (TurnId "turn-started")
      results <-
        sequence
          [ assert "automatic execute prestarts app-server turn once" (length [() | FakeAppServer request <- calls, request.requestMethod == "turn/start"] == 1)
          , assert "automatic execute appends returned turn event" (FakeAppendJsonLine "/tmp/events.jsonl" (toJSON expectedEvent) `elem` calls)
          , assert "automatic execute reaches plan mode" (maybe False ((== PlanMode) . somePhase . daemonObservedState) tick.loopObservedTick)
          , assert "automatic execute reports cached start action" (length tick.loopActionReports == 1)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic execute prestart: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

automaticDaemonLoopActiveTurnCompletionObservesOutput :: IO Bool
automaticDaemonLoopActiveTurnCompletionObservesOutput = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "turns"
                    .= [ object
                          [ "id" .= ("turn-plan" :: Text)
                          , "status" .= ("completed" :: Text)
                          , "output" .= ("{\"outcome\":\"complete\",\"reason\":\"\",\"summary\":\"plan ready\",\"plan_markdown\":\"Implement the issue in small verified steps.\"}" :: Text)
                          ]
                       ]
                ]
            else defaultFakeAppServer request
      )
  let runtimeConfig = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 140
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
      events =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssuePullRequestReusedEvent (PrNumber 7)
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      results <-
        sequence
          [ assert "automatic active turn reads app-server thread" (length [() | FakeAppServer request <- calls, request.requestMethod == "thread/read"] == 1)
          , assert "automatic active turn emits plan-completed event" (maybe False ((== IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing) . daemonObservedEvent) tick.loopObservedTick)
          , assert "automatic active turn reaches implementation setup" (maybe False ((== Implementing) . somePhase . daemonObservedState) tick.loopObservedTick)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic active turn completion: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

automaticDaemonLoopActiveTurnSystemErrorBlocksWatcher :: IO Bool
automaticDaemonLoopActiveTurnSystemErrorBlocksWatcher = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "thread"
                    .= object
                      [ "status" .= object ["type" .= ("systemError" :: Text)]
                      , "turns"
                          .= [ object
                                [ "id" .= ("turn-plan" :: Text)
                                , "status" .= ("completed" :: Text)
                                ]
                             ]
                      ]
                ]
            else defaultFakeAppServer request
      )
  let runtimeConfig = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 141
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
      expectedReason = BlockedReason "app-server thread entered systemError: systemError"
      events =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssuePullRequestReusedEvent (PrNumber 7)
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      results <-
        sequence
          [ assert "automatic active turn still reads app-server thread on systemError" (length [() | FakeAppServer request <- calls, request.requestMethod == "thread/read"] == 1)
          , assert "automatic active turn blocks watcher on systemError thread" ((daemonObservedEvent <$> tick.loopObservedTick) == Just (WatcherBlocked expectedReason))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic active turn systemError: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

automaticPlanningSystemErrorRetriesWatcher :: IO Bool
automaticPlanningSystemErrorRetriesWatcher = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "thread"
                    .= object
                      [ "status" .= object ["type" .= ("systemError" :: Text)]
                      , "turns"
                          .= [ object
                                [ "id" .= ("planner-turn" :: Text)
                                , "status" .= ("completed" :: Text)
                                ]
                             ]
                      ]
                ]
            else defaultFakeAppServer request
      )
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 142
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      expectedEvent = IssuePlanningTurnRetryRequested (BlockedReason "retrying planner turn after app-server systemError: systemError")
      events =
        [ IssuePlanningInitialized (PlannerConfig repo (maxParallelForTest 1) [])
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      results <-
        sequence
          [ assert "planning systemError still reads active planner turn" (length [() | FakeAppServer request <- calls, request.requestMethod == "thread/read"] == 1)
          , assert "planning systemError retries instead of blocking" ((daemonObservedEvent <$> tick.loopObservedTick) == Just expectedEvent)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL planning systemError retry: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

automaticPlanningSystemErrorBlocksAfterRetryLimit :: IO Bool
automaticPlanningSystemErrorBlocksAfterRetryLimit = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "thread"
                    .= object
                      [ "status" .= object ["type" .= ("systemError" :: Text)]
                      , "turns"
                          .= [ object
                                [ "id" .= ("planner-turn-2" :: Text)
                                , "status" .= ("completed" :: Text)
                                ]
                             ]
                      ]
                ]
            else defaultFakeAppServer request
      )
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 143
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      expectedReason = BlockedReason "app-server thread entered systemError: systemError"
      events =
        [ IssuePlanningInitialized (PlannerConfig repo (maxParallelForTest 1) [])
        , IssuePlanningTurnStarted (ThreadId "planner-thread-1") (TurnId "planner-turn-1")
        , IssuePlanningTurnRetryRequested (BlockedReason "retrying planner turn after app-server systemError: systemError")
        , IssuePlanningTurnStarted (ThreadId "planner-thread-2") (TurnId "planner-turn-2")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      results <-
        sequence
          [ assert "planning systemError still reads active planner turn after retry" (length [() | FakeAppServer request <- calls, request.requestMethod == "thread/read"] == 1)
          , assert "planning systemError blocks after retry limit" ((daemonObservedEvent <$> tick.loopObservedTick) == Just (WatcherBlocked expectedReason))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL planning systemError retry limit: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

automaticDaemonLoopWritesPlanBeforePlanCompletedEvent :: IO Bool
automaticDaemonLoopWritesPlanBeforePlanCompletedEvent = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "turns"
                    .= [ object
                          [ "id" .= ("turn-plan" :: Text)
                          , "status" .= ("completed" :: Text)
                          , "output" .= ("{\"outcome\":\"complete\",\"reason\":\"\",\"summary\":\"plan ready\",\"plan_markdown\":\"Implement the issue in small verified steps.\"}" :: Text)
                          ]
                       ]
                ]
            else defaultFakeAppServer request
      )
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 142
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      prNumber = PrNumber 7
      events =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssuePullRequestReusedEvent prNumber
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        ]
      expectedEvent = IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
      expectedWrite = FakeWriteText "/tmp/work/.watcher/issue-plan.md" (sampleIssuePlanFile issueConfig prNumber)
      expectedAppend = FakeAppendJsonLine "/tmp/events.jsonl" (toJSON expectedEvent)
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right _tick -> do
      results <-
        sequence
          [ assert "plan file is written before plan-completed event" (callBefore expectedWrite expectedAppend calls)
          , assert "plan-completed event is appended" (expectedAppend `elem` calls)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic plan write before event: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

callBefore :: FakeActionCall -> FakeActionCall -> [FakeActionCall] -> Bool
callBefore expectedFirst expectedSecond =
  go False
 where
  go _sawFirst [] = False
  go sawFirst (call : rest)
    | call == expectedFirst = go True rest
    | call == expectedSecond = sawFirst
    | otherwise = go sawFirst rest

automaticDaemonLoopEmptyPlanMarkdownBlocksBeforePlanCompleted :: IO Bool
automaticDaemonLoopEmptyPlanMarkdownBlocksBeforePlanCompleted = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "turns"
                    .= [ object
                          [ "id" .= ("turn-plan" :: Text)
                          , "status" .= ("completed" :: Text)
                          , "output" .= ("{\"outcome\":\"complete\",\"reason\":\"\",\"summary\":\"plan ready\",\"plan_markdown\":\"\"}" :: Text)
                          ]
                       ]
                ]
            else defaultFakeAppServer request
      )
  let runtimeConfig = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 141
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
      events =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssuePullRequestReusedEvent (PrNumber 7)
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
      results <-
        sequence
          [ assert "empty plan markdown blocks before plan-completed event" (observedEvent == Just (WatcherBlocked (BlockedReason "plan turn completed with empty plan_markdown")))
          , assert "empty plan markdown does not append plan-completed event" (not (any isPlanCompletedAppend calls))
          , assert "empty plan markdown does not update PR body" (not (any isPrBodyUpdate calls))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic empty plan_markdown pre-validation: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isPlanCompletedAppend = \case
    FakeAppendJsonLine _ value -> lookupValue "type" value == Just (String "issue_plan_completed")
    _ -> False
  isPrBodyUpdate = \case
    FakeCommand GhUpdatePullRequestBody {} -> True
    _ -> False

automaticDaemonLoopImplementationCompletionSequencesHandoff :: IO Bool
automaticDaemonLoopImplementationCompletionSequencesHandoff = do
  (executor, _getCalls) <-
    fakeActionExecutorWith
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "turns"
                    .= [ object
                          [ "id" .= ("turn-impl" :: Text)
                          , "status" .= ("completed" :: Text)
                          , "output" .= ("{\"outcome\":\"complete\",\"reason\":\"ready for review\"}" :: Text)
                          ]
                       ]
                ]
            else defaultFakeAppServer request
      )
  let runtimeConfig = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 150
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
      prNumber = PrNumber 7
      baseEvents =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssuePullRequestReusedEvent prNumber
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        , IssuePullRequestBodyUpdatedEvent prNumber
        , IssueImplementationTurnStartedEvent (TurnId "turn-impl")
        ]
      observedEventFor events = do
        result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
        pure $ case result of
          Right tick -> daemonObservedEvent <$> tick.loopObservedTick
          Left _ -> Nothing
  firstEvent <- observedEventFor baseEvents
  secondEvent <- observedEventFor (baseEvents <> [IssueImplementationCompletedEvent prNumber Nothing])
  thirdEvent <- observedEventFor (baseEvents <> [IssueImplementationCompletedEvent prNumber Nothing, IssueReviewHandoffInitializedEvent prNumber])
  fourthEvent <- observedEventFor (baseEvents <> [IssueImplementationCompletedEvent prNumber Nothing, IssueReviewHandoffInitializedEvent prNumber, IssueReviewHandoffStartedEvent prNumber])
  results <-
    sequence
      [ assert "automatic implementation completion records implementation completion first" (firstEvent == Just (IssueImplementationCompletedEvent prNumber Nothing))
      , assert "automatic implementation completion initializes handoff second" (secondEvent == Just (IssueReviewHandoffInitializedEvent prNumber))
      , assert "automatic implementation completion starts handoff third" (thirdEvent == Just (IssueReviewHandoffStartedEvent prNumber))
      , assert "automatic implementation completion waits for PR merge after handoff" (fourthEvent == Nothing)
      ]
  pure (and results)

automaticIssueMergeWaitsForIssueClose :: IO Bool
automaticIssueMergeWaitsForIssueClose = do
  let prNumber = PrNumber 7
      reviewerThread = ThreadId "dry-run-issue-reviewer-thread"
      reviewedCommit = CommitSha "0123456789abcdef"
      reviewerTurn = TurnId "dry-run-issue-final-review-turn-155"
      waitingWithReviewerEvents = issueEvents <> [IssueReviewerThreadReadyEvent reviewerThread]
      postMergeReadyEvents = issueEvents <> [IssuePullRequestMergedEvent prNumber]
      postMergeReviewReadyEvents = postMergeReadyEvents <> [IssueReviewerThreadReadyEvent reviewerThread]
      postMergeReviewingEvents = postMergeReviewReadyEvents <> [IssuePostMergeReviewStartedEvent reviewedCommit reviewerTurn]
      postMergeCleanEvents = postMergeReviewingEvents <> [IssuePostMergeReviewCleanEvent (CleanReviewEvidence reviewedCommit "LGTM")]
  (openTick, openCalls) <- runIssueMergeTickWithCalls issueEvents openPrCommand defaultFakeAppServer
  openIssueRetryTick <- runIssueMergeTick postMergeCleanEvents openIssueCommand defaultFakeAppServer
  openIssueRetryExecuteTick <- runIssueMergeTickWithMode ExecuteActions postMergeCleanEvents openIssueCommand defaultFakeAppServer
  merged <- runIssueMergeCheck issueEvents mergedPrCommand defaultFakeAppServer
  mergedTick <- runIssueMergeTick issueEvents mergedPrCommand defaultFakeAppServer
  mergedWithReviewerTick <- runIssueMergeTick waitingWithReviewerEvents mergedPrCommand defaultFakeAppServer
  reviewerReady <- runIssueMergeCheck postMergeReadyEvents defaultFakeCommand defaultFakeAppServer
  reviewerReadyTick <- runIssueMergeTick postMergeReadyEvents defaultFakeCommand defaultFakeAppServer
  reviewerStarted <- runIssueMergeCheck postMergeReviewReadyEvents mergedPrCommand defaultFakeAppServer
  clean <- runIssueMergeTick postMergeReviewingEvents defaultFakeCommand cleanReviewerAppServer
  closedTick <- runIssueMergeTick postMergeCleanEvents closedIssueCommand defaultFakeAppServer
  closed <- runIssueMergeCheck postMergeCleanEvents closedIssueCommand defaultFakeAppServer
  results <-
    sequence
      [ assert "open PR uses gh pr view and stays idle" (maybe False openPrIdled openTick && any isGhPrViewCall openCalls)
      , assert "merged PR moves issue implementer to post-merge review" (merged == Just (IssuePullRequestMergedEvent prNumber, Implementing))
      , assert "merged PR without reviewer matches indexed projection" (maybe False (indexedPullRequestMergedNoReviewerMatches prNumber) mergedTick)
      , assert "merged PR with existing reviewer matches indexed projection" (maybe False (indexedPullRequestMergedWithReviewerMatches prNumber reviewerThread) mergedWithReviewerTick)
      , assert "merged PR with existing reviewer does not start new reviewer thread" (maybe False noReviewerThreadStartAction mergedWithReviewerTick)
      , assert "post-merge review creates reviewer thread when absent" (reviewerReady == Just (IssueReviewerThreadReadyEvent reviewerThread, Implementing))
      , assert "post-merge reviewer-ready observation matches indexed projection" (maybe False (indexedPostMergeReviewerReadyMatches prNumber reviewerThread) reviewerReadyTick)
      , assert "post-merge review starts reviewer against merged PR head" (reviewerStarted == Just (IssuePostMergeReviewStartedEvent reviewedCommit reviewerTurn, Implementing))
      , assert "clean post-merge review schedules issue close" (maybe False issueCloseScheduled clean)
      , assert "open issue close retry closes before sleeping" (maybe False issueCloseRetryOrdered openIssueRetryTick)
      , assert "open issue close retry stays idle after close command" (maybe False issueCloseRetryIdlesAfterClose openIssueRetryExecuteTick)
      , assert "open issue close retry dry-run renders close command" (maybe False issueCloseRetryDryRunRendersCommand openIssueRetryTick)
      , assert "open issue close retry does not prematurely observe issue closed" (maybe False noPrematureIssueClosedEvent openIssueRetryTick)
      , assert "closed issue completes issue implementer" (closed == Just (IssueClosedEvent prNumber, Complete))
      , assert "closed issue observation matches indexed projection" (maybe False (indexedIssueClosedMatches prNumber) closedTick)
      ]
  pure (and results)
 where
  openPrCommand = \case
      GhPrView {} -> jsonCommandReport (object ["state" .= ("OPEN" :: Text)])
      command -> defaultFakeCommand command
  mergedPrCommand = \case
      GhPrView {} -> jsonCommandReport (object ["state" .= ("MERGED" :: Text), "headRefOid" .= ("0123456789abcdef" :: Text)])
      command -> defaultFakeCommand command
  openIssueCommand = \case
      GhIssueView {} -> jsonCommandReport (object ["state" .= ("OPEN" :: Text), "closed" .= False])
      command -> defaultFakeCommand command
  closedIssueCommand = \case
      GhIssueView {} -> jsonCommandReport (object ["state" .= ("CLOSED" :: Text), "closed" .= True])
      command -> defaultFakeCommand command
  cleanReviewerAppServer request
    | request.requestMethod == "thread/read" =
        object
          [ "turns"
              .= [ object
                    [ "id" .= ("dry-run-issue-final-review-turn-155" :: Text)
                    , "status" .= ("completed" :: Text)
                    , "output" .= issueFinalReviewOutput "clean" (CommitSha "0123456789abcdef") reviewerPromptVersion True True True False ["validated issue and plan"] [] Nothing (Just "LGTM")
                    ]
                 ]
          ]
    | otherwise = defaultFakeAppServer request
  runIssueMergeCheck events commandHandler appServerHandler = do
    tick <- runIssueMergeTick events commandHandler appServerHandler
    pure $ tick >>= \result -> (\observed -> (observed.daemonObservedEvent, somePhase observed.daemonObservedState)) <$> result.loopObservedTick
  runIssueMergeTick events commandHandler appServerHandler = do
    runIssueMergeTickWithMode DryRunActions events commandHandler appServerHandler
  runIssueMergeTickWithMode executionMode events commandHandler appServerHandler = do
    (tick, _calls) <- runIssueMergeTickWithCallsAndMode executionMode events commandHandler appServerHandler
    pure tick
  runIssueMergeTickWithCalls events commandHandler appServerHandler = do
    runIssueMergeTickWithCallsAndMode DryRunActions events commandHandler appServerHandler
  runIssueMergeTickWithCallsAndMode executionMode events commandHandler appServerHandler = do
    (executor, _getCalls) <-
      fakeActionExecutorWith
        commandHandler
        appServerHandler
    let repo = RepoName "soulomoon/mlf2"
        runtimeConfig = effectRuntimeConfig repo "/tmp/work" 155
        options =
          DaemonOptions
            { daemonEventLogPath = "/tmp/events.jsonl"
            , daemonRuntimeConfig = runtimeConfig
            , daemonExecutionMode = executionMode
            }
        loopConfig = DaemonLoopConfig options Nothing
    result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
    calls <- _getCalls
    pure
      ( case result of
          Right tick -> Just tick
          Left _ -> Nothing
      , calls
      )
  issueEvents =
    let issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
     in
          [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
          , IssuePullRequestReusedEvent (PrNumber 7)
          , IssuePlanTurnStartedEvent (TurnId "turn-plan")
          , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
          , IssuePullRequestBodyUpdatedEvent (PrNumber 7)
          , IssueImplementationTurnStartedEvent (TurnId "turn-impl")
          , IssueImplementationCompletedEvent (PrNumber 7) Nothing
          , IssueReviewHandoffInitializedEvent (PrNumber 7)
          , IssueReviewHandoffStartedEvent (PrNumber 7)
          ]
  issueCloseScheduled tick =
    any isGhIssueCloseReport tick.loopActionReports
  isGhIssueCloseReport report =
    case report.actionExecutionAction of
      PlannedCommand GhIssueClose {} -> True
      _ -> False
  issueCloseRetryOrdered tick =
    actionBefore
      (PlannedCommand (GhIssueClose (IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")) (PrNumber 7)))
      PlannedSleepUntilNextPoll
      (fmap actionExecutionAction tick.loopActionReports)
  issueCloseRetryIdlesAfterClose tick =
    tick.loopIdleReason == Just "closed issue after merged PR #7; waiting to observe closed issue"
  issueCloseRetryDryRunRendersCommand tick =
    any rendersExpectedClose tick.loopActionReports
   where
    expectedCommand = GhIssueClose (IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")) (PrNumber 7)
    expectedSpec = renderRuntimeCommand expectedCommand
    rendersExpectedClose report =
      report.actionExecutionMode == DryRunActions
        && report.actionExecutionResult == DryRunActionResult
        && case report.actionExecutionAction of
          PlannedCommand command ->
            command == expectedCommand
              && renderRuntimeCommand command == expectedSpec
          _ -> False
  noPrematureIssueClosedEvent tick =
    case (tick.loopObservation, tick.loopObservedTick) of
      (Nothing, Nothing) -> True
      _ -> False
  actionBefore first second actions =
    case (firstIndex (== first) actions, firstIndex (== second) actions) of
      (Just firstPosition, Just secondPosition) -> firstPosition < secondPosition
      _ -> False
  firstIndex predicate =
    go (0 :: Int)
   where
    go _ [] = Nothing
    go index (value : values)
      | predicate value = Just index
      | otherwise = go (index + 1) values
  openPrIdled tick =
    case tick.loopObservedTick of
      Nothing ->
        tick.loopIdleReason == Just "waiting for PR merge before post-merge review: #7"
      Just _ ->
        False
  isGhPrViewCall = \case
    FakeCommand GhPrView {} -> True
    _ -> False
  noReviewerThreadStartAction tick =
    all (not . isReviewerThreadStartAction . actionExecutionAction) tick.loopActionReports
  isReviewerThreadStartAction = \case
    PlannedAppServerRequest request -> request.requestMethod == "thread/start"
    _ -> False
  indexedPullRequestMergedNoReviewerMatches prNumber tick =
    let issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
        state = SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber (WorkerIdle (ThreadId "worker-thread")) Nothing)
     in case (tick.loopObservedTick, IssueImplementIndexed.projectIssueImplementPullRequestMergedWaitingForPrMergeObservation state prNumber) of
          (Just observed, Right projection) ->
            observed.daemonObservedEvent == projection.issueImplementIndexedProjectionPlanned.plannedEvent
              && sameWatcherStateShape observed.daemonObservedState projection.issueImplementIndexedProjectionFinalState
          _ -> False
  indexedPullRequestMergedWithReviewerMatches prNumber reviewerThread tick =
    let issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
        state = SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber (WorkerIdle (ThreadId "worker-thread")) (Just (ReviewerIdle reviewerThread)))
     in case (tick.loopObservedTick, IssueImplementIndexed.projectIssueImplementPullRequestMergedWaitingForPrMergeObservation state prNumber) of
          (Just observed, Right projection) ->
            observed.daemonObservedEvent == projection.issueImplementIndexedProjectionPlanned.plannedEvent
              && sameWatcherStateShape observed.daemonObservedState projection.issueImplementIndexedProjectionFinalState
          _ -> False
  indexedPostMergeReviewerReadyMatches prNumber reviewerThread tick =
    let issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
        state = SomeWatcherState (IssuePostMergeReviewPendingReviewer issueConfig prNumber (WorkerIdle (ThreadId "worker-thread")))
     in case (tick.loopObservedTick, IssueImplementIndexed.projectIssueImplementReviewerThreadReadyPostMergeReviewPendingReviewerObservation state reviewerThread) of
          (Just observed, Right projection) ->
            observed.daemonObservedEvent == projection.issueImplementIndexedProjectionPlanned.plannedEvent
              && sameWatcherStateShape observed.daemonObservedState projection.issueImplementIndexedProjectionFinalState
          _ -> False
  indexedIssueClosedMatches prNumber tick =
    let issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
        state = SomeWatcherState (IssueWaitingForIssueClose issueConfig prNumber)
     in case (tick.loopObservedTick, IssueImplementIndexed.projectIssueImplementIssueClosedObservation state prNumber) of
          (Just observed, Right projection) ->
            observed.daemonObservedEvent == projection.issueImplementIndexedProjectionPlanned.plannedEvent
              && sameWatcherStateShape observed.daemonObservedState projection.issueImplementIndexedProjectionFinalState
              && fmap effectTag projection.issueImplementIndexedProjectionEffectPlan == [StopDaemonTag]
              && fmap actionExecutionAction observed.daemonObservedActionReports == [PlannedStopDaemon]
          _ -> False

automaticIssueFinalReviewFindingsRequestRework :: IO Bool
automaticIssueFinalReviewFindingsRequestRework = do
  tick <- runIssueMergeTick postMergeReviewingEvents defaultFakeCommand findingsReviewerAppServer
  results <-
    sequence
      [ assert "final review findings emit post-merge follow-up" (maybe False followUpObserved tick)
      , assert "final review findings update issue follow-up" (maybe False issueFollowUpScheduled tick)
      , assert "final review findings do not close issue" (maybe False (not . issueCloseScheduled) tick)
      , assert "final review findings restart implementation on next attempt branch" (maybe False reworkStateObserved tick)
      ]
  pure (and results)
 where
  issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
  prNumber = PrNumber 7
  reviewerThread = ThreadId "dry-run-issue-reviewer-thread"
  reviewedCommit = CommitSha "0123456789abcdef"
  reviewerTurn = TurnId "dry-run-issue-final-review-turn-155"
  finding = "follow-up needed"
  expectedEvidence = reviewEvidenceFromSummaries (finding :| []) reviewedCommit
  postMergeReviewingEvents =
    [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
    , IssuePullRequestReusedEvent prNumber
    , IssuePlanTurnStartedEvent (TurnId "turn-plan")
    , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
    , IssuePullRequestBodyUpdatedEvent prNumber
    , IssueImplementationTurnStartedEvent (TurnId "turn-impl")
    , IssueImplementationCompletedEvent prNumber Nothing
    , IssueReviewHandoffInitializedEvent prNumber
    , IssueReviewHandoffStartedEvent prNumber
    , IssuePullRequestMergedEvent prNumber
    , IssueReviewerThreadReadyEvent reviewerThread
    , IssuePostMergeReviewStartedEvent reviewedCommit reviewerTurn
    ]
  findingsReviewerAppServer request
    | request.requestMethod == "thread/read" =
        object
          [ "turns"
              .= [ object
                    [ "id" .= ("dry-run-issue-final-review-turn-155" :: Text)
                    , "status" .= ("completed" :: Text)
                    , "output" .= issueFinalReviewOutput "rework_required" reviewedCommit reviewerPromptVersion False True True True [] [finding] Nothing (Just "LGTM")
                    ]
                 ]
          ]
    | otherwise = defaultFakeAppServer request
  runIssueMergeTick events commandHandler appServerHandler = do
    (executor, _getCalls) <-
      fakeActionExecutorWith
        commandHandler
        appServerHandler
    let runtimeConfig = effectRuntimeConfig issueConfig.issueRepo "/tmp/work" 155
        options =
          DaemonOptions
            { daemonEventLogPath = "/tmp/events.jsonl"
            , daemonRuntimeConfig = runtimeConfig
            , daemonExecutionMode = DryRunActions
            }
        loopConfig = DaemonLoopConfig options Nothing
    result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
    pure case result of
      Right tick -> Just tick
      Left _ -> Nothing
  followUpObserved tick =
    (daemonObservedEvent <$> tick.loopObservedTick) == Just (IssuePostMergeReviewFollowUpEvent expectedEvidence)
  reworkStateObserved tick =
    case daemonObservedState <$> tick.loopObservedTick of
      Just (SomeWatcherState (IssueImplementationReady followUpConfig Nothing (WorkerIdle returnedWorker))) ->
        followUpConfig.issueRepo == issueConfig.issueRepo
          && followUpConfig.issueNumber == issueConfig.issueNumber
          && unBranchName followUpConfig.issueBranch == "codex/issue-42-2"
          && returnedWorker == ThreadId "worker-thread"
      _ -> False
  issueFollowUpScheduled tick =
    any isGhIssueFollowUpReport tick.loopActionReports
  issueCloseScheduled tick =
    any isGhIssueCloseReport tick.loopActionReports
  isGhIssueFollowUpReport report =
    case report.actionExecutionAction of
      PlannedCommand GhIssueFollowUp {} -> True
      _ -> False
  isGhIssueCloseReport report =
    case report.actionExecutionAction of
      PlannedCommand GhIssueClose {} -> True
      _ -> False

automaticIssueFollowUpRefreshesWorkerBeforePlanTurn :: IO Bool
automaticIssueFollowUpRefreshesWorkerBeforePlanTurn = do
  (executor, getCalls) <- fakeActionExecutorWith defaultFakeCommand defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig issueConfig.issueRepo "/tmp/work" 156
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          observedState = daemonObservedState <$> tick.loopObservedTick
          threadStarts = [request | FakeAppServer request <- calls, request.requestMethod == "thread/start"]
          turnStarts = [request | FakeAppServer request <- calls, request.requestMethod == "turn/start"]
      results <-
        sequence
          [ assert "issue follow-up refreshes worker thread before plan" (observedEvent == Just (IssueWorkerThreadRefreshed (ThreadId "thread-started")))
          , assert "issue follow-up keeps ready-to-plan state with fresh worker" (freshReadyToPlan observedState)
          , assert "issue follow-up refresh tick matches indexed projection" (indexedRefreshMatches tick.loopObservedTick)
          , assert "issue follow-up starts one replacement worker thread" (length threadStarts == 1)
          , assert "issue follow-up does not start a plan turn on stale worker" (null turnStarts)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL issue follow-up refresh worker: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
  prNumber = PrNumber 7
  followUpPrNumber = PrNumber 8
  oldWorker = ThreadId "stale-worker"
  reviewedCommit = CommitSha "0123456789abcdef"
  evidence = reviewEvidenceFromSummaries ("add IR golden tests" :| []) reviewedCommit
  events =
    [ IssueImplementInitialized issueConfig oldWorker
    , IssuePullRequestCreatedEvent prNumber
    , IssuePlanTurnStartedEvent (TurnId "turn-plan")
    , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
    , IssuePullRequestBodyUpdatedEvent prNumber
    , IssueImplementationTurnStartedEvent (TurnId "turn-impl")
    , IssueImplementationCompletedEvent prNumber Nothing
    , IssueReviewHandoffInitializedEvent prNumber
    , IssueReviewHandoffStartedEvent prNumber
    , IssuePullRequestMergedEvent prNumber
    , IssueReviewerThreadReadyEvent (ThreadId "reviewer-thread")
    , IssuePostMergeReviewStartedEvent reviewedCommit (TurnId "final-review")
    , IssuePostMergeReviewFollowUpEvent evidence
    , IssuePullRequestCreatedEvent followUpPrNumber
    ]
  freshReadyToPlan = \case
    Just (SomeWatcherState (IssueReadyToPlan observedConfig observedPrNumber (WorkerIdle workerThread))) ->
      observedConfig.issueRepo == issueConfig.issueRepo
        && observedConfig.issueNumber == issueConfig.issueNumber
        && unBranchName observedConfig.issueBranch == "codex/issue-42-2"
        && observedPrNumber == followUpPrNumber
        && workerThread == ThreadId "thread-started"
    _ ->
      False
  followUpConfig = IssueConfig issueConfig.issueRepo issueConfig.issueNumber (BranchName "codex/issue-42-2")
  readyToPlanState = SomeWatcherState (IssueReadyToPlan followUpConfig followUpPrNumber (WorkerIdle oldWorker))
  indexedRefreshMatches = \case
    Just observed ->
      case IssueImplementIndexed.projectIssueImplementWorkerThreadRefreshedReadyToPlanObservation readyToPlanState (ThreadId "thread-started") of
        Right projection ->
          observed.daemonObservedEvent == projection.issueImplementIndexedProjectionPlanned.plannedEvent
            && sameWatcherStateShape observed.daemonObservedState projection.issueImplementIndexedProjectionFinalState
        Left _ ->
          False
    Nothing ->
      False

automaticStalePlanningTurnRetriesAfterThreeMisses :: IO Bool
automaticStalePlanningTurnRetriesAfterThreeMisses = do
  (executor, getCalls) <-
    fakeActionExecutorWithJsonStore
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then object ["turns" .= ([] :: [Value])]
            else defaultFakeAppServer request
      )
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 156
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events =
        [ IssuePlanningInitialized (PlannerConfig repo (maxParallelForTest 1) [])
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "missing-turn")
        ]
      runOnce = runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  first <- runOnce
  second <- runOnce
  third <- runOnce
  calls <- getCalls
  let eventOf result =
        case result of
          Right tick -> daemonObservedEvent <$> tick.loopObservedTick
          Left _ -> Nothing
      markerWrites =
        [ value
        | FakeWriteJson path value <- calls
        , path == "/tmp/work/.watcher/stale-active-turn.json"
        ]
  results <-
    sequence
      [ assert "first missing active turn idles" (eventOf first == Nothing)
      , assert "second missing active turn idles" (eventOf second == Nothing)
      , assert
          "third missing planner turn retries"
          ( eventOf third
              == Just (IssuePlanningTurnRetryRequested (BlockedReason "active turn not found after 3 consecutive checks: missing-turn"))
          )
      , assert "stale active turn marker is persisted" (not (null markerWrites))
      , assert "stale active turn marker is cleared on retry" (last markerWrites == Null)
      ]
  pure (and results)

automaticDaemonLoopRetriesPrCreateWhileWaitingForPr :: IO Bool
automaticDaemonLoopRetriesPrCreateWhileWaitingForPr = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhPrListOpen {} -> CommandReport {ok = True, status = Just 0, stdout = "[]", stderr = "", errorMessage = Nothing}
          GhPrListByHead {} -> CommandReport {ok = True, status = Just 0, stdout = "[]", stderr = "", errorMessage = Nothing}
          command@GhCreatePullRequest {} -> (defaultFakeCommand command) {stdout = "{\"status\":\"created\",\"prNumber\":7}"}
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 160
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      events =
        [IssueImplementInitialized issueConfig (ThreadId "worker-thread")]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      results <-
        sequence
          [ assert "missing PR retry records created PR" ((daemonObservedEvent <$> tick.loopObservedTick) == Just (IssuePullRequestCreatedEvent (PrNumber 7)))
          , assert "missing PR retry tick matches indexed projection" (indexedPrCreatedMatches issueConfig (PrNumber 7) tick.loopObservedTick)
          , assert "missing PR retry checks open PRs" (FakeCommand (GhPrListOpen repo) `elem` calls)
          , assert "missing PR retry re-runs create PR" (FakeCommand (GhCreatePullRequest "/tmp/work" issueConfig) `elem` calls)
          , assert "missing PR retry sleeps after create attempt" (FakeSleep `elem` calls)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic PR retry: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

automaticDaemonLoopAdvancesMergedAttemptBranchBeforePrCreate :: IO Bool
automaticDaemonLoopAdvancesMergedAttemptBranchBeforePrCreate = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhPrListOpen {} ->
            jsonCommandReport (toJSON ([] :: [Value]))
          GhPrListByHead _repo branch "all"
            | branch == oldBranch ->
                jsonCommandReport
                  ( toJSON
                      [ object
                          [ "number" .= (6 :: Int)
                          , "title" .= ("Old merged attempt" :: Text)
                          , "headRefName" .= unBranchName oldBranch
                          , "headRefOid" .= ("abc123" :: Text)
                          , "closingIssuesReferences" .= [object ["number" .= (42 :: Int)]]
                          , "body" .= ("Closes #42" :: Text)
                          , "state" .= ("MERGED" :: Text)
                          ]
                      ]
                  )
            | branch == nextBranch ->
                jsonCommandReport (toJSON ([] :: [Value]))
          command@GhCreatePullRequest {} ->
            (defaultFakeCommand command) {stdout = "{\"status\":\"created\",\"prNumber\":7}"}
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let runtimeConfig = effectRuntimeConfig repo "/tmp/work" 160
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      events = [IssueImplementInitialized oldIssueConfig (ThreadId "worker-thread")]
  first <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  second <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig (events <> [IssueAttemptBranchAdvancedEvent nextBranch])
  calls <- getCalls
  case (first, second) of
    (Right firstTick, Right secondTick) -> do
      results <-
        sequence
          [ assert "merged old branch advances attempt branch" ((daemonObservedEvent <$> firstTick.loopObservedTick) == Just (IssueAttemptBranchAdvancedEvent nextBranch))
          , assert "merged old branch advance tick matches indexed projection" (indexedBranchAdvanceMatches firstTick.loopObservedTick)
          , assert "merged old branch does not create PR on advance tick" (FakeCommand (GhCreatePullRequest "/tmp/work" oldIssueConfig) `notElem` calls)
          , assert "advanced branch creates next PR" ((daemonObservedEvent <$> secondTick.loopObservedTick) == Just (IssuePullRequestCreatedEvent (PrNumber 7)))
          , assert "advanced branch create tick matches indexed projection" (indexedPrCreatedMatches nextIssueConfig (PrNumber 7) secondTick.loopObservedTick)
          , assert "advanced branch is used for new PR creation" (FakeCommand (GhCreatePullRequest "/tmp/work" nextIssueConfig) `elem` calls)
          ]
      pure (and results)
    (Left failure, _) -> do
      putStrLn ("FAIL automatic merged branch advance first tick: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
    (_, Left failure) -> do
      putStrLn ("FAIL automatic merged branch advance second tick: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  repo = RepoName "soulomoon/mlf2"
  oldBranch = BranchName "codex/issue-42"
  nextBranch = BranchName "codex/issue-42-2"
  oldIssueConfig = IssueConfig repo (IssueNumber 42) oldBranch
  nextIssueConfig = IssueConfig repo (IssueNumber 42) nextBranch
  indexedBranchAdvanceMatches = \case
    Just observed ->
      let state = SomeWatcherState (IssueImplementationReady oldIssueConfig Nothing (WorkerIdle (ThreadId "worker-thread")))
       in case IssueImplementIndexed.projectIssueImplementAttemptBranchAdvancedObservation state nextBranch of
            Right projection ->
              observed.daemonObservedEvent == projection.issueImplementIndexedProjectionPlanned.plannedEvent
                && sameWatcherStateShape observed.daemonObservedState projection.issueImplementIndexedProjectionFinalState
            Left _ -> False
    Nothing -> False

automaticDaemonLoopBlocksUnlinkedBranchPr :: IO Bool
automaticDaemonLoopBlocksUnlinkedBranchPr = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhPrListOpen {} ->
            jsonCommandReport
              ( toJSON
                  [ object
                      [ "number" .= (8 :: Int)
                      , "title" .= ("Unrelated PR" :: Text)
                      , "headRefName" .= ("codex/issue-42" :: Text)
                      , "headRefOid" .= ("abc123" :: Text)
                      , "closingIssuesReferences" .= ([] :: [Value])
                      , "body" .= ("Refs #99" :: Text)
                      ]
                  ]
              )
          GhPrView {} ->
            jsonCommandReport
              ( object
                  [ "closingIssuesReferences" .= ([] :: [Value])
                  , "body" .= ("Refs #99" :: Text)
                  ]
              )
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 160
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      expectedReason = BlockedReason "open PR #8 already uses branch codex/issue-42 but is not linked to issue #42"
      events =
        [IssueImplementInitialized issueConfig (ThreadId "worker-thread")]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      results <-
        sequence
          [ assert "unlinked branch PR blocks watcher" ((daemonObservedEvent <$> tick.loopObservedTick) == Just (WatcherBlocked expectedReason))
          , assert "unlinked branch PR checks open PRs" (FakeCommand (GhPrListOpen repo) `elem` calls)
          , assert "unlinked branch PR validates exact PR link" (FakeCommand (GhPrView repo (PrNumber 8) ["body", "closingIssuesReferences"]) `elem` calls)
          , assert "unlinked branch PR does not create PR" (FakeCommand (GhCreatePullRequest "/tmp/work" issueConfig) `notElem` calls)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic unlinked branch PR block: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

indexedPrCreatedMatches :: IssueConfig -> PrNumber -> Maybe DaemonObservedTickResult -> Bool
indexedPrCreatedMatches issueConfig prNumber = \case
  Just observed ->
    let state = SomeWatcherState (IssueImplementationReady issueConfig Nothing (WorkerIdle (ThreadId "worker-thread")))
     in case IssueImplementIndexed.projectIssueImplementPullRequestCreatedImplementationReadyObservation state prNumber of
          Right projection ->
            observed.daemonObservedEvent == projection.issueImplementIndexedProjectionPlanned.plannedEvent
              && sameWatcherStateShape observed.daemonObservedState projection.issueImplementIndexedProjectionFinalState
          Left _ -> False
  Nothing ->
    False

indexedPrBodyUpdateMatches :: IssueConfig -> PrNumber -> Maybe DaemonObservedTickResult -> Bool
indexedPrBodyUpdateMatches issueConfig prNumber = \case
  Just observed ->
    let state = SomeWatcherState (IssuePlanReady issueConfig prNumber (WorkerIdle (ThreadId "worker-thread")))
     in case IssueImplementIndexed.projectIssueImplementPullRequestBodyUpdatedPlanReadyObservation state prNumber of
          Right projection ->
            observed.daemonObservedEvent == projection.issueImplementIndexedProjectionPlanned.plannedEvent
              && sameWatcherStateShape observed.daemonObservedState projection.issueImplementIndexedProjectionFinalState
          Left _ -> False
  Nothing ->
    False

automaticDaemonLoopUpdatesNewPrBodyBeforeImplementation :: IO Bool
automaticDaemonLoopUpdatesNewPrBodyBeforeImplementation =
  automaticDaemonLoopUpdatesPrBodyBeforeImplementation "new PR" IssuePullRequestCreatedEvent

automaticDaemonLoopUpdatesReusedPrBodyBeforeImplementation :: IO Bool
automaticDaemonLoopUpdatesReusedPrBodyBeforeImplementation =
  automaticDaemonLoopUpdatesPrBodyBeforeImplementation "reused PR" IssuePullRequestReusedEvent

automaticDaemonLoopUpdatesPrBodyBeforeImplementation :: String -> (PrNumber -> WatcherEvent) -> IO Bool
automaticDaemonLoopUpdatesPrBodyBeforeImplementation caseName prEvent = do
  (executor, getCalls) <- fakeActionExecutor
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 161
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      prNumber = PrNumber 7
      events =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , prEvent prNumber
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        ]
      expectedCommand = GhUpdatePullRequestBody "/tmp/work" issueConfig prNumber "/tmp/work/.watcher/issue-plan.md"
      expectedWrite = FakeWriteText "/tmp/work/.watcher/issue-plan.md" (sampleIssuePlanFile issueConfig prNumber)
      expectedAppend = FakeAppendJsonLine "/tmp/events.jsonl" (toJSON (IssuePullRequestBodyUpdatedEvent prNumber))
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      results <-
        sequence
          [ assert (caseName <> " body update emits event") ((daemonObservedEvent <$> tick.loopObservedTick) == Just (IssuePullRequestBodyUpdatedEvent prNumber))
          , assert (caseName <> " body update tick matches indexed projection") (indexedPrBodyUpdateMatches issueConfig prNumber tick.loopObservedTick)
          , assert (caseName <> " body update writes plan before command") (callBefore expectedWrite (FakeCommand expectedCommand) calls)
          , assert (caseName <> " body update writes plan before event append") (callBefore expectedWrite expectedAppend calls)
          , assert (caseName <> " body update command is scheduled") (FakeCommand expectedCommand `elem` calls)
          , assert (caseName <> " body update does not start implementation yet") (not (any isTurnStartCall calls))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic PR body update (" <> caseName <> "): " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isTurnStartCall = \case
    FakeAppServer request -> request.requestMethod == "turn/start"
    _ -> False

automaticDaemonLoopStartsImplementationAfterPrBodyUpdate :: IO Bool
automaticDaemonLoopStartsImplementationAfterPrBodyUpdate = do
  (executor, getCalls) <- fakeActionExecutor
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 162
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      prNumber = PrNumber 7
      events =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssuePullRequestCreatedEvent prNumber
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        , IssuePullRequestBodyUpdatedEvent prNumber
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let actions = fmap actionExecutionAction tick.loopActionReports
      results <-
        sequence
          [ assert "body-updated PR starts implementation" ((daemonObservedEvent <$> tick.loopObservedTick) == Just (IssueImplementationTurnStartedEvent (TurnId "turn-started")))
          , assert "body-updated PR start tick matches indexed projection" (indexedImplementationTurnStartMatches issueConfig prNumber (TurnId "turn-started") tick.loopObservedTick)
          , assert "body-updated PR schedules implementation worker turn" (any isTurnStartAction actions)
          , assert "body-updated PR advances app-server request id" (maybe False (\observed -> observed.daemonObservedCompiledEffects.compiledNextRequestId == RequestId 163) tick.loopObservedTick)
          , assert "body-updated PR does not update body again" (FakeCommand (GhUpdatePullRequestBody "/tmp/work" issueConfig prNumber "/tmp/work/.watcher/issue-plan.md") `notElem` calls)
          , assert "body-updated PR starts app-server turn" (any isTurnStartCall calls)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic implementation start after PR body update: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isTurnStartAction = \case
    PlannedAppServerRequest request -> request.requestMethod == "turn/start" && request.requestId == RequestId 162
    _ -> False
  isTurnStartCall = \case
    FakeAppServer request -> request.requestMethod == "turn/start"
    _ -> False

indexedImplementationTurnStartMatches :: IssueConfig -> PrNumber -> TurnId -> Maybe DaemonObservedTickResult -> Bool
indexedImplementationTurnStartMatches issueConfig prNumber turnId = \case
  Just observed ->
    let state = SomeWatcherState (IssueImplementationReady issueConfig (Just prNumber) (WorkerIdle (ThreadId "worker-thread")))
     in case IssueImplementIndexed.projectIssueImplementationTurnStartedObservation state turnId of
          Right projection ->
            observed.daemonObservedEvent == projection.issueImplementIndexedProjectionPlanned.plannedEvent
              && sameWatcherStateShape observed.daemonObservedState projection.issueImplementIndexedProjectionFinalState
          Left _ -> False
  Nothing ->
    False

automaticDaemonLoopIncompleteImplementationRestartsWorker :: IO Bool
automaticDaemonLoopIncompleteImplementationRestartsWorker = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "turns"
                    .= [ object
                          [ "id" .= ("turn-impl" :: Text)
                          , "status" .= ("completed" :: Text)
                          , "output" .= ("{\"outcome\":\"incomplete\",\"reason\":\"needs another pass\"}" :: Text)
                          ]
                       ]
                ]
            else defaultFakeAppServer request
      )
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 164
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      prNumber = PrNumber 7
      reason = "needs another pass"
      events =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssuePullRequestCreatedEvent prNumber
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        , IssuePullRequestBodyUpdatedEvent prNumber
        , IssueImplementationTurnStartedEvent (TurnId "turn-impl")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let actions = fmap actionExecutionAction tick.loopActionReports
      results <-
        sequence
          [ assert "automatic implementation incomplete reads active turn" (length [() | FakeAppServer request <- calls, request.requestMethod == "thread/read"] == 1)
          , assert "automatic implementation incomplete emits incomplete event" ((daemonObservedEvent <$> tick.loopObservedTick) == Just (IssueImplementationIncompleteEvent reason))
          , assert "automatic implementation incomplete matches indexed projection" (indexedImplementationIncompleteMatches issueConfig prNumber reason tick.loopObservedTick)
          , assert "automatic implementation incomplete restarts worker" (any isTurnStartAction actions)
          , assert "automatic implementation incomplete returns to ready state" (maybe False ((== Implementing) . somePhase . daemonObservedState) tick.loopObservedTick)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic implementation incomplete restart: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isTurnStartAction = \case
    PlannedAppServerRequest request -> request.requestMethod == "turn/start" && request.requestId == RequestId 164
    _ -> False

indexedImplementationIncompleteMatches :: IssueConfig -> PrNumber -> Text -> Maybe DaemonObservedTickResult -> Bool
indexedImplementationIncompleteMatches issueConfig prNumber reason = \case
  Just observed ->
    let state = SomeWatcherState (IssueImplementing issueConfig (Just prNumber) (WorkerActive (ActiveTurn (ThreadId "worker-thread") (TurnId "turn-impl"))))
     in case IssueImplementIndexed.projectIssueImplementationIncompleteObservation state reason of
          Right projection ->
            observed.daemonObservedEvent == projection.issueImplementIndexedProjectionPlanned.plannedEvent
              && sameWatcherStateShape observed.daemonObservedState projection.issueImplementIndexedProjectionFinalState
          Left _ -> False
  Nothing ->
    False

automaticDaemonLoopMissingImplementationOutputBlocks :: IO Bool
automaticDaemonLoopMissingImplementationOutputBlocks = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "turns"
                    .= [ object
                          [ "id" .= ("turn-impl" :: Text)
                          , "status" .= ("completed" :: Text)
                          ]
                       ]
                ]
            else defaultFakeAppServer request
      )
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 165
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      prNumber = PrNumber 7
      reason = BlockedReason "implementation turn completed without output"
      events =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssuePullRequestCreatedEvent prNumber
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        , IssuePullRequestBodyUpdatedEvent prNumber
        , IssueImplementationTurnStartedEvent (TurnId "turn-impl")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let actions = fmap actionExecutionAction tick.loopActionReports
      results <-
        sequence
          [ assert "automatic implementation missing output reads active turn" (length [() | FakeAppServer request <- calls, request.requestMethod == "thread/read"] == 1)
          , assert "automatic implementation missing output blocks" ((daemonObservedEvent <$> tick.loopObservedTick) == Just (IssueImplementationBlockedEvent reason))
          , assert "automatic implementation missing output matches indexed projection" (indexedImplementationBlockedMatches issueConfig prNumber reason tick.loopObservedTick)
          , assert "automatic implementation missing output records blocked state" (maybe False ((== Blocked) . somePhase . daemonObservedState) tick.loopObservedTick)
          , assert "automatic implementation missing output stops daemon" (PlannedStopDaemon `elem` actions)
          , assert "automatic implementation missing output does not restart" (not (any isTurnStartAction actions))
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic implementation missing output block: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isTurnStartAction = \case
    PlannedAppServerRequest request -> request.requestMethod == "turn/start"
    _ -> False

indexedImplementationBlockedMatches :: IssueConfig -> PrNumber -> BlockedReason -> Maybe DaemonObservedTickResult -> Bool
indexedImplementationBlockedMatches issueConfig prNumber reason = \case
  Just observed ->
    let state = SomeWatcherState (IssueImplementing issueConfig (Just prNumber) (WorkerActive (ActiveTurn (ThreadId "worker-thread") (TurnId "turn-impl"))))
     in case IssueImplementIndexed.projectIssueImplementationBlockedImplementingObservation state reason of
          Right projection ->
            observed.daemonObservedEvent == projection.issueImplementIndexedProjectionPlanned.plannedEvent
              && sameWatcherStateShape observed.daemonObservedState projection.issueImplementIndexedProjectionFinalState
          Left _ -> False
  Nothing ->
    False

automaticDaemonLoopCompleteImplementationWithoutKnownPrStaysIncomplete :: IO Bool
automaticDaemonLoopCompleteImplementationWithoutKnownPrStaysIncomplete = do
  (executor, _getCalls) <-
    fakeActionExecutorWith
      defaultFakeCommand
      ( \request ->
          if request.requestMethod == "thread/read"
            then
              object
                [ "turns"
                    .= [ object
                          [ "id" .= ("turn-impl" :: Text)
                          , "status" .= ("completed" :: Text)
                          , "output" .= ("{\"outcome\":\"complete\",\"reason\":\"ready for review\"}" :: Text)
                          ]
                       ]
                ]
            else defaultFakeAppServer request
      )
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 166
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = DryRunActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      reason = "implementation completed before a pull request was known"
      events =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssueImplementationTurnStartedEvent (TurnId "turn-impl")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  case result of
    Right tick -> do
      let actions = fmap actionExecutionAction tick.loopActionReports
      results <-
        sequence
          [ assert "automatic implementation complete without PR stays incomplete" ((daemonObservedEvent <$> tick.loopObservedTick) == Just (IssueImplementationIncompleteEvent reason))
          , assert "automatic implementation complete without PR does not hand off" (not (any isReviewHandoffEvent (daemonObservedEvent <$> tick.loopObservedTick)))
          , assert "automatic implementation complete without PR restarts worker" (any isTurnStartAction actions)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic implementation complete without known PR: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isTurnStartAction = \case
    PlannedAppServerRequest request -> request.requestMethod == "turn/start"
    _ -> False
  isReviewHandoffEvent = \case
    IssueReviewHandoffInitializedEvent {} -> True
    IssueReviewHandoffStartedEvent {} -> True
    _ -> False

automaticDaemonLoopMissingPlanFailsPrBodyUpdate :: IO Bool
automaticDaemonLoopMissingPlanFailsPrBodyUpdate = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhUpdatePullRequestBody {} -> failedCommandReport "issue plan file missing or empty: /tmp/work/.watcher/issue-plan.md"
          command -> defaultFakeCommand command
      )
      defaultFakeAppServer
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 163
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      prNumber = PrNumber 7
      events =
        [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
        , IssuePullRequestCreatedEvent prNumber
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  results <-
    sequence
      [ assert "missing plan fails PR body update" (case result of Left (DaemonLoopDaemonFailure (DaemonActionFailed (PlannedCommand GhUpdatePullRequestBody {}) _report)) -> True; _ -> False)
      , assert "missing plan does not append body-updated event" (not (any isBodyUpdatedAppend calls))
      , assert "missing plan does not start implementation" (not (any isTurnStartCall calls))
      ]
  pure (and results)
 where
  isBodyUpdatedAppend = \case
    FakeAppendJsonLine _ value -> lookupValue "type" value == Just (String "issue_pr_body_updated")
    _ -> False
  isTurnStartCall = \case
    FakeAppServer request -> request.requestMethod == "turn/start"
    _ -> False

automaticDaemonLoopTerminalStateStops :: IO Bool
automaticDaemonLoopTerminalStateStops = do
  (executor, getCalls) <- fakeActionExecutor
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 170
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/example")
      cleanEvidence = CleanReviewEvidence (CommitSha "abc123") "LGTM"
      events =
        [ PrReviewInitialized prConfig (ThreadId "worker-thread") (ThreadId "reviewer-thread")
        , PrReviewNoUnresolvedFound (cleanReviewCommit cleanEvidence) (TurnId "reviewer-turn")
        , PrReviewCleanFound cleanEvidence []
        , PrReviewMergeabilityClean (cleanReviewCommit cleanEvidence)
        , PrReviewMergeCompleted (MergeCommit (CommitSha "def456"))
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      results <-
        sequence
          [ assert "automatic terminal state reports complete idle reason" (tick.loopIdleReason == Just "watcher is complete")
          , assert "automatic terminal state writes compatibility state" (any isFakeWriteJson calls)
          , assert "automatic terminal state stops daemon" (FakeStop `elem` calls)
          , assert "automatic terminal state does not sleep" (FakeSleep `notElem` calls)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic terminal stop: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isFakeWriteJson = \case
    FakeWriteJson {} -> True
    _ -> False

automaticDaemonLoopEmitsBoundaryLogs :: IO Bool
automaticDaemonLoopEmitsBoundaryLogs = do
  (logger, getLogs) <- collectWatcherLogs
  (executor, _getCalls) <- fakeActionExecutorWithLogger logger defaultFakeCommand defaultFakeAppServer
  let repo = RepoName "soulomoon/mlf2"
      runtimeConfig = effectRuntimeConfig repo "/tmp/work" 171
      options =
        DaemonOptions
          { daemonEventLogPath = "/tmp/events.jsonl"
          , daemonRuntimeConfig = runtimeConfig
          , daemonExecutionMode = ExecuteActions
          }
      loopConfig = DaemonLoopConfig options Nothing
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/example")
      cleanEvidence = CleanReviewEvidence (CommitSha "abc123") "LGTM"
      events =
        [ PrReviewInitialized prConfig (ThreadId "worker-thread") (ThreadId "reviewer-thread")
        , PrReviewNoUnresolvedFound (cleanReviewCommit cleanEvidence) (TurnId "reviewer-turn")
        , PrReviewCleanFound cleanEvidence []
        , PrReviewMergeabilityClean (cleanReviewCommit cleanEvidence)
        , PrReviewMergeCompleted (MergeCommit (CommitSha "def456"))
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  logs <- getLogs
  let eventsLogged = fmap Log.watcherLogEvent logs
  case result of
    Right _tick -> do
      results <-
        sequence
          [ assert "loop logs tick start" ("loop_tick_started" `elem` eventsLogged)
          , assert "loop logs replay success" ("loop_replay_succeeded" `elem` eventsLogged)
          , assert "loop logs terminal outcome" ("loop_terminal" `elem` eventsLogged)
          , assert "loop logs tick finish" ("loop_tick_finished" `elem` eventsLogged)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic loop logging: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

automaticLoopRetryPolicyKeepsTransientFailuresAlive :: IO Bool
automaticLoopRetryPolicyKeepsTransientFailuresAlive = do
  let graphqlFailure = classifyDaemonLoopFailure (DaemonLoopExternalFailure "GitHub GraphQL EOF")
      transientCommandFailure =
        classifyDaemonLoopFailure
          ( DaemonLoopDaemonFailure
              ( DaemonActionFailed
                  (PlannedCommand GhAuthStatus)
                  CommandReport {ok = False, status = Just 1, stdout = "", stderr = "GitHub GraphQL EOF", errorMessage = Nothing}
              )
          )
  results <-
    sequence
      [ assert "automatic loop retries external observation failures" (retryableAutomaticLoopFailure (DaemonLoopExternalFailure "GitHub GraphQL EOF"))
      , assert "automatic loop retries app-server transport failures" (retryableAutomaticLoopFailure (DaemonLoopAppServerFailure (AppServerTransportFailure "connection reset")))
      , assert "automatic loop keeps replay failures fatal" (not (retryableAutomaticLoopFailure (DaemonLoopDaemonFailure (DaemonEventLogDecodeFailed "bad event log"))))
      , assert "automatic loop keeps unexpected start plans fatal" (not (retryableAutomaticLoopFailure (DaemonLoopUnexpectedStartPlan "invalid start plan")))
      , assert "automatic loop classifies GraphQL EOF as transient" (graphqlFailure.failureClass == TransientFailure)
      , assert "automatic loop classifies transient command output as retryable" (failureIsRetryable transientCommandFailure)
      ]
  pure (and results)

phaseActionValidationRejectsInvalidCombinations :: IO Bool
phaseActionValidationRejectsInvalidCombinations = do
  let plannerConfig = PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 2) [IssueNumber 12]
      planningGraph = PlanningGraph [IssueNumber 12] [] []
      planningWaiting = SomeWatcherState (PlanningWaitingForReadyIssues plannerConfig planningGraph)
      issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
      issuePr = PrNumber 7
      issuePostMergeWithoutReviewer = SomeWatcherState (IssuePostMergeReviewPendingReviewer issueConfig issuePr (WorkerIdle (ThreadId "worker")))
      issuePostMergeWithReviewer = SomeWatcherState (IssuePostMergeReviewReady issueConfig issuePr (WorkerIdle (ThreadId "worker")) (ReviewerIdle (ThreadId "reviewer")))
      prConfig = PrConfig (RepoName "soulomoon/mlf2") (PrNumber 8) (BranchName "codex/pr-8")
      prFixing = SomeWatcherState (PrFixingReviews prConfig (reviewEvidenceFromSummaries ("fix" :| []) (CommitSha "abc123")) (WorkerActive (ActiveTurn (ThreadId "worker") (TurnId "turn"))) (ReviewerIdle (ThreadId "reviewer")))
      startPlanner = [SomeEffect (StartPlannerTurn (ThreadId "planner"))]
      retryPlanning = [SomeEffect SleepUntilNextPoll]
      startReviewer = [SomeEffect (StartReviewerTurn prConfig (CommitSha "abc123") (ThreadId "reviewer"))]
      readReviews = [SomeEffect (ReadReviewThreads prConfig)]
      startFinalReviewer = [SomeEffect (StartIssueFinalReviewTurn issueConfig issuePr (CommitSha "def456") (ThreadId "reviewer"))]
  results <-
    sequence
      [ assert "planning waiting rejects planner turn starts" (validationRejected planningWaiting startPlanner)
      , assert "planning waiting allows retry sleep" (validatePhaseActionPlan planningWaiting retryPlanning == Right ())
      , assert "PR fixing rejects clean reviewer starts" (validationRejected prFixing startReviewer)
      , assert "PR fixing allows review-thread reads" (validatePhaseActionPlan prFixing readReviews == Right ())
      , assert "post-merge review rejects final reviewer without reviewer thread" (validationRejected issuePostMergeWithoutReviewer startFinalReviewer)
      , assert "post-merge review allows final reviewer with reviewer thread" (validatePhaseActionPlan issuePostMergeWithReviewer startFinalReviewer == Right ())
      ]
  pure (and results)
 where
  validationRejected state effects =
    case validatePhaseActionPlan state effects of
      Left _ -> True
      Right () -> False

phaseActionValidationAcceptsStateMachineDecisions :: IO Bool
phaseActionValidationAcceptsStateMachineDecisions = do
  let repo = RepoName "soulomoon/mlf2"
      plannerConfig = PlannerConfig repo (maxParallelForTest 2) [IssueNumber 42]
      planningGraph = PlanningGraph [IssueNumber 42] [] []
      issueConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42")
      followUpConfig = IssueConfig repo (IssueNumber 42) (BranchName "codex/issue-42-2")
      prNumber = PrNumber 7
      prConfig = PrConfig repo prNumber (BranchName "codex/issue-42")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      plannerTurn = ActiveTurn (ThreadId "planner") (TurnId "planner-turn")
      planTurn = ActiveTurn workerThread (TurnId "plan-turn")
      implementationTurn = ActiveTurn workerThread (TurnId "implementation-turn")
      reviewerTurn = ActiveTurn reviewerThread (TurnId "reviewer-turn")
      commit = CommitSha "abc123"
      cleanEvidence = CleanReviewEvidence commit "LGTM"
      reviewEvidence = reviewEvidenceFromSummaries ("fix bug" :| []) commit
      workerIdle = WorkerIdle workerThread
      reviewerIdle = ReviewerIdle reviewerThread
      workerActive = WorkerActive implementationTurn
      reviewerActive = ReviewerActive reviewerTurn
      planningRequests =
        IssueCreationRequest "child issue" "body" Nothing :| []
      cases =
        [ decisionAllowed "planning starts planner" (PlanningReady plannerConfig) (StartPlanningTurn plannerTurn)
        , decisionAllowed "planning records graph" (PlanningTurnActive plannerConfig plannerTurn) (PlannerUpdatedGraph planningGraph)
        , decisionAllowed "planning creates issues" (PlanningTurnActive plannerConfig plannerTurn) (PlannerRequestedIssueCreation planningRequests)
        , decisionAllowed "planning waits after retry" (PlanningTurnActive plannerConfig plannerTurn) (PlannerTurnRetryRequested (BlockedReason "retry"))
        , decisionAllowed "planning completes" (PlanningTurnActive plannerConfig plannerTurn) PlannerTurnCompleted
        , decisionAllowed "planning waiting reactivates" (PlanningWaitingForReadyIssues plannerConfig planningGraph) PlannerReadyIssuesFixed
        , decisionAllowed "issue starts plan turn" (IssueReadyToPlan issueConfig prNumber workerIdle) (StartReadyIssuePlanTurn planTurn)
        , decisionAllowed "issue records plan" (IssueInPlanMode issueConfig prNumber (WorkerActive planTurn)) (IssuePlanCompleted sampleIssuePlanMarkdown (Just implementationTurn))
        , decisionAllowed "issue accepts PR body update" (IssuePlanReady issueConfig prNumber workerIdle) (IssuePullRequestBodyUpdated prNumber)
        , decisionAllowed "issue starts implementation" (IssueImplementationReady issueConfig (Just prNumber) workerIdle) (StartIssueImplementationTurn implementationTurn)
        , decisionAllowed "issue advances merged attempt branch" (IssueImplementationReady issueConfig Nothing workerIdle) (IssueAttemptBranchAdvanced followUpConfig.issueBranch)
        , decisionAllowed "issue restarts incomplete implementation" (IssueImplementing issueConfig (Just prNumber) workerActive) IssueImplementationIncomplete
        , decisionAllowed "issue completes implementation" (IssueImplementing issueConfig (Just prNumber) workerActive) (IssueImplementationCompleted prNumber (Just reviewerThread))
        , decisionAllowed "issue enters post-merge review" (IssueWaitingForPrMerge issueConfig prNumber workerIdle (Just reviewerIdle)) (IssuePullRequestMerged prNumber)
        , decisionAllowed "issue records reviewer thread" (IssuePostMergeReviewPendingReviewer issueConfig prNumber workerIdle) (IssueReviewerThreadReady reviewerThread)
        , decisionAllowed "issue starts final review" (IssuePostMergeReviewReady issueConfig prNumber workerIdle reviewerIdle) (StartIssuePostMergeReview commit reviewerTurn)
        , decisionAllowed "issue closes after final clean" (IssuePostMergeReviewing issueConfig prNumber workerIdle commit reviewerActive) (IssuePostMergeReviewSatisfied cleanEvidence)
        , decisionAllowed "issue requests follow-up" (IssuePostMergeReviewing issueConfig prNumber workerIdle commit reviewerActive) (IssuePostMergeReviewFollowUp reviewEvidence)
        , decisionAllowed "issue retries incomplete final review" (IssuePostMergeReviewing issueConfig prNumber workerIdle commit reviewerActive) (IssuePostMergeReviewIncomplete "retry")
        , decisionAllowed "issue completes after close" (IssueWaitingForIssueClose issueConfig prNumber) (IssueClosed prNumber)
        , decisionAllowed "PR starts worker on findings" (PrCheckingReviews prConfig workerIdle reviewerIdle) (ReviewThreadsFound reviewEvidence implementationTurn)
        , decisionAllowed "PR starts clean reviewer" (PrCheckingReviews prConfig workerIdle reviewerIdle) (NoReviewThreadsFound commit reviewerTurn)
        , decisionAllowed "PR fix completion waits" (PrFixingReviews prConfig reviewEvidence workerActive reviewerIdle) ReviewFixCompleted
        , decisionAllowed "PR incomplete fix rereads threads" (PrFixingReviews prConfig reviewEvidence workerActive reviewerIdle) ReviewFixIncomplete
        , decisionAllowed "PR verifying starts worker on new findings" (PrVerifyingReviewFix prConfig reviewEvidence workerIdle reviewerIdle) (ReviewThreadsFound reviewEvidence implementationTurn)
        , decisionAllowed "PR verifying starts normal reviewer" (PrVerifyingReviewFix prConfig reviewEvidence workerIdle reviewerIdle) (NoReviewThreadsFound commit reviewerTurn)
        , decisionAllowed "PR verifying starts verification reviewer" (PrVerifyingReviewFix prConfig reviewEvidence workerIdle reviewerIdle) (StartReviewFixVerification commit reviewerTurn)
        , decisionAllowed "PR clean reviewer approves clean" (PrReviewingClean prConfig commit normalReviewContext workerIdle reviewerActive) (ReviewerFoundClean cleanEvidence [])
        , decisionAllowed "PR verification resolves old findings" (PrReviewingClean prConfig commit (verificationReviewContext reviewEvidence) workerIdle reviewerActive) (ReviewerFoundClean cleanEvidence [ReviewThreadId "thread-1"])
        , decisionAllowed "PR clean reviewer finds problems" (PrReviewingClean prConfig commit normalReviewContext workerIdle reviewerActive) (ReviewerFoundProblems reviewEvidence [ReviewThreadId "thread-1"])
        , decisionAllowed "PR clean reviewer incomplete rereads" (PrReviewingClean prConfig commit normalReviewContext workerIdle reviewerActive) ReviewerTurnIncomplete
        , decisionAllowed "PR waits then merges" (PrWaitingForMergeability prConfig cleanEvidence workerIdle reviewerIdle) MergeabilityClean
        , decisionAllowed "PR mergeability retries" (PrWaitingForMergeability prConfig cleanEvidence workerIdle reviewerIdle) (MergeabilityRetryLater "pending")
        , decisionAllowed "PR mergeability rechecks reviews" (PrWaitingForMergeability prConfig cleanEvidence workerIdle reviewerIdle) (MergeabilityRecheckReviews "review changed")
        , decisionAllowed "PR merge completes" (PrMerging prConfig cleanEvidence) (MergeCompleted (MergeCommit (CommitSha "def456")))
        , decisionAllowed "blocked state can stop" (BlockedState (BlockedReason "blocked") :: WatcherState 'IssueImplement 'Blocked) (StopWatcher (StopReason "stop"))
        ]
  sequence cases >>= pure . and
 where
  decisionAllowed testName state event =
    case step state event of
      Decision _ effects ->
        assert testName (validatePhaseActionPlan (SomeWatcherState state) effects == Right ())

workflowFacadeExtractionTests :: IO Bool
workflowFacadeExtractionTests = do
  results <-
    sequence
      [ workflowFacadeReplayMatchesEventLog
      , workflowSpecModuleKeepsCoreBoundary
      , workflowIndexedSpecModuleKeepsCoreBoundary
      , workflowSpecIndexedBridgeSourceScans
      , workflowSpecInventoryCoversCurrentSpecSurfaces
      , workflowCabalProjectListsStandaloneWorkflowPackages
      , workflowMoifoldCabalConsumesStandaloneWorkflowPackages
      , workflowCoreStandalonePackageKeepsPackageBoundary
      , workflowCodexStandalonePackageKeepsPackageBoundary
      , workflowGithubStandalonePackageKeepsPackageBoundary
      , workflowMoifoldCabalLibraryDoesNotReexportAdapters
      , workflowEventCodecContractCoversWatcherEvents
      , workflowEventCodecToleratesMetadataAndPreservesGoldenTypes
      , workflowEventLogCommitCoreEncodesAndAppendsBeforeSuccess
      , workflowEventLogFileCoreNumberingIgnoresBlankLines
      , workflowEventLogFileCoreDecodeFailureReportsSourceLine
      , workflowEventLogFileWrapperDecodesExistingFixtures
      , workflowEventLogFileWrapperFormatsMalformedErrors
      , workflowGithubCommandFacadeMatchesRuntimeRender
      , workflowEventLogCoreDetailedReplayMatchesMoifold
      , workflowEventLogCoreFixtureContractValidatesReplay
      , workflowEventLogCoreTransitionContractsMatchFacades
      , workflowFacadeInitialApplyMatchesReplay
      , workflowPermissionFacadeMatchesStateMachine
      , workflowPermissionCoreChecksMatchMoifoldPermission
      , workflowPermissionPolicyMatchesMoifoldPermission
      , workflowExecutionFacadeDryRunMatchesExecutor
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
      , workflowIndexedSpecExistentialsPreserveLabels
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
      , workflowIssueImplementLifecycleBoundarySourceScans
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
      , workflowPlannedTransitionPreservesObservedEffects
      , workflowPlannedTransitionPartitionsPostCommitEffects
      , workflowPrReviewMergeabilityPlannedTransitionKeepsMergePreCommitEffect
      , workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions
      , workflowDocsMigrationIndexedLawMatchesUnindexedDraftReplayTerminalAndPermissions
      , workflowDocsMigrationIndexedSpecMatchesCompatibilityForDraft
      , workflowDocsMigrationIndexedSpecMatchesCompatibilityForValidationAndBlocked
      , workflowDocsMigrationIndexedSpecPreservesPermissionsAndFixtureCodec
      , workflowDocsMigrationIndexedDryRunAndDaemonParity
      , workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions
      , workflowEventLogFailureAuditClassifiesRetryRecommendation
      , workflowDslWorkflowMAccumulationLaws
      , workflowDslAdvanceBuildsPhaseChangingTransition
      , workflowDslPrReviewFeedbackMatchesStateMachine
      , workflowDslTransitionLowersToPlannedTransition
      , workflowDslMoifoldProjectionParity
      , workflowDslDocsMigrationProjectionParity
      , workflowDslDocsMigrationDraftProducedPortParity
      , workflowDslIssuePlanningTurnCompletedPortParity
      , workflowDocsMigrationSpecProvesSecondWorkflow
      , workflowDocsMigrationPermissionAndPartitionContracts
      , workflowDocsMigrationEventCodecFixtureContract
      , workflowDocsMigrationFixtureFailureReportsThroughCore
      , workflowDocsMigrationAgentRoleClassifiesCompleteOutput
      , workflowDocsMigrationUsesCoreExecutionContracts
      , workflowDaemonCoreProjectsMoifoldAndDocsMigrationResults
      , workflowDaemonCoreProjectsObservedFailureBoundary
      , workflowTransactionDetailedFailuresRecordCommitBoundary
      , workflowExecutionMetadataCoversCurrentEffects
      , workflowExecutionCapabilityMetadataCoversCurrentEffects
      , workflowExecutionMetadataPartitionPreservesLegacyOrdering
      , workflowExecutionMetadataDryRunMatchesLegacy
      , workflowExecutionCoreCheckedActionsStopsOnFirstFailure
      , workflowExecutionCheckedActionsStopsOnHardFailure
      ]
  pure (and results)

workflowSpecModuleKeepsCoreBoundary :: IO Bool
workflowSpecModuleKeepsCoreBoundary = do
  let specPath =
        "agent-workflow-core"
          </> "src"
          </> "CodexWatcher"
          </> "Workflow"
          </> "Spec.hs"
  source <- Text.pack <$> readFile specPath
  let forbiddenImports =
        sourceImportViolationsIn specPath coreBoundaryForbiddenImportModules source
      keepsCoreDefinitions =
        "data PlannedTransition spec" `Text.isInfixOf` source
          && "class WorkflowSpec spec where" `Text.isInfixOf` source
          && "workflowPlanObservation" `Text.isInfixOf` source
  importsOk <-
    assertNoTextMatches
      "workflow spec module has no moifold-specific imports"
      forbiddenImports
  definitionsOk <-
    assert
      "workflow spec module keeps generic core definitions"
      keepsCoreDefinitions
  pure (importsOk && definitionsOk)

workflowIndexedSpecModuleKeepsCoreBoundary :: IO Bool
workflowIndexedSpecModuleKeepsCoreBoundary = do
  let specPath =
        "agent-workflow-core"
          </> "src"
          </> "CodexWatcher"
          </> "Workflow"
          </> "Indexed"
          </> "Spec.hs"
  source <- Text.pack <$> readFile specPath
  let forbiddenImports =
        sourceImportViolationsIn specPath coreBoundaryForbiddenImportModules source
      keepsCoreDefinitions =
        "type family WorkflowIndex spec :: Type" `Text.isInfixOf` source
          && "class IndexedWorkflowSpec spec where" `Text.isInfixOf` source
          && "data IndexedPlannedTransition" `Text.isInfixOf` source
          && "SomeIndexedWorkflowState" `Text.isInfixOf` source
          && "SomeIndexedWorkflowEvent" `Text.isInfixOf` source
          && "SomeIndexedWorkflowObservation" `Text.isInfixOf` source
          && "SomeIndexedWorkflowEffectPlan" `Text.isInfixOf` source
          && "SomeIndexedPlannedTransition" `Text.isInfixOf` source
          && "data WorkflowSpecIndexedBridge" `Text.isInfixOf` source
          && "workflowSpecBridgeReplayEvents" `Text.isInfixOf` source
          && "workflowSpecBridgeEffectAllowed" `Text.isInfixOf` source
          && "indexedWorkflowPlanObservation" `Text.isInfixOf` source
  importsOk <-
    assertNoTextMatches
      "indexed workflow spec module has no moifold-specific imports"
      forbiddenImports
  definitionsOk <-
    assert
      "indexed workflow spec module exposes indexed class, transitions, and existentials"
      keepsCoreDefinitions
  pure (importsOk && definitionsOk)

workflowSpecIndexedBridgeSourceScans :: IO Bool
workflowSpecIndexedBridgeSourceScans = do
  indexedSpecSource <-
    Text.pack
      <$> readFile
        ( "agent-workflow-core"
            </> "src"
            </> "CodexWatcher"
            </> "Workflow"
            </> "Indexed"
            </> "Spec.hs"
        )
  docsMigrationSource <-
    Text.pack
      <$> readFile ("src" </> "CodexWatcher" </> "Workflow" </> "DocsMigration.hs")
  prReviewCheckingSource <-
    Text.pack
      <$> readFile
        ( "src"
            </> "CodexWatcher"
            </> "Workflow"
            </> "Moifold"
            </> "PrReview"
            </> "Checking"
            </> "Indexed.hs"
        )
  let forbiddenImports =
        sourceImportViolationsIn
          ("agent-workflow-core" </> "src" </> "CodexWatcher" </> "Workflow" </> "Indexed" </> "Spec.hs")
          coreBoundaryForbiddenImportModules
          indexedSpecSource
  importsOk <-
    assertNoTextMatches
      "workflow indexed bridge keeps generic core imports"
      forbiddenImports
  results <-
    sequence
      [ assert "workflow indexed bridge exposes generic delegate hooks" $
          all
            (`Text.isInfixOf` indexedSpecSource)
            [ "WorkflowSpecIndexedBridge"
            , "workflowSpecBridgeInitialEvent"
            , "workflowSpecBridgeApplyEvent"
            , "workflowSpecBridgeObserve"
            , "workflowSpecBridgeObservedTransition"
            , "workflowSpecBridgePlanTransition"
            , "workflowSpecBridgeReplayEvents"
            , "workflowSpecBridgeValidateEffects"
            , "workflowSpecBridgeEffectAllowed"
            , "workflowSpecBridgeEffectLabel"
            ]
      , assert "workflow indexed bridge migrates DocsMigration indexed hooks" $
          all
            (`Text.isInfixOf` docsMigrationSource)
            [ "docsMigrationIndexedBridge"
            , "workflowSpecBridgePlanTransition docsMigrationIndexedBridge"
            , "workflowSpecBridgeReplayEvents docsMigrationIndexedBridge"
            , "workflowSpecBridgeValidateEffects docsMigrationIndexedBridge"
            , "workflowSpecBridgeEffectAllowed docsMigrationIndexedBridge"
            ]
      , assert "workflow indexed bridge migrates representative moifold PR-review checking adapter" $
          all
            (`Text.isInfixOf` prReviewCheckingSource)
            [ "prReviewCheckingIndexedBridge"
            , "WorkflowSpecIndexedBridge MoifoldSpec PrReviewCheckingIndexedSpec"
            , "workflowSpecBridgePlanTransition prReviewCheckingIndexedBridge"
            , "workflowSpecBridgeReplayEvents prReviewCheckingIndexedBridge"
            , "workflowSpecBridgeEffectAllowed prReviewCheckingIndexedBridge"
            ]
      ]
  pure (importsOk && and results)

workflowSpecInventoryCoversCurrentSpecSurfaces :: IO Bool
workflowSpecInventoryCoversCurrentSpecSurfaces = do
  workflowSpecSource <-
    Text.pack
      <$> readFile
        ( "agent-workflow-core"
            </> "src"
            </> "CodexWatcher"
            </> "Workflow"
            </> "Spec.hs"
        )
  indexedSpecSource <-
    Text.pack
      <$> readFile
        ( "agent-workflow-core"
            </> "src"
            </> "CodexWatcher"
            </> "Workflow"
            </> "Indexed"
            </> "Spec.hs"
        )
  moifoldSpecSource <-
    Text.pack
      <$> readFile ("src" </> "CodexWatcher" </> "Workflow" </> "Types.hs")
  docsMigrationSource <-
    Text.pack
      <$> readFile ("src" </> "CodexWatcher" </> "Workflow" </> "DocsMigration.hs")
  indexedAdapterSources <-
    traverse
      ( \(path, needles) -> do
          source <- Text.pack <$> readFile path
          pure (source, needles)
      )
      [ ( "src" </> "CodexWatcher" </> "Workflow" </> "Moifold" </> "IssuePlanning" </> "Indexed.hs"
        , ["data IssuePlanningIndexedSpec", "instance IndexedWorkflow.IndexedWorkflowSpec IssuePlanningIndexedSpec"]
        )
      , ( "src" </> "CodexWatcher" </> "Workflow" </> "Moifold" </> "IssueImplement" </> "Indexed.hs"
        , ["data IssueImplementIndexedSpec", "instance IndexedWorkflow.IndexedWorkflowSpec IssueImplementIndexedSpec"]
        )
      , ( "src" </> "CodexWatcher" </> "Workflow" </> "Moifold" </> "PrReview" </> "Checking" </> "Indexed.hs"
        , ["data PrReviewCheckingIndexedSpec", "instance IndexedWorkflow.IndexedWorkflowSpec PrReviewCheckingIndexedSpec"]
        )
      , ( "src" </> "CodexWatcher" </> "Workflow" </> "Moifold" </> "PrReview" </> "Worker" </> "Indexed.hs"
        , ["data PrReviewWorkerIndexedSpec", "instance IndexedWorkflow.IndexedWorkflowSpec PrReviewWorkerIndexedSpec"]
        )
      , ( "src" </> "CodexWatcher" </> "Workflow" </> "Moifold" </> "PrReview" </> "Reviewer" </> "Indexed.hs"
        , ["data PrReviewReviewerIndexedSpec", "instance IndexedWorkflow.IndexedWorkflowSpec PrReviewReviewerIndexedSpec"]
        )
      , ( "src" </> "CodexWatcher" </> "Workflow" </> "Moifold" </> "PrReview" </> "Mergeability" </> "Indexed.hs"
        , ["data PrReviewMergeabilityIndexedSpec", "instance IndexedWorkflow.IndexedWorkflowSpec PrReviewMergeabilityIndexedSpec"]
        )
      ]
  results <-
    sequence
      [ assert "workflow spec inventory covers unindexed hooks" $
          all
            (`Text.isInfixOf` workflowSpecSource)
            [ "type WorkflowState spec"
            , "type WorkflowEvent spec"
            , "type WorkflowObservation spec"
            , "type WorkflowObservedTick spec"
            , "type WorkflowEffect spec"
            , "type WorkflowEffectPlan spec"
            , "type WorkflowReplayResult spec"
            , "workflowReplayEvents"
            , "workflowValidateEffects"
            , "workflowEffectPlanEffects"
            , "workflowEffectAllowed"
            , "workflowIsTerminal"
            , "workflowStateLabel"
            , "workflowEventLabel"
            , "workflowObservationLabel"
            , "workflowEffectLabel"
            ]
      , assert "workflow spec inventory covers indexed hooks and existential helpers" $
          all
            (`Text.isInfixOf` indexedSpecSource)
            [ "type IndexedWorkflowState spec state"
            , "type IndexedWorkflowEvent spec source target"
            , "type IndexedWorkflowObservation spec source target"
            , "type IndexedWorkflowObservedTick spec source target"
            , "type IndexedWorkflowEffect spec source target"
            , "type IndexedWorkflowEffectPlan spec source target"
            , "type IndexedWorkflowReplayResult spec state"
            , "indexedWorkflowReplayEvents"
            , "indexedWorkflowReplayState"
            , "indexedWorkflowValidateEffects"
            , "indexedWorkflowEffectAllowed"
            , "indexedWorkflowIsTerminal"
            , "indexedWorkflowEventSourceLabel"
            , "indexedWorkflowEventTargetLabel"
            , "indexedWorkflowObservationSourceLabel"
            , "indexedWorkflowObservationTargetLabel"
            , "SomeIndexedWorkflowState"
            , "SomeIndexedWorkflowEvent"
            , "SomeIndexedWorkflowObservation"
            , "SomeIndexedWorkflowEffect"
            , "SomeIndexedWorkflowEffectPlan"
            , "SomeIndexedWorkflowReplayResult"
            , "someIndexedWorkflowReplayStateLabel"
            , "withSomeIndexedPlannedTransition"
            , "WorkflowSpecIndexedBridge"
            , "workflowSpecBridgePlanTransition"
            ]
      , assert "workflow spec inventory covers moifold and docs-migration instances" $
          all
            (`Text.isInfixOf` moifoldSpecSource)
            [ "data MoifoldSpec"
            , "instance WorkflowSpec MoifoldSpec"
            , "workflowReplayEvents events"
            , "workflowValidateEffects state effects"
            , "workflowEffectAllowed state effect"
            , "workflowIsTerminal = isTerminalState"
            ]
            && all
              (`Text.isInfixOf` docsMigrationSource)
              [ "data DocsMigrationSpec"
              , "instance WorkflowSpec DocsMigrationSpec"
              , "instance IndexedWorkflow.IndexedWorkflowSpec DocsMigrationSpec"
              , "docsMigrationIndexedBridge"
              , "docsMigrationIndexedSomeReplayResult"
              , "workflowSpecBridgeReplayEvents docsMigrationIndexedBridge"
              , "workflowSpecBridgeEffectAllowed docsMigrationIndexedBridge"
              , "indexedWorkflowEventSourceLabel"
              , "indexedWorkflowObservationTargetLabel"
              ]
      , assert "workflow spec inventory covers current moifold indexed adapters" $
          all
            ( \(source, needles) ->
                all (`Text.isInfixOf` source) (needles <> indexedAdapterNeedles)
            )
            indexedAdapterSources
      ]
  pure (and results)
 where
  indexedAdapterNeedles =
    [ "indexedWorkflowReplayEvents"
    , "indexedWorkflowValidateEffects"
    , "indexedWorkflowEffectAllowed"
    , "indexedWorkflowIsTerminal"
    , "indexedWorkflowEventSourceLabel"
    , "indexedWorkflowEventTargetLabel"
    , "indexedWorkflowObservationSourceLabel"
    , "indexedWorkflowObservationTargetLabel"
    ]

workflowIssueImplementLifecycleBoundarySourceScans :: IO Bool
workflowIssueImplementLifecycleBoundarySourceScans = do
  coreSources <- sourceTextUnder ("agent-workflow-core" </> "src")
  lifecycleSources <-
    Text.intercalate "\n"
      <$> traverse
        (fmap Text.pack . readFile)
        [ "src" </> "CodexWatcher" </> "Domain" </> "IssueImplement" </> "Watcher.hs"
        , "src" </> "CodexWatcher" </> "Domain" </> "IssueImplement" </> "Loop.hs"
        , "src" </> "CodexWatcher" </> "DaemonLoop.hs"
        , "src" </> "CodexWatcher" </> "DaemonLoop" </> "Runtime.hs"
        , "src" </> "CodexWatcher" </> "DaemonLoop" </> "TurnStart.hs"
        , "src" </> "CodexWatcher" </> "AutomaticLoop" </> "IssuePlanningFanout.hs"
        ]
  daemonSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Daemon.hs")
  issueFanoutSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Cli" </> "Command" </> "IssueFanout.hs")
  healthcheckSource <- TextIO.readFile ("src" </> "CodexWatcher" </> "Healthcheck.hs")
  cabalSource <- TextIO.readFile "moifold.cabal"
  let coreForbiddenImportModules =
        [ "CodexWatcher.ChildDaemon"
        , "CodexWatcher.WatcherRuntimeStatus"
        , "CodexWatcher.Healthcheck"
        , "CodexWatcher.EventLogRepair"
        , "CodexWatcher.Cli.Command.IssueFanout"
        , "CodexWatcher.AutomaticLoop.IssuePlanningFanout"
        , "CodexWatcher.Domain.IssueImplement"
        , "CodexWatcher.EventLog"
        , "CodexWatcher.Core.State"
        ]
      coreForbiddenTokens =
        [ "IssueConfig"
        , "WatcherEvent"
        , "SomeWatcherState"
        , "runtime-owner"
        , "issue-watcher.pid"
        , ".lock"
        ]
      lifecycleIndexedRouterTokens =
        [ "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed"
        , "projectIssueImplement"
        , "IssueImplementIndexedSpec"
        ]
      mainLibrarySection = cabalComponentSection "library" cabalSource
      coreImportViolations =
        sourceImportViolationsIn "agent-workflow-core/src" coreForbiddenImportModules coreSources
      coreTokenViolations =
        filter (`Text.isInfixOf` coreSources) coreForbiddenTokens
      lifecycleRouterViolations =
        filter (`Text.isInfixOf` lifecycleSources) lifecycleIndexedRouterTokens
      adapterReexportViolations =
        filter
          (`Text.isInfixOf` mainLibrarySection)
          [ "reexported-modules:"
          , "CodexWatcher.Workflow.Agent"
          , "CodexWatcher.Workflow.GitHub"
          ]
  importsOk <-
    assertNoTextMatches
      "workflow core source has no IssueImplement lifecycle ownership imports"
      coreImportViolations
  tokensOk <-
    assertNoTextMatches
      "workflow core source has no IssueImplement lifecycle ownership tokens"
      coreTokenViolations
  lifecycleRouterOk <-
    assertNoTextMatches
      "IssueImplement lifecycle modules do not route through indexed daemon projectors"
      lifecycleRouterViolations
  daemonRouterOk <-
    assert
      "live IssueImplement indexed projection routing remains isolated to Daemon"
      ("CodexWatcher.Workflow.Moifold.IssueImplement.Indexed" `Text.isInfixOf` daemonSource)
  compatibilityFacadeOk <-
    assertNoTextMatches
      "main moifold library keeps compatibility facades without adapter reexports"
      adapterReexportViolations
  launchOwnershipOk <-
    assert
      "IssueFanout keeps child lifecycle ownership in moifold"
      ( all
          (`Text.isInfixOf` issueFanoutSource)
          [ "startChildDaemonChecked"
          , "issue-watcher.pid"
          ]
      )
  healthcheckReadOnlyOk <-
    assert
      "healthcheck surfaces issue implement lifecycle files without mutation"
      ( all
          (`Text.isInfixOf` healthcheckSource)
          [ "(\"issueState\", \"issue-state.json\")"
          , "(\"daemonState\", \"daemon-state.json\")"
          , "(\"blockedState\", \"block-state.json\")"
          , "(\"runtimeOwner\", \"runtime-owner.json\")"
          , "fallbackPidPath kind stateDir' config.pidPath"
          ]
          && not ("writeJsonValue" `Text.isInfixOf` healthcheckSource)
      )
  pure (importsOk && tokensOk && lifecycleRouterOk && daemonRouterOk && compatibilityFacadeOk && launchOwnershipOk && healthcheckReadOnlyOk)

workflowMoifoldCabalConsumesStandaloneWorkflowPackages :: IO Bool
workflowMoifoldCabalConsumesStandaloneWorkflowPackages = do
  cabalSource <- Text.pack <$> readFile "moifold.cabal"
  let mainLibrarySection = cabalComponentSection "library" cabalSource
      watcherCoreTestSection = cabalComponentSection "test-suite watcher-core-test" cabalSource
      mainLibraryDependencyPackages = cabalBuildDependsPackages mainLibrarySection
      watcherCoreTestDependencyPackages = cabalBuildDependsPackages watcherCoreTestSection
      internalWorkflowComponentMatches =
        filter
          (`elem` Text.lines cabalSource)
          [ "library agent-workflow-core"
          , "library agent-workflow-codex"
          , "library agent-workflow-github"
          ]
      internalWorkflowDependencyMatches =
        filter
          (`Text.isInfixOf` cabalSource)
          [ "moifold:agent-workflow-core"
          , "moifold:agent-workflow-codex"
          , "moifold:agent-workflow-github"
          ]
      standaloneWorkflowDependencyBounds =
        [ "agent-workflow-core >=0.1 && <0.2"
        , "agent-workflow-codex >=0.1 && <0.2"
        , "agent-workflow-github >=0.1 && <0.2"
        ]
      mainLibraryMissingStandalonePackages =
        filter (`notElem` mainLibraryDependencyPackages) standaloneWorkflowPackageNames
      watcherCoreTestMissingStandalonePackages =
        filter (`notElem` watcherCoreTestDependencyPackages) standaloneWorkflowPackageNames
  noInternalComponentsOk <-
    assertNoTextMatches
      "moifold cabal no longer defines internal workflow sublibraries"
      internalWorkflowComponentMatches
  noInternalDependenciesOk <-
    assertNoTextMatches
      "moifold cabal no longer consumes internal workflow sublibraries"
      internalWorkflowDependencyMatches
  mainLibraryPackageNamesOk <-
    assertNoTextMatches
      "main moifold library depends on standalone workflow package names"
      mainLibraryMissingStandalonePackages
  watcherCoreTestPackageNamesOk <-
    assertNoTextMatches
      "watcher-core-test depends on standalone workflow package names"
      watcherCoreTestMissingStandalonePackages
  mainLibraryDependsOk <-
    assert
      "main moifold library depends on standalone workflow packages with approved bounds"
      (all (`Text.isInfixOf` mainLibrarySection) standaloneWorkflowDependencyBounds)
  watcherCoreTestDependsOk <-
    assert
      "watcher-core-test depends on standalone workflow packages with approved bounds"
      (all (`Text.isInfixOf` watcherCoreTestSection) standaloneWorkflowDependencyBounds)
  pure
    ( noInternalComponentsOk
        && noInternalDependenciesOk
        && mainLibraryPackageNamesOk
        && watcherCoreTestPackageNamesOk
        && mainLibraryDependsOk
        && watcherCoreTestDependsOk
    )

workflowCabalProjectListsStandaloneWorkflowPackages :: IO Bool
workflowCabalProjectListsStandaloneWorkflowPackages = do
  projectSource <- Text.pack <$> readFile "cabal.project"
  let projectPackages = sort (cabalFieldEntries "packages" projectSource)
      expectedPackages = sort ("." : standaloneWorkflowPackageNames)
      packageMismatches =
        inventoryMismatches "cabal.project packages" expectedPackages projectPackages
      internalWorkflowDependencyMatches =
        filter
          (`Text.isInfixOf` projectSource)
          [ "moifold:agent-workflow-core"
          , "moifold:agent-workflow-codex"
          , "moifold:agent-workflow-github"
          ]
  packageInventoryOk <-
    assertNoTextMatches
      "cabal.project lists the root and standalone workflow packages"
      packageMismatches
  noInternalDependenciesOk <-
    assertNoTextMatches
      "cabal.project does not reference internal workflow sublibraries"
      internalWorkflowDependencyMatches
  pure (packageInventoryOk && noInternalDependenciesOk)

standaloneWorkflowPackageNames :: [Text]
standaloneWorkflowPackageNames =
  [ "agent-workflow-core"
  , "agent-workflow-codex"
  , "agent-workflow-github"
  ]

workflowCoreStandalonePackageKeepsPackageBoundary :: IO Bool
workflowCoreStandalonePackageKeepsPackageBoundary = do
  standaloneCabalSource <- Text.pack <$> readFile ("agent-workflow-core" </> "agent-workflow-core.cabal")
  coreSources <- sourceTextUnder ("agent-workflow-core" </> "src")
  coreSourceModules <- sourceModulesUnder ("agent-workflow-core" </> "src")
  forbiddenImportViolations <-
    sourceImportViolationsUnder
      ("agent-workflow-core" </> "src")
      coreBoundaryForbiddenImportModules
  let standaloneCoreSection = cabalComponentSection "library" standaloneCabalSource
      standaloneForbiddenPackageNeedles =
        [ "aeson"
        , "directory"
        , "filepath"
        , "optparse-applicative"
        , "singletons"
        , "typed-process"
        , "unix"
        , "websockets"
        , "moifold,"
        , "moifold:"
        , "agent-workflow-codex"
        , "agent-workflow-github"
        ]
      forbiddenConcreteTypes =
        [ "ChildDaemon"
        , "Healthcheck"
        , "EventLogRepair"
        , "WatcherRuntimeStatus"
        , "SomeWatcherState"
        , "WatcherState"
        , "WatcherEvent"
        , "DaemonObservation"
        , "ObservedPolicyTick"
        , "EffectPlan"
        , "SomeEffect"
        , "ActionExecutionMode"
        , "RuntimeInterpreter"
        , "AppServerTurn"
        , "AppServerRequest"
        , "GitHubCommandSpec"
        , "RepoName"
        , "PrConfig"
        , "DaemonOptions"
        , "DaemonTickResult"
        , "runDaemonTickWithEvents"
        , "runObservedDaemonTickWithEvents"
        , "DaemonObservedTickResult"
        , "DaemonObservedTransactionFailure"
        , "CompatibilityWrite"
        , "PidFile"
        , "RuntimeOwner"
        , "RuntimeLease"
        , "FilePath"
        , "IO"
        , "ActionExecutionReport"
        , "CommandReport"
        , "PlannedAction"
        ]
      forbiddenConcreteNeedles =
        [ "runtime-owner"
        , "pid-file"
        , "pidFile"
        , ".lock"
        , "readFile"
        , "writeFile"
        , "createDirectory"
        , "System.Directory"
        , "System.FilePath"
        , "System.Process"
        ]
      coreSourceTokens = sourceIdentifierTokens coreSources
      standaloneForbiddenPackageMatches =
        filter (`Text.isInfixOf` standaloneCoreSection) standaloneForbiddenPackageNeedles
      forbiddenConcreteTokenMatches =
        filter (`elem` coreSourceTokens) forbiddenConcreteTypes
      forbiddenConcreteNeedleMatches =
        filter (`Text.isInfixOf` coreSources) forbiddenConcreteNeedles
      standaloneCoreDependencyPackages = cabalBuildDependsPackages standaloneCoreSection
      unapprovedStandaloneCoreDependencyMatches =
        filter (`notElem` ["base", "bytestring", "text"]) standaloneCoreDependencyPackages
      standaloneExposedModules = cabalExposedModules standaloneCoreSection
      standaloneModuleInventoryMismatches =
        inventoryMismatches "agent-workflow-core exposed modules" (sort coreSourceModules) (sort standaloneExposedModules)
      expectedStandaloneModuleMismatches =
        inventoryMismatches "agent-workflow-core approved modules" (sort coreStandaloneExposedModules) (sort standaloneExposedModules)
      standaloneDependsOnlyOnCoreDeps =
        all (`elem` standaloneCoreDependencyPackages) ["base", "bytestring", "text"]
          && null unapprovedStandaloneCoreDependencyMatches
      standaloneMetadataMatchesPolicy =
        all
          (`Text.isInfixOf` standaloneCabalSource)
          [ "name:          agent-workflow-core"
          , "version:       0.1.0.0"
          , "license:       MIT"
          , "author:        soulomoon"
          , "maintainer:    soulomoon"
          , "category:      Development"
          , "build-type:    Simple"
          , "location: https://github.com/soulomoon/moifold.git"
          , "hs-source-dirs:   src"
          ]
  standalonePackageOk <-
    assertNoTextMatches
      "standalone workflow core package excludes forbidden package dependencies"
      standaloneForbiddenPackageMatches
  standaloneApprovedDependencyOk <-
    assertNoTextMatches
      "standalone workflow core package excludes unapproved package dependencies"
      unapprovedStandaloneCoreDependencyMatches
  importOk <-
    assertNoTextMatches
      "workflow core source excludes forbidden concrete imports"
      forbiddenImportViolations
  tokenOk <-
    assertNoTextMatches
      "workflow core source excludes concrete lifecycle action and event tokens"
      forbiddenConcreteTokenMatches
  ownershipNeedleOk <-
    assertNoTextMatches
      "workflow core source excludes concrete daemon ownership text"
      forbiddenConcreteNeedleMatches
  standaloneInventoryOk <-
    assertNoTextMatches
      "standalone workflow core package exposed modules match recursive source tree"
      standaloneModuleInventoryMismatches
  standaloneExposedOk <-
    assertNoTextMatches
      "standalone workflow core package exposes generic core modules"
      expectedStandaloneModuleMismatches
  standaloneCoreDepsOk <-
    assert
      "standalone workflow core package keeps the approved generic dependency set"
      standaloneDependsOnlyOnCoreDeps
  standaloneMetadataOk <-
    assert
      "standalone workflow core package records approved metadata and source layout"
      standaloneMetadataMatchesPolicy
  pure
    ( standalonePackageOk
        && standaloneApprovedDependencyOk
        && importOk
        && tokenOk
        && ownershipNeedleOk
        && standaloneInventoryOk
        && standaloneExposedOk
        && standaloneCoreDepsOk
        && standaloneMetadataOk
    )

coreStandaloneExposedModules :: [Text]
coreStandaloneExposedModules =
  [ "CodexWatcher.Workflow.Audit"
  , "CodexWatcher.Workflow.Codec"
  , "CodexWatcher.Workflow.Daemon.Core"
  , "CodexWatcher.Workflow.DSL"
  , "CodexWatcher.Workflow.EventLog.Commit.Core"
  , "CodexWatcher.Workflow.EventLog.Core"
  , "CodexWatcher.Workflow.EventLog.File.Core"
  , "CodexWatcher.Workflow.Execution.Core"
  , "CodexWatcher.Workflow.Failure"
  , "CodexWatcher.Workflow.Indexed.Spec"
  , "CodexWatcher.Workflow.Permission.Core"
  , "CodexWatcher.Workflow.Spec"
  , "CodexWatcher.Workflow.Transaction.Core"
  ]

coreBoundaryForbiddenImportModules :: [Text]
coreBoundaryForbiddenImportModules =
  [ "CodexWatcher.Core.State"
  , "CodexWatcher.Domain."
  , "CodexWatcher.Effects"
  , "CodexWatcher.EventLog"
  , "CodexWatcher.Observation"
  , "CodexWatcher.StateMachine"
  , "CodexWatcher.Workflow.Moifold"
  , "CodexWatcher.Workflow.Observation"
  , "Data.Aeson"
  , "Data.Aeson.Key"
  , "Data.Aeson.KeyMap"
  , "Data.Aeson.Types"
  , "CodexWatcher.ActionExecutor"
  , "CodexWatcher.Runtime"
  , "CodexWatcher.EffectInterpreter"
  , "CodexWatcher.Runtime.Command"
  , "CodexWatcher.Runtime.Interpreter"
  , "CodexWatcher.GhGit"
  , "CodexWatcher.Workflow.GitHub"
  , "CodexWatcher.AppServerClient"
  , "CodexWatcher.AppServerProtocol"
  , "CodexWatcher.Workflow.Agent"
  , "CodexWatcher.Workflow.Agent.Codex"
  , "CodexWatcher.Workflow.Observation.Agent"
  , "CodexWatcher.Daemon"
  , "CodexWatcher.DaemonLoop"
  , "CodexWatcher.ChildDaemon"
  , "CodexWatcher.Healthcheck"
  , "CodexWatcher.EventLogRepair"
  , "CodexWatcher.RunnerGuard"
  , "CodexWatcher.WatcherRuntimeStatus"
  , "CodexWatcher.Supervisor"
  ]

workflowCodexStandalonePackageKeepsPackageBoundary :: IO Bool
workflowCodexStandalonePackageKeepsPackageBoundary = do
  standaloneCabalSource <- Text.pack <$> readFile ("agent-workflow-codex" </> "agent-workflow-codex.cabal")
  codexSources <- sourceTextUnder ("agent-workflow-codex" </> "src")
  codexSourceModules <- sourceModulesUnder ("agent-workflow-codex" </> "src")
  forbiddenImportViolations <-
    sourceImportViolationsUnder
      ("agent-workflow-codex" </> "src")
      codexBoundaryForbiddenImportModules
  let standaloneCodexSection = cabalComponentSection "library" standaloneCabalSource
      standaloneForbiddenPackageNeedles =
        [ "containers"
        , "directory"
        , "filepath"
        , "optparse-applicative"
        , "singletons"
        , "typed-process"
        , "unix"
        , "moifold,"
        , "moifold:"
        ]
      forbiddenSourceNeedles =
        [ "CodexWatcher.AppServerClient"
        , "CodexWatcher.ActionExecutor"
        , "CodexWatcher.ChildDaemon"
        , "CodexWatcher.Daemon"
        , "CodexWatcher.DaemonLoop"
        , "CodexWatcher.Domain."
        , "CodexWatcher.Effects"
        , "CodexWatcher.EventLog"
        , "CodexWatcher.EventLogRepair"
        , "CodexWatcher.GhGit"
        , "CodexWatcher.Healthcheck"
        , "CodexWatcher.Runtime."
        , "CodexWatcher.StateMachine"
        , "CodexWatcher.Workflow.GitHub"
        , "CodexWatcher.Workflow.Moifold."
        , "issue-state.json"
        , "daemon-state.json"
        , "planning-state.json"
        , "pr-url"
        , "block-state"
        , "repair-state"
        , "runtime-owner"
        ]
      forbiddenConcreteTypes =
        [ "WatcherEvent"
        , "SomeWatcherState"
        ]
      codexSourceTokens = sourceIdentifierTokens codexSources
      standaloneForbiddenPackageMatches =
        filter (`Text.isInfixOf` standaloneCodexSection) standaloneForbiddenPackageNeedles
      forbiddenSourceMatches =
        filter (`Text.isInfixOf` codexSources) forbiddenSourceNeedles
      forbiddenConcreteTypeMatches =
        filter (`elem` codexSourceTokens) forbiddenConcreteTypes
      standaloneCodexDependencyPackages = cabalBuildDependsPackages standaloneCodexSection
      unapprovedStandaloneCodexDependencyMatches =
        filter (`notElem` ["aeson", "agent-workflow-core", "base", "bytestring", "text", "websockets"]) standaloneCodexDependencyPackages
      standaloneExposedModules = cabalExposedModules standaloneCodexSection
      standaloneModuleInventoryMismatches =
        inventoryMismatches "agent-workflow-codex exposed modules" (sort codexSourceModules) (sort standaloneExposedModules)
      expectedStandaloneModuleMismatches =
        inventoryMismatches "agent-workflow-codex approved modules" (sort codexStandaloneExposedModules) (sort standaloneExposedModules)
      standaloneDependsOnlyOnCodexDeps =
        all (`elem` standaloneCodexDependencyPackages) ["aeson", "agent-workflow-core", "base", "bytestring", "text", "websockets"]
          && null unapprovedStandaloneCodexDependencyMatches
      standaloneMetadataMatchesPolicy =
        all
          (`Text.isInfixOf` standaloneCabalSource)
          [ "name:          agent-workflow-codex"
          , "version:       0.1.0.0"
          , "license:       MIT"
          , "author:        soulomoon"
          , "maintainer:    soulomoon"
          , "category:      Development"
          , "build-type:    Simple"
          , "location: https://github.com/soulomoon/moifold.git"
          , "hs-source-dirs:   src"
          , "agent-workflow-core >=0.1 && <0.2"
          ]
  standalonePackageOk <-
    assertNoTextMatches
      "standalone workflow Codex package excludes forbidden package dependencies"
      standaloneForbiddenPackageMatches
  standaloneApprovedDependencyOk <-
    assertNoTextMatches
      "standalone workflow Codex package excludes unapproved package dependencies"
      unapprovedStandaloneCodexDependencyMatches
  importOk <-
    assertNoTextMatches
      "workflow Codex source excludes moifold lifecycle imports"
      forbiddenImportViolations
  sourceOk <-
    assertNoTextMatches
      "workflow Codex source excludes moifold lifecycle ownership text"
      forbiddenSourceMatches
  concreteTypeOk <-
    assertNoTextMatches
      "workflow Codex source excludes concrete watcher state and event tokens"
      forbiddenConcreteTypeMatches
  standaloneInventoryOk <-
    assertNoTextMatches
      "standalone workflow Codex package exposed modules match recursive source tree"
      standaloneModuleInventoryMismatches
  standaloneExposedOk <-
    assertNoTextMatches
      "standalone workflow Codex package exposes adapter API modules"
      expectedStandaloneModuleMismatches
  standaloneCodexDepsOk <-
    assert
      "standalone workflow Codex package keeps the approved adapter dependency set"
      standaloneDependsOnlyOnCodexDeps
  standaloneMetadataOk <-
    assert
      "standalone workflow Codex package records approved metadata and source layout"
      standaloneMetadataMatchesPolicy
  pure
    ( standalonePackageOk
        && standaloneApprovedDependencyOk
        && importOk
        && sourceOk
        && concreteTypeOk
        && standaloneInventoryOk
        && standaloneExposedOk
        && standaloneCodexDepsOk
        && standaloneMetadataOk
    )

codexStandaloneExposedModules :: [Text]
codexStandaloneExposedModules =
  [ "CodexWatcher.AppServerProtocol"
  , "CodexWatcher.Workflow.Agent"
  , "CodexWatcher.Workflow.Agent.Codex"
  , "CodexWatcher.Workflow.Agent.Codex.Client"
  , "CodexWatcher.Workflow.Agent.Codex.Interpreter"
  , "CodexWatcher.Workflow.Agent.Codex.Protocol"
  , "CodexWatcher.Workflow.Agent.Codex.Transport"
  , "CodexWatcher.Workflow.Agent.Ids"
  , "CodexWatcher.Workflow.Agent.Types"
  , "CodexWatcher.Workflow.Observation.Agent"
  ]

codexBoundaryForbiddenImportModules :: [Text]
codexBoundaryForbiddenImportModules =
  [ "CodexWatcher.AppServerClient"
  , "CodexWatcher.ActionExecutor"
  , "CodexWatcher.ChildDaemon"
  , "CodexWatcher.Daemon"
  , "CodexWatcher.DaemonLoop"
  , "CodexWatcher.Domain."
  , "CodexWatcher.Effects"
  , "CodexWatcher.EventLog"
  , "CodexWatcher.EventLogRepair"
  , "CodexWatcher.GhGit"
  , "CodexWatcher.Healthcheck"
  , "CodexWatcher.Runtime."
  , "CodexWatcher.StateMachine"
  , "CodexWatcher.Workflow.GitHub"
  , "CodexWatcher.Workflow.Moifold."
  , "CodexWatcher.Workflow.Types"
  ]

workflowGithubStandalonePackageKeepsPackageBoundary :: IO Bool
workflowGithubStandalonePackageKeepsPackageBoundary = do
  standaloneCabalSource <- Text.pack <$> readFile ("agent-workflow-github" </> "agent-workflow-github.cabal")
  githubSourceModules <- sourceModulesUnder ("agent-workflow-github" </> "src")
  importViolations <-
    sourceImportViolationsUnder
      ("agent-workflow-github" </> "src")
      githubForbiddenImportModules
  ownershipViolations <-
    sourceTextNeedleViolationsUnder
      ("agent-workflow-github" </> "src")
      githubForbiddenOwnershipTokens
  let standaloneGithubSection = cabalComponentSection "library" standaloneCabalSource
      standaloneForbiddenPackageNeedles =
        [ "bytestring"
        , "containers"
        , "directory"
        , "filepath"
        , "optparse-applicative"
        , "singletons"
        , "typed-process"
        , "unix"
        , "websockets"
        , "moifold,"
        , "moifold:"
        , "agent-workflow-core"
        , "agent-workflow-codex"
        ]
      standaloneGithubDependencyPackages = cabalBuildDependsPackages standaloneGithubSection
      unapprovedStandaloneGithubDependencyMatches =
        filter (`notElem` ["aeson", "base", "text"]) standaloneGithubDependencyPackages
      standaloneExposedModules = cabalExposedModules standaloneGithubSection
      standaloneModuleInventoryMismatches =
        inventoryMismatches "agent-workflow-github exposed modules" (sort githubSourceModules) (sort standaloneExposedModules)
      expectedStandaloneModuleMismatches =
        inventoryMismatches "agent-workflow-github approved modules" (sort githubStandaloneExposedModules) (sort standaloneExposedModules)
      standaloneDependsOnlyOnGithubDeps =
        all
          (`elem` standaloneGithubDependencyPackages)
          ["aeson", "base", "text"]
          && null unapprovedStandaloneGithubDependencyMatches
          && not (any (`Text.isInfixOf` standaloneGithubSection) standaloneForbiddenPackageNeedles)
      standaloneDependencyBoundsMatchPolicy =
        all
          (`Text.isInfixOf` standaloneGithubSection)
          [ "aeson >=2.2 && <3"
          , "base >=4.18 && <5"
          , "text >=2.0 && <3"
          ]
      standaloneMetadataMatchesPolicy =
        all
          (`Text.isInfixOf` standaloneCabalSource)
          [ "name:          agent-workflow-github"
          , "version:       0.1.0.0"
          , "license:       MIT"
          , "author:        soulomoon"
          , "maintainer:    soulomoon"
          , "category:      Development"
          , "build-type:    Simple"
          , "location: https://github.com/soulomoon/moifold.git"
          , "hs-source-dirs:   src"
          ]
  standaloneInventoryOk <-
    assertNoTextMatches
      "standalone workflow GitHub package exposed modules match recursive source tree"
      standaloneModuleInventoryMismatches
  standaloneExposedOk <-
    assertNoTextMatches
      "standalone workflow GitHub package exposes only adapter modules"
      expectedStandaloneModuleMismatches
  standaloneDependencyOk <-
    assert
      "standalone workflow GitHub package keeps the approved adapter dependency set"
      (standaloneDependsOnlyOnGithubDeps && standaloneDependencyBoundsMatchPolicy)
  standaloneMetadataOk <-
    assert
      "standalone workflow GitHub package records approved metadata and source layout"
      standaloneMetadataMatchesPolicy
  importsOk <-
    assertNoTextMatches
      "workflow GitHub source has no moifold state-machine, daemon, lifecycle, runtime, or compatibility imports"
      importViolations
  ownershipOk <-
    assertNoTextMatches
      "workflow GitHub source has no moifold lifecycle ownership tokens"
      ownershipViolations
  pure
    ( standaloneInventoryOk
        && standaloneExposedOk
        && standaloneDependencyOk
        && standaloneMetadataOk
        && importsOk
        && ownershipOk
    )

githubStandaloneExposedModules :: [Text]
githubStandaloneExposedModules =
  [ "CodexWatcher.Workflow.GitHub.Command"
  , "CodexWatcher.Workflow.GitHub.Ids"
  , "CodexWatcher.Workflow.GitHub.Remote"
  ]

githubForbiddenImportModules :: [Text]
githubForbiddenImportModules =
  [ "CodexWatcher.AppServer"
  , "CodexWatcher.AppServerClient"
  , "CodexWatcher.AppServerProtocol"
  , "CodexWatcher.ChildDaemon"
  , "CodexWatcher.Cli"
  , "CodexWatcher.Core."
  , "CodexWatcher.Daemon"
  , "CodexWatcher.DaemonLoop"
  , "CodexWatcher.Domain"
  , "CodexWatcher.EffectInterpreter"
  , "CodexWatcher.Effects"
  , "CodexWatcher.EventLog"
  , "CodexWatcher.EventLogRepair"
  , "CodexWatcher.GhGit"
  , "CodexWatcher.Healthcheck"
  , "CodexWatcher.Json"
  , "CodexWatcher.Logging"
  , "CodexWatcher.Observation"
  , "CodexWatcher.Runtime"
  , "CodexWatcher.StateMachine"
  , "CodexWatcher.Supervisor"
  , "CodexWatcher.Turn"
  , "CodexWatcher.TurnOutput"
  , "CodexWatcher.WatcherLiveness"
  , "CodexWatcher.WatcherRuntimeStatus"
  , "CodexWatcher.Workflow.Agent"
  , "CodexWatcher.Workflow.Daemon"
  , "CodexWatcher.Workflow.EventLog"
  , "CodexWatcher.Workflow.Execution"
  , "CodexWatcher.Workflow.Moifold"
  , "CodexWatcher.Workflow.Observation"
  , "CodexWatcher.Workflow.Permission"
  , "CodexWatcher.Workflow.Transaction"
  , "CodexWatcher.Workflow.Types"
  ]

githubForbiddenOwnershipTokens :: [Text]
githubForbiddenOwnershipTokens =
  [ "WatcherEvent"
  , "SomeWatcherState"
  , "RuntimeCommand"
  , "RuntimeInterpreter"
  , "CommandReport"
  , "IssueConfig"
  , "PrConfig"
  , "ReviewEvidence"
  , "CleanReviewEvidence"
  , "Healthcheck"
  , "EventLogRepair"
  , "runtime-owner"
  , "daemon-state.json"
  , "issue-state.json"
  , "planning-state.json"
  , "watcher-state.json"
  , "block-state.json"
  , "app-server"
  ]

workflowMoifoldCabalLibraryDoesNotReexportAdapters :: IO Bool
workflowMoifoldCabalLibraryDoesNotReexportAdapters = do
  cabalSource <- Text.pack <$> readFile "moifold.cabal"
  appServerCompatibilitySource <- Text.pack <$> readFile ("src" </> "CodexWatcher" </> "AppServerClient.hs")
  let mainLibrarySection = cabalComponentSection "library" cabalSource
      adapterModuleNeedles =
        [ "CodexWatcher.AppServerProtocol"
        , "CodexWatcher.Workflow.Agent"
        , "CodexWatcher.Workflow.Agent.Codex"
        , "CodexWatcher.Workflow.Agent.Codex.Protocol"
        , "CodexWatcher.Workflow.Agent.Ids"
        , "CodexWatcher.Workflow.Agent.Types"
        , "CodexWatcher.Workflow.Observation.Agent"
        , "CodexWatcher.Workflow.GitHub.Ids"
        ]
      noAdapterReexports =
        not ("reexported-modules:" `Text.isInfixOf` mainLibrarySection)
          && not (any (`Text.isInfixOf` mainLibrarySection) adapterModuleNeedles)
      keepsAdapterDependencies =
        all
          (`Text.isInfixOf` mainLibrarySection)
          [ "agent-workflow-codex >=0.1 && <0.2"
          , "agent-workflow-github >=0.1 && <0.2"
          ]
      mainLibraryDoesNotOwnAppServerTransport =
        not ("websockets" `Text.isInfixOf` mainLibrarySection)
          && "import CodexWatcher.Workflow.Agent.Codex.Transport" `Text.isInfixOf` appServerCompatibilitySource
          && "import CodexWatcher.Workflow.Agent.Codex.Client" `Text.isInfixOf` appServerCompatibilitySource
          && not ("Network.WebSockets" `Text.isInfixOf` appServerCompatibilitySource)
          && not ("data AppServerEndpoint" `Text.isInfixOf` appServerCompatibilitySource)
          && not ("newtype AppServerConnection" `Text.isInfixOf` appServerCompatibilitySource)
  assert
    "main moifold library does not reexport workflow adapter modules or own app-server transport"
    (noAdapterReexports && keepsAdapterDependencies && mainLibraryDoesNotOwnAppServerTransport)

workflowGithubCommandFacadeMatchesRuntimeRender :: IO Bool
workflowGithubCommandFacadeMatchesRuntimeRender = do
  let repo = RepoName "soulomoon/mlf2"
      issue = IssueNumber 42
      pr = PrNumber 6
      branch = BranchName "codex/example"
      thread = ReviewThreadId "PRRT_test"
      prConfig = PrConfig repo pr branch
      checks =
        [ (renderRuntimeCommand GhAuthStatus, WorkflowGitHubCommand.ghAuthStatusCommand)
        , (renderRuntimeCommand GhApiUser, WorkflowGitHubCommand.ghApiUserCommand)
        , (renderRuntimeCommand (GhIssueListOpen repo), WorkflowGitHubCommand.ghIssueListOpenCommand repo)
        , (renderRuntimeCommand (GhIssueView repo issue WorkflowGitHubCommand.ghIssueViewStateFields), WorkflowGitHubCommand.ghIssueViewCommand repo issue WorkflowGitHubCommand.ghIssueViewStateFields)
        , (renderRuntimeCommand (GhPrListOpen repo), WorkflowGitHubCommand.ghPrListOpenCommand repo)
        , (renderRuntimeCommand (GhPrListByHead repo branch "all"), WorkflowGitHubCommand.ghPrListByHeadCommand repo branch "all")
        , (renderRuntimeCommand (GhPrView repo pr ["state", "url"]), WorkflowGitHubCommand.ghPrViewCommand repo pr ["state", "url"])
        , (renderRuntimeCommand (GhPrView repo pr WorkflowGitHubCommand.ghPrViewRemoteFields), WorkflowGitHubCommand.ghPrViewCommand repo pr WorkflowGitHubCommand.ghPrViewRemoteFields)
        , (renderRuntimeCommand (GhPrView repo pr WorkflowGitHubCommand.ghPrViewMergeMetadataFields), WorkflowGitHubCommand.ghPrViewCommand repo pr WorkflowGitHubCommand.ghPrViewMergeMetadataFields)
        , (renderRuntimeCommand (GhPrChecks repo pr), WorkflowGitHubCommand.ghPrChecksCommand repo pr)
        , (renderRuntimeCommand (GhReviewThreads prConfig), WorkflowGitHubCommand.ghReviewThreadsCommand repo pr)
        , (renderRuntimeCommand (GhResolveReviewThread thread), WorkflowGitHubCommand.ghResolveReviewThreadCommand thread)
        , (renderRuntimeCommand (GhReplyReviewThread thread "still applies"), WorkflowGitHubCommand.ghReplyReviewThreadCommand thread "still applies")
        , (renderRuntimeCommand (GhPrMerge repo pr "squash"), WorkflowGitHubCommand.ghPrMergeCommand repo pr "squash")
        , (renderRuntimeCommand (GitBranchCurrent "/tmp/work"), WorkflowGitHubCommand.gitBranchCurrentCommand "/tmp/work")
        , (renderRuntimeCommand (GitRevParseHead "/tmp/work"), WorkflowGitHubCommand.gitRevParseHeadCommand "/tmp/work")
        , (renderRuntimeCommand (GitStatusPorcelain "/tmp/work"), WorkflowGitHubCommand.gitStatusPorcelainCommand "/tmp/work")
        , (renderRuntimeCommand (GitLsRemoteBranch "/tmp/work" branch), WorkflowGitHubCommand.gitLsRemoteBranchCommand "/tmp/work" branch)
        , (renderRuntimeCommand (GitPushDryRun "/tmp/work" branch), WorkflowGitHubCommand.gitPushDryRunCommand "/tmp/work" branch)
        , (renderRuntimeCommand (GitPush "/tmp/work" branch), WorkflowGitHubCommand.gitPushCommand "/tmp/work" branch)
        ]
  assert
    "workflow GitHub command facade matches runtime render"
    (all commandSpecMatches checks)

commandSpecMatches :: (RuntimeCommandSpec, WorkflowGitHubCommand.GitHubCommandSpec) -> Bool
commandSpecMatches (runtimeSpec, githubSpec) =
  runtimeSpec.command == githubSpec.githubCommand
    && runtimeSpec.args == githubSpec.githubCommandArgs
    && runtimeSpec.cwd == githubSpec.githubCommandCwd
    && runtimeSpec.stdin == githubSpec.githubCommandStdin

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
      detailed = WorkflowEventLog.replayWorkflowEventLogDetailed @MoifoldSpec id events
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
        WorkflowEventLog.EventLogFixtureContract
          { WorkflowEventLog.fixtureExpectedStateLabel = "PrReview/WaitingMergeability"
          , WorkflowEventLog.fixtureExpectedEventCount = Just 3
          }
  assert "workflow event-log core fixture contract validates replay summary" $
    case WorkflowEventLog.replayWorkflowEventLogDetailed @MoifoldSpec id events of
      Right summary -> WorkflowEventLog.validateEventLogFixtureContract @MoifoldSpec contract summary == Right ()
      Left _ -> False

workflowEventLogCoreTransitionContractsMatchFacades :: IO Bool
workflowEventLogCoreTransitionContractsMatchFacades = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      initialized = PrReviewInitialized prConfig (ThreadId "worker") (ThreadId "reviewer")
      noUnresolved = PrReviewNoUnresolvedFound (CommitSha "abc123") (TurnId "reviewer-turn")
      moifoldCoreInitial = WorkflowEventLog.initializeWorkflowEvent @MoifoldSpec id initialized
      moifoldFacadeInitial = WorkflowEventLog.initializeMoifoldWorkflow initialized
      docsConfig =
        DocsMigration.DocsMigrationConfig
          { DocsMigration.docsMigrationSource = "docs/source.md"
          , DocsMigration.docsMigrationTarget = "docs/target.md"
          , DocsMigration.docsMigrationGoal = "migrate framework notes"
          }
      docsInitialized = DocsMigration.DocsMigrationInitialized docsConfig
      docsTurnStarted = DocsMigration.DocsMigrationTurnStarted (ThreadId "docs-thread") (TurnId "docs-turn")
      docsCoreInitial = WorkflowEventLog.initializeWorkflowEvent @DocsMigration.DocsMigrationSpec id docsInitialized
  results <-
    sequence
      [ assert "workflow event-log core initialize matches moifold facade" $
          case (moifoldCoreInitial, moifoldFacadeInitial) of
            (Right (coreState, coreEffects), Right (facadeState, facadeEffects)) ->
              someDomain coreState == someDomain facadeState
                && somePhase coreState == somePhase facadeState
                && coreEffects == facadeEffects
            _ -> False
      , assert "workflow event-log core apply matches moifold facade" $
          case (moifoldCoreInitial, moifoldFacadeInitial) of
            (Right (coreState, _), Right (facadeState, _)) ->
              case (WorkflowEventLog.applyWorkflowEvent @MoifoldSpec id coreState noUnresolved, WorkflowEventLog.applyMoifoldWorkflowEvent facadeState noUnresolved) of
                (Right (coreState', coreEffects), Right (facadeState', facadeEffects)) ->
                  someDomain coreState' == someDomain facadeState'
                    && somePhase coreState' == somePhase facadeState'
                    && coreEffects == facadeEffects
                _ -> False
            _ -> False
      , assert "workflow event-log core transition failure records moifold state and event labels" $
          case moifoldCoreInitial of
            Right (state, _) ->
              case WorkflowEventLog.applyWorkflowEvent @MoifoldSpec id state initialized of
                Left failure ->
                  WorkflowEventLog.workflowTransitionEventLabel failure == "pr_review_initialized"
                    && WorkflowEventLog.workflowTransitionPriorStateLabel failure == Just (workflowStateLabel @MoifoldSpec state)
                    && not (Text.null (WorkflowEventLog.workflowTransitionReason failure))
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
              case WorkflowEventLog.applyWorkflowEvent @DocsMigration.DocsMigrationSpec id state docsTurnStarted of
                Right (state', effects) ->
                  state' == DocsMigration.DocsMigrationTurnActive docsConfig (WorkflowAgent.TurnRef (ThreadId "docs-thread") (TurnId "docs-turn"))
                    && effects == []
                Left _ -> False
            Left _ -> False
      , assert "workflow event-log core transition failure records docs-migration state and event labels" $
          case docsCoreInitial of
            Right (state, _) ->
              case WorkflowEventLog.applyWorkflowEvent @DocsMigration.DocsMigrationSpec id state (DocsMigration.DocsMigrationValidationPassed "too early") of
                Left failure ->
                  WorkflowEventLog.workflowTransitionEventLabel failure == "docs-migration-validation-passed"
                    && WorkflowEventLog.workflowTransitionPriorStateLabel failure == Just "ready"
                    && "ready" `Text.isInfixOf` WorkflowEventLog.formatWorkflowTransitionFailure failure
                Right _ -> False
            Left _ -> False
      ]
  pure (and results)

cabalComponentSection :: Text -> Text -> Text
cabalComponentSection componentName cabalSource =
  case dropWhile (/= componentName) (Text.lines cabalSource) of
    [] -> ""
    _component : rest ->
      Text.unlines (takeWhile (not . isTopLevelComponent) rest)
 where
  isTopLevelComponent line =
    not (Text.null line)
      && not (" " `Text.isPrefixOf` line)
      && any
        (`Text.isPrefixOf` line)
        [ "common "
        , "library"
        , "executable "
        , "test-suite "
        , "benchmark "
        ]

cabalFieldLines :: Text -> Text -> [Text]
cabalFieldLines fieldName cabalSource =
  case dropWhile (not . isNamedField) (Text.lines cabalSource) of
    [] -> []
    fieldLine : rest ->
      let fieldIndent = Text.length (Text.takeWhile (== ' ') fieldLine)
          fieldValue =
            Text.strip
              . Text.drop 1
              . Text.dropWhile (/= ':')
              $ fieldLine
          continuationLines =
            fmap Text.strip $
              takeWhile
                ( \line ->
                    not (Text.null (Text.strip line))
                      && Text.length (Text.takeWhile (== ' ') line) > fieldIndent
                )
                rest
       in fieldValue : continuationLines
 where
  isNamedField line =
    (fieldName <> ":") `Text.isPrefixOf` Text.strip line

cabalFieldEntries :: Text -> Text -> [Text]
cabalFieldEntries fieldName =
  filter (not . Text.null)
    . Text.words
    . Text.replace "," " "
    . Text.unlines
    . cabalFieldLines fieldName

cabalExposedModules :: Text -> [Text]
cabalExposedModules =
  cabalFieldEntries "exposed-modules"

cabalBuildDependsPackages :: Text -> [Text]
cabalBuildDependsPackages componentSection =
  filter (not . Text.null)
    . fmap (Text.takeWhile isCabalDependencyPackageChar . Text.strip)
    . Text.splitOn ","
    . Text.intercalate "\n"
    $ cabalFieldLines "build-depends" componentSection

isCabalDependencyPackageChar :: Char -> Bool
isCabalDependencyPackageChar character =
  isAlphaNum character || character == '-' || character == '_' || character == ':'

inventoryMismatches :: Text -> [Text] -> [Text] -> [Text]
inventoryMismatches inventoryName expected actual =
  [ inventoryName <> " missing: " <> Text.intercalate ", " missing
  | not (null missing)
  ]
    <> [ inventoryName <> " extra: " <> Text.intercalate ", " extra
       | not (null extra)
       ]
 where
  missing = expected \\ actual
  extra = actual \\ expected

assertNoTextMatches :: String -> [Text] -> IO Bool
assertNoTextMatches assertionName matches = do
  when (not (null matches)) $
    mapM_ (putStrLn . ("  " <>) . Text.unpack) matches
  assert assertionName (null matches)

textNeedlesInOrder :: [Text] -> Text -> Bool
textNeedlesInOrder [] _source =
  True
textNeedlesInOrder (needle : rest) source =
  case Text.breakOn needle source of
    (_before, after)
      | Text.null after -> False
      | otherwise -> textNeedlesInOrder rest (Text.drop (Text.length needle) after)

sourceImportViolationsUnder :: FilePath -> [Text] -> IO [Text]
sourceImportViolationsUnder root forbiddenModules = do
  files <- sourceFilesUnder root
  fmap concat $
    traverse
      ( \path -> do
          source <- Text.pack <$> readFile path
          pure (sourceImportViolationsIn path forbiddenModules source)
      )
      files

sourceImportViolationsIn :: FilePath -> [Text] -> Text -> [Text]
sourceImportViolationsIn path forbiddenModules source =
  concatMap lineViolation (zip [(1 :: Int) ..] (Text.lines source))
 where
  pathText = Text.pack path
  lineViolation (lineNumber, line) =
    case sourceImportedModule line of
      Nothing -> []
      Just moduleName ->
        case filter (`forbiddenModuleMatches` moduleName) forbiddenModules of
          [] -> []
          forbiddenModule : _ ->
            [ pathText
                <> ":"
                <> Text.pack (show lineNumber)
                <> ": "
                <> moduleName
                <> " matches "
                <> forbiddenModule
            ]

sourceTextNeedleViolationsUnder :: FilePath -> [Text] -> IO [Text]
sourceTextNeedleViolationsUnder root forbiddenNeedles = do
  files <- sourceFilesUnder root
  fmap concat $
    traverse
      ( \path -> do
          source <- Text.pack <$> readFile path
          pure (sourceTextNeedleViolationsIn path forbiddenNeedles source)
      )
      files

sourceTextNeedleViolationsIn :: FilePath -> [Text] -> Text -> [Text]
sourceTextNeedleViolationsIn path forbiddenNeedles source =
  concatMap lineViolation (zip [(1 :: Int) ..] (Text.lines source))
 where
  pathText = Text.pack path
  lineViolation (lineNumber, line) =
    [ pathText
        <> ":"
        <> Text.pack (show lineNumber)
        <> ": contains "
        <> needle
    | needle <- forbiddenNeedles
    , needle `Text.isInfixOf` line
    ]

sourceImportedModule :: Text -> Maybe Text
sourceImportedModule line
  | Just rest <- Text.stripPrefix "import qualified " stripped =
      sourceImportedModuleFromRest rest
  | Just rest <- Text.stripPrefix "import " stripped =
      sourceImportedModuleFromRest rest
  | otherwise =
      Nothing
 where
  stripped = Text.strip line

sourceImportedModuleFromRest :: Text -> Maybe Text
sourceImportedModuleFromRest rest =
  let moduleName =
        Text.takeWhile isSourceModuleChar
          . dropPackageQualifier
          . Text.strip
          $ rest
   in if Text.null moduleName
        then Nothing
        else Just moduleName

dropPackageQualifier :: Text -> Text
dropPackageQualifier rest =
  case Text.stripPrefix "\"" rest of
    Just afterOpenQuote ->
      Text.strip
        . Text.drop 1
        . Text.dropWhile (/= '"')
        $ afterOpenQuote
    Nothing -> rest

forbiddenModuleMatches :: Text -> Text -> Bool
forbiddenModuleMatches forbiddenModule moduleName
  | "." `Text.isSuffixOf` forbiddenModule =
      moduleName == Text.dropEnd 1 forbiddenModule
        || forbiddenModule `Text.isPrefixOf` moduleName
  | otherwise =
      moduleName == forbiddenModule
        || (forbiddenModule <> ".") `Text.isPrefixOf` moduleName

isSourceModuleChar :: Char -> Bool
isSourceModuleChar character =
  isAlphaNum character || character == '_' || character == '\'' || character == '.'

sourceTextUnder :: FilePath -> IO Text
sourceTextUnder root = do
  files <- sourceFilesUnder root
  Text.intercalate "\n" <$> traverse (fmap Text.pack . readFile) files

sourceModulesUnder :: FilePath -> IO [Text]
sourceModulesUnder root = do
  files <- sourceFilesUnder root
  pure [moduleName | Just moduleName <- fmap (sourceModuleFromPath root) files]

sourceModuleFromPath :: FilePath -> FilePath -> Maybe Text
sourceModuleFromPath root path
  | ".hs" `Text.isSuffixOf` pathText =
      Just
        . Text.intercalate "."
        . fmap Text.pack
        . splitDirectories
        . dropExtension
        $ makeRelative root path
  | otherwise =
      Nothing
 where
  pathText = Text.pack path

sourceIdentifierTokens :: Text -> [Text]
sourceIdentifierTokens =
  filter (not . Text.null) . Text.split (not . isSourceIdentifierChar)
 where
  isSourceIdentifierChar character =
    isAlphaNum character || character == '_' || character == '\''

sourceFilesUnder :: FilePath -> IO [FilePath]
sourceFilesUnder root = do
  entries <- listDirectory root
  fmap concat $
    traverse
      ( \entry -> do
          let path = root </> entry
          isDirectory <- doesDirectoryExist path
          if isDirectory
            then sourceFilesUnder path
            else pure [path | ".hs" `Text.isSuffixOf` Text.pack path]
      )
      entries

workflowFacadeReplayMatchesEventLog :: IO Bool
workflowFacadeReplayMatchesEventLog = do
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
      specialized = WorkflowEventLog.replayMoifoldWorkflowEvents events
      generic = WorkflowEventLog.replayWorkflowEventLog @MoifoldSpec events
  results <-
    sequence
      [ assert "workflow replay facade preserves direct replay result" (sameReplay direct specialized)
      , assert "workflow spec replay facade preserves direct replay result" (sameReplayText direct generic)
      ]
  pure (and results)

workflowFacadeInitialApplyMatchesReplay :: IO Bool
workflowFacadeInitialApplyMatchesReplay = do
  let repo = RepoName "soulomoon/mlf2"
      prConfig = PrConfig repo (PrNumber 6) (BranchName "codex/pr-6")
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      commit = CommitSha "abc123"
      firstEvent = PrReviewInitialized prConfig workerThread reviewerThread
      secondEvent = PrReviewNoUnresolvedFound commit (TurnId "reviewer-turn")
      direct = replayEventLog [firstEvent, secondEvent]
      stepped = do
        (state0, _effects0) <- WorkflowEventLog.initializeMoifoldWorkflow firstEvent
        (state1, effects1) <- WorkflowEventLog.applyMoifoldWorkflowEvent state0 secondEvent
        pure (state1, effects1)
  results <-
    sequence
      [ assert "workflow event-log facade initializes and applies to replay state" $
          case (direct, stepped) of
            (Right replay, Right (state1, _effects1)) ->
              someDomain replay.replayState == someDomain state1
                && somePhase replay.replayState == somePhase state1
            _ -> False
      , assert "workflow event-log facade exposes transition effects" $
          case stepped of
            Right (_state1, effects1) -> hasEffect StartReviewerTurnTag effects1
            Left _ -> False
      ]
  pure (and results)

workflowPermissionFacadeMatchesStateMachine :: IO Bool
workflowPermissionFacadeMatchesStateMachine = do
  let plannerConfig = PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 2) [IssueNumber 12]
      planningGraph = PlanningGraph [IssueNumber 12] [] []
      state = SomeWatcherState (PlanningWaitingForReadyIssues plannerConfig planningGraph)
      effects = [SomeEffect (StartPlannerTurn (ThreadId "planner"))]
      direct = validatePhaseActionPlan state effects
      facade = WorkflowPermission.validateMoifoldEffectPlan state effects
  assert "workflow permission facade matches state-machine validation" (direct == facade)

workflowPermissionCoreChecksMatchMoifoldPermission :: IO Bool
workflowPermissionCoreChecksMatchMoifoldPermission = do
  let plannerConfig = PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 2) [IssueNumber 12]
      planningGraph = PlanningGraph [IssueNumber 12] [] []
      state = SomeWatcherState (PlanningWaitingForReadyIssues plannerConfig planningGraph)
      effects = [SomeEffect (StartPlannerTurn (ThreadId "planner"))]
      direct = validatePhaseActionPlan state effects
      core = WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec state effects
      checks = WorkflowPermission.workflowEffectPermissionChecks @MoifoldSpec state effects
  assert "workflow permission core checks match moifold validation" $
    case (direct, core, checks) of
      (Left directError, Left coreError, [check]) ->
        coreError.workflowPermissionStateLabel == directError.phaseActionState
          && coreError.workflowPermissionEffectLabel == directError.phaseActionEffect
          && coreError.workflowPermissionReason == formatPhaseActionValidationError directError
          && check.workflowPermissionCheckEffectLabel == directError.phaseActionEffect
          && check.workflowPermissionCheckResult == Left (formatPhaseActionValidationError directError)
      _ -> False

workflowPermissionPolicyMatchesMoifoldPermission :: IO Bool
workflowPermissionPolicyMatchesMoifoldPermission = do
  let plannerConfig = PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 2) [IssueNumber 12]
      planningGraph = PlanningGraph [IssueNumber 12] [] []
      deniedState = SomeWatcherState (PlanningWaitingForReadyIssues plannerConfig planningGraph)
      deniedEffects = [SomeEffect (StartPlannerTurn (ThreadId "planner"))]
      allowedState = SomeWatcherState (PlanningReady plannerConfig :: WatcherState 'IssuePlanning 'Initialized)
      allowedEffects = [SomeEffect (StartPlannerTurn (ThreadId "planner"))]
      deniedDirect = validatePhaseActionPlan deniedState deniedEffects
      deniedPolicy =
        WorkflowPermission.validateWorkflowEffectPlanWithPolicy
          WorkflowPermission.moifoldPermissionPolicy
          deniedState
          deniedEffects
      allowedPolicy =
        WorkflowPermission.validateWorkflowEffectPlanWithPolicy
          WorkflowPermission.moifoldPermissionPolicy
          allowedState
          allowedEffects
      allowedChecks =
        WorkflowPermission.workflowEffectPermissionChecksWithPolicy
          WorkflowPermission.moifoldPermissionPolicy
          allowedState
          allowedEffects
      deniedChecks =
        WorkflowPermission.workflowEffectPermissionChecksWithPolicy
          WorkflowPermission.moifoldPermissionPolicy
          deniedState
          deniedEffects
  results <-
    sequence
      [ assert "workflow permission policy accepts allowed moifold effects" $
          case (allowedPolicy, allowedChecks) of
            (Right (), [check]) ->
              check.workflowPermissionCheckStateLabel == workflowStateLabel @MoifoldSpec allowedState
                && check.workflowPermissionCheckEffectLabel == "StartPlannerTurn"
                && check.workflowPermissionCheckResult == Right ()
            _ -> False
      , assert "workflow permission policy rejects denied moifold effects like state machine" $
          case (deniedDirect, deniedPolicy, deniedChecks) of
            (Left directError, Left policyError, [check]) ->
              policyError.workflowPermissionStateLabel == directError.phaseActionState
                && policyError.workflowPermissionEffectLabel == directError.phaseActionEffect
                && policyError.workflowPermissionReason == formatPhaseActionValidationError directError
                && check.workflowPermissionCheckEffectLabel == directError.phaseActionEffect
                && check.workflowPermissionCheckResult == Left (formatPhaseActionValidationError directError)
            _ -> False
      ]
  pure (and results)

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
          , WorkflowAgent.plannerAgentRoleId
          )
        , ( "pr-review worker"
          , SomeEffect (StartWorkerTurn evidence thread)
          , WorkflowAgent.prReviewWorkerAgentRoleId
          )
        , ( "issue plan worker"
          , SomeEffect (StartIssuePlanWorkerTurn issueConfig (PrNumber 6) thread)
          , WorkflowAgent.issuePlanWorkerAgentRoleId
          )
        , ( "issue implementation worker"
          , SomeEffect (StartIssueImplementationWorkerTurn thread)
          , WorkflowAgent.issueImplementationWorkerAgentRoleId
          )
        , ( "reviewer"
          , SomeEffect (StartReviewerTurn prConfig commit thread)
          , WorkflowAgent.reviewerAgentRoleId
          )
        , ( "verification reviewer"
          , SomeEffect (StartReviewerVerificationTurn prConfig evidence commit thread)
          , WorkflowAgent.prReviewVerificationReviewerAgentRoleId
          )
        , ( "final reviewer"
          , SomeEffect (StartIssueFinalReviewTurn issueConfig (PrNumber 6) commit thread)
          , WorkflowAgent.finalReviewerAgentRoleId
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
          { WorkflowAgent.agentThreadPlanRoleId = WorkflowAgent.plannerAgentRoleId
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
            == Right (WorkflowAgent.AgentThreadStart WorkflowAgent.plannerAgentRoleId (ThreadId "thread-1"))
      , assert "workflow Codex adapter starts thread with interpreter" $
          started == Right (WorkflowAgent.AgentThreadStart WorkflowAgent.plannerAgentRoleId (ThreadId "thread-1"))
      ]
  pure (and results)

workflowAgentCodexParsesTurnLifecycle :: IO Bool
workflowAgentCodexParsesTurnLifecycle = do
  let plan =
        WorkflowAgent.AgentTurnPlan
          { WorkflowAgent.agentTurnPlanRoleId = WorkflowAgent.prReviewWorkerAgentRoleId
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
            == Right (WorkflowAgent.AgentTurnStart WorkflowAgent.prReviewWorkerAgentRoleId (ThreadId "thread-1") (TurnId "turn-1"))
      , assert "workflow Codex adapter exposes typed turn refs from starts" $
          case WorkflowAgentCodex.parseAgentTurnStart plan startValue of
            Right started ->
              (WorkflowAgent.agentTurnStartRef started :: WorkflowAgent.TurnRef WorkflowAgent.PrReviewWorkerAgent ())
                == WorkflowAgent.TurnRef (ThreadId "thread-1") (TurnId "turn-1")
            Left _ -> False
      , assert "workflow Codex adapter cached start response is used" $
          startedViaInterpreter
            == Right (WorkflowAgent.AgentTurnStart WorkflowAgent.prReviewWorkerAgentRoleId (ThreadId "thread-1") (TurnId "turn-1"))
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
                && WorkflowEventLog.workflowAuditCommittedEventLabel audit == Nothing
                && WorkflowEventLog.workflowAuditPriorStateLabel audit == workflowStateLabel @MoifoldSpec state
                && WorkflowEventLog.workflowAuditFinalStateLabel audit == Just "IssuePlanning/PlanMode"
                && WorkflowEventLog.workflowAuditPreCommitReports audit == expectedReports
                && WorkflowEventLog.workflowAuditPostCommitReports audit == []
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
              WorkflowEventLog.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just "issue_planning_turn_started"
                && WorkflowEventLog.workflowAuditPreCommitReports tick.daemonObservedAudit == tick.daemonObservedActionReports
                && WorkflowEventLog.workflowAuditPostCommitReports tick.daemonObservedAudit == []
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
                  && WorkflowEventLog.workflowAuditCommittedEventLabel audit == Nothing
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
                WorkflowEventLog.workflowAuditPriorStateLabel tick.daemonObservedAudit == "IssuePlanning/PlanMode"
                  && WorkflowEventLog.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just "issue_planning_issues_requested"
                  && WorkflowEventLog.workflowAuditFinalStateLabel tick.daemonObservedAudit == Just "IssuePlanning/Initialized"
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
                WorkflowEventLog.workflowAuditPriorStateLabel tick.daemonObservedAudit == "IssuePlanning/PlanMode"
                  && WorkflowEventLog.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just "issue_planning_graph_updated"
                  && WorkflowEventLog.workflowAuditFinalStateLabel tick.daemonObservedAudit == Just "IssuePlanning/Initialized"
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
                WorkflowEventLog.workflowAuditPriorStateLabel tick.daemonObservedAudit == "IssuePlanning/PlanMode"
                  && WorkflowEventLog.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just "watcher_blocked"
                  && WorkflowEventLog.workflowAuditFinalStateLabel tick.daemonObservedAudit == Just "IssuePlanning/Blocked"
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
                  && WorkflowEventLog.workflowAuditCommittedEventLabel audit == Nothing
                  && WorkflowEventLog.workflowAuditPriorStateLabel audit == workflowStateLabel @MoifoldSpec state
                  && WorkflowEventLog.workflowAuditFinalStateLabel audit == Just expectedTargetLabel
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
                WorkflowEventLog.workflowAuditPriorStateLabel tick.daemonObservedAudit == workflowStateLabel @MoifoldSpec state
                  && WorkflowEventLog.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just (eventName expectedEvent)
                  && WorkflowEventLog.workflowAuditFinalStateLabel tick.daemonObservedAudit == Just expectedTargetLabel
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
                    && WorkflowEventLog.workflowAuditCommittedEventLabel audit == Nothing
                    && WorkflowEventLog.workflowAuditPriorStateLabel audit == workflowStateLabel @MoifoldSpec state
                    && WorkflowEventLog.workflowAuditFinalStateLabel audit == Just "PrReview/Merging"
                    && WorkflowEventLog.workflowAuditPreCommitReports audit == expectedReports
                    && WorkflowEventLog.workflowAuditPostCommitReports audit == []
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
                  WorkflowEventLog.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Just "pr_review_mergeability_clean"
                    && WorkflowEventLog.workflowAuditPreCommitReports tick.daemonObservedAudit == tick.daemonObservedActionReports
                    && WorkflowEventLog.workflowAuditPostCommitReports tick.daemonObservedAudit == []
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
                  (WorkflowEventLog.workflowAuditPriorStateLabel <$> audit) == Just (workflowStateLabel @MoifoldSpec state)
                    && (WorkflowEventLog.workflowAuditCommittedEventLabel <$> audit) == Just Nothing
                    && (WorkflowEventLog.workflowAuditFinalStateLabel <$> audit) == Just Nothing
                    && (WorkflowEventLog.workflowAuditNextDaemonRecommendation <$> audit) == Just WorkflowEventLog.WorkflowDaemonStop
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
                    && WorkflowEventLog.workflowAuditCommittedEventLabel tick.daemonObservedAudit == Nothing
                    && null calls
              ]
          ExecuteActions ->
            sequence
              [ assert (title "commits event and compatibility writes") $
                  tick.daemonObservedCommittedEvents == [tick.daemonObservedEvent]
                    && expectedAppend `elem` calls
                    && all (`elem` calls) expectedWriteCalls
                    && all (\writeCall -> callBefore expectedAppend writeCall calls) expectedWriteCalls
                    && WorkflowEventLog.workflowAuditCommittedEventLabel tick.daemonObservedAudit /= Nothing
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

workflowEventLogFailureAuditClassifiesRetryRecommendation :: IO Bool
workflowEventLogFailureAuditClassifiesRetryRecommendation = do
  let repo = RepoName "soulomoon/mlf2"
      plannerConfig = PlannerConfig repo (maxParallelForTest 2) []
      priorState = SomeWatcherState (PlanningReady plannerConfig :: WatcherState 'IssuePlanning 'Initialized)
      observation = DaemonIssuePlanningObservation (ObservedPlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn"))
      classification = FailureClassification TransientFailure "network EOF"
      audit =
        WorkflowEventLog.workflowFailureAudit @MoifoldSpec
          priorState
          (Just observation)
          Nothing
          Nothing
          []
          []
          classification
  assert "workflow event-log failure audit classifies retry recommendation" $
    WorkflowEventLog.workflowAuditPriorStateLabel audit == "IssuePlanning/Initialized"
      && maybe False ("ObservedPlanningTurnStarted" `Text.isInfixOf`) (WorkflowEventLog.workflowAuditObservationLabel audit)
      && WorkflowEventLog.workflowAuditFailureClassification audit == Just classification
      && WorkflowEventLog.workflowAuditNextDaemonRecommendation audit == WorkflowEventLog.WorkflowDaemonRetry

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

sameReplay :: Either ReplayFailure EventReplayResult -> Either ReplayFailure EventReplayResult -> Bool
sameReplay (Right left) (Right right) =
  someDomain left.replayState == someDomain right.replayState
    && somePhase left.replayState == somePhase right.replayState
    && left.replayEffects == right.replayEffects
sameReplay (Left left) (Left right) =
  left == right
sameReplay _ _ =
  False

sameReplayText :: Either ReplayFailure EventReplayResult -> Either Text EventReplayResult -> Bool
sameReplayText (Right left) (Right right) =
  someDomain left.replayState == someDomain right.replayState
    && somePhase left.replayState == somePhase right.replayState
    && left.replayEffects == right.replayEffects
sameReplayText (Left _) (Left _) =
  True
sameReplayText _ _ =
  False

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

observeOnceParsingCoversDomainsAndDefaults :: IO Bool
observeOnceParsingCoversDomainsAndDefaults = do
  planning <-
    parseDaemonObservation
      ( (baseObserveCli IssuePlanning "turn-started")
          { observeCliThreadId = Just (ThreadId "planner-thread")
          , observeCliTurnId = Just (TurnId "planner-turn")
          }
      )
  issueIncomplete <-
    parseDaemonObservation
      (baseObserveCli IssueImplement "implementation-incomplete")
  prWorkerIncomplete <-
    parseDaemonObservation
      (baseObserveCli PrReview "worker-incomplete")
  results <-
    sequence
      [ assert
          "observe-once parses issue planning observation"
          (planning == DaemonIssuePlanningObservation (ObservedPlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn")))
      , assert
          "observe-once defaults issue implementation incomplete reason"
          (issueIncomplete == DaemonIssueImplementObservation (ObservedImplementationIncomplete "incomplete"))
      , assert
          "observe-once defaults PR review worker incomplete reason"
          (prWorkerIncomplete == DaemonPrReviewObservation (ObservedWorkerOutcome (WorkerIncomplete "incomplete")))
      ]
  pure (and results)

baseObserveCli :: Domain -> String -> ObserveOnceCli
baseObserveCli domain observation =
  ObserveOnceCli
    { observeCliEventsPath = "/tmp/events.jsonl"
    , observeCliStateDir = "/tmp/state"
    , observeCliRepo = RepoName "owner/name"
    , observeCliWorkdir = "/tmp/work"
    , observeCliDomain = domain
    , observeCliObservation = observation
    , observeCliExecute = False
    , observeCliEndpoint = Nothing
    , observeCliThreadId = Nothing
    , observeCliTurnId = Nothing
    , observeCliImplementationTurnId = Nothing
    , observeCliPrNumber = Nothing
    , observeCliCommitSha = Nothing
    , observeCliMergeCommitSha = Nothing
    , observeCliReason = Nothing
    , observeCliPlanMarkdown = Nothing
    , observeCliReviewThreadIds = []
    , observeCliComment = Nothing
    }

main :: IO ()
main = do
  results <-
    sequence
      [ quickCheckResult prop_someEffectSemanticEquality
      , quickCheckResult prop_observedFromDecisionPreservesTransition
      , quickCheckResult prop_invalidObservationReportsState
      , quickCheckResult prop_blockingNonTerminalRecordsReasonAndStops
      , quickCheckResult prop_stoppedTerminalDoesNotMutate
      , quickCheckResult prop_completeTerminalStopDoesNotMutate
      , quickCheckResult prop_unresolvedReviewsStartWorkerButDoNotMerge
      , quickCheckResult prop_noUnresolvedReviewsStartsReviewerOnly
      , quickCheckResult prop_cleanReviewWaitsForMergeability
      , quickCheckResult prop_issuePlanCompletionWaitsBeforeImplementation
      , quickCheckResult prop_issuePlanReadyStartsPlanTurn
      , quickCheckResult prop_issuePlanCompletionWithoutImmediateTurnWaitsOnly
      , quickCheckResult prop_issueImplementationIncompleteRestartsWorker
      , quickCheckResult prop_issueImplementationBlockedStops
      , quickCheckResult prop_plannerCompletionReturnsToReady
      , quickCheckResult prop_plannerGraphUpdateWaitsAndRecords
      , quickCheckResult prop_plannerIssueCreationReturnsToPlanning
      , quickCheckResult prop_stateSingletonReflection
      , quickCheckResult prop_eventLogFullPrReviewPathCompletes
      , quickCheckResult prop_eventLogMergeabilityFixRequiredQueuesWorker
      , quickCheckResult prop_eventLogCannotReviewCleanWhileFixing
      , quickCheckResult prop_eventLogCannotMergeBeforeCleanReview
      , quickCheckResult prop_eventLogFullIssueImplementationPathCompletes
      , quickCheckResult prop_eventLogPostMergeReviewStartUsesExistingReviewer
      , quickCheckResult prop_eventLogIgnoresMergedPrBeforeHandoff
      , quickCheckResult prop_eventLogRefreshesIdleIssueWorkerThread
      , quickCheckResult prop_eventLogRefreshesIdlePrReviewThreads
      , quickCheckResult prop_eventLogRefreshesPrReviewVerificationThreads
      , quickCheckResult prop_eventLogRefreshesPrReviewReviewerWhileWorkerActive
      , quickCheckResult prop_eventLogCreatePrBeforeIssuePlanStartsPlanReady
      , quickCheckResult prop_eventLogCannotUpdatePrBodyBeforePlan
      , quickCheckResult prop_eventLogCannotCompleteIssueBeforeImplementationTurn
      , quickCheckResult prop_eventLogCannotHandoffBeforeImplementationCompletion
      , quickCheckResult prop_eventLogIssueInitializedStartsPrSetup
      , quickCheckResult prop_eventLogIssueIncompleteCanContinueToComplete
      , quickCheckResult prop_issueImplementWatcherStartsPlanMode
      , quickCheckResult prop_issueImplementWatcherPlanCompletionWaitsBeforeImplementation
      , quickCheckResult prop_issueImplementWatcherIncompleteRestartsImplementation
      , quickCheckResult prop_issueImplementWatcherRejectsCompletionBeforeImplementationTurn
      , quickCheckResult prop_issueImplementWatcherRejectsStaleCompletionPrAfterHandoff
      , quickCheckResult prop_issueImplementWatcherMergedStartsPostMergeReview
      , quickCheckResult prop_issueImplementPostMergeFollowUpUsesNextAttemptBranch
      , quickCheckResult prop_issueImplementPostMergeFollowUpIncrementsAttemptBranch
      , quickCheckResult prop_issueImplementWatcherIssueClosedCompletes
      , quickCheckResult prop_issueImplementWatcherBlockedStops
      , quickCheckResult prop_issueImplementationCompatibilityWritesPrUrl
      , quickCheckResult prop_prReviewCompatibilityClearsCheckerState
      , quickCheckResult prop_eventLogFullIssuePlanningPathReturnsReady
      , quickCheckResult prop_eventLogIssuePlanningIssueCreationReturnsReady
      , quickCheckResult prop_eventLogIssuePlanningGraphWaitsForReadyIssues
      , quickCheckResult prop_eventLogAllowsScopedPlanningDependencyClosure
      , quickCheckResult prop_eventLogIssuePlanningReadyIssuesFixedReentersPlanning
      , quickCheckResult prop_eventLogIssuePlanningRetryReentersPlanning
      , quickCheckResult prop_eventLogCannotCompletePlanningBeforeStart
      , quickCheckResult prop_issuePlanningWatcherStartsAndCompletesTurn
      , quickCheckResult prop_issuePlanningWatcherRetriesTurn
      , quickCheckResult prop_issuePlanningWatcherCreatesIssuesBeforeReplanning
      , quickCheckResult prop_issuePlanningWatcherRecordsGraphBeforeFanoutAndWaits
      , quickCheckResult prop_issuePlanningWatcherBlocksOutOfScopeGraph
      , quickCheckResult prop_issuePlanningWatcherAllowsScopedDependencyClosure
      , quickCheckResult prop_canonicalPlanningGraphUsesDependencyHintsAndOpenChildren
      , quickCheckResult prop_issuePlanningSelectionRespectsMaxParallelAndSkipsActive
      , quickCheckResult prop_issuePlanningFanoutBuildsLaunchPlans
      , quickCheckResult prop_issuePlanningFanoutRetriesTransientCloneFailures
      , quickCheckResult prop_issuePlanningFanoutParsesImplementerConfig
      , quickCheckResult prop_issuePlanningFanoutDetectsCompletionBoundary
      , quickCheckResult (once (ioProperty issuePlanningFanoutRoutesTerminalWritesThroughIndexedProjection))
      , quickCheckResult prop_issuePlanningFanoutUsesOnlyReadyIssues
      , quickCheckResult prop_issuePlanningReadyFanoutDoesNotRecreateExistingImplementers
      , quickCheckResult prop_issuePlanningFanoutTreatsClosedReadyIssuesAsTerminal
      , quickCheckResult (ioProperty prop_issuePlanningFanoutDefaultsToStartingChildWatchers)
      , quickCheckResult (once (ioProperty issueImplementerLaunchLifecycleManifestsAndDryRunCommand))
      , quickCheckResult (once (ioProperty issueImplementerLaunchSourcePreservesWriteOrdering))
      , quickCheckResult prop_issuePlanningFanoutAllowsScopedDependencyClosure
      , quickCheckResult prop_eventLogCanonicalJsonRoundTrips
      , quickCheckResult prop_eventLogCanonicalIssuePlanStartName
      , quickCheckResult prop_eventLogRejectsLegacyIssuePlanAliases
      , quickCheckResult prop_eventLogRejectsEmptyReviewThreads
      , quickCheckResult prop_eventLogRepairIssue26MissingPlanReentersImplementation
      , quickCheckResult prop_eventLogRepairDropsCompletionWithoutImplementationTurn
      , quickCheckResult prop_eventLogRepairDropsStalePlanningReadyIssuesFixed
      , quickCheckResult prop_eventLogRepairRejectsValidEventLog
      , quickCheckResult (once (ioProperty issueImplementEventLogRepairCliPreservesDryRunAndExecuteContract))
      , quickCheckResult prop_protocolPrReviewWorkerCompletedReturnsToChecking
      , quickCheckResult prop_protocolPrReviewWorkerIncompleteReturnsToChecking
      , quickCheckResult prop_protocolPrReviewWorkerBlockedStopsInBlocked
      , quickCheckResult prop_protocolPrReviewWorkerEmitsStartThenTerminalEvent
      , quickCheckResult prop_protocolPrReviewReviewerCleanWaitsForMergeability
      , quickCheckResult prop_protocolPrReviewReviewerBlockedStopsInBlocked
      , quickCheckResult prop_protocolPrReviewReviewerProblemsReturnToChecking
      , quickCheckResult prop_protocolPrReviewReviewerIncompleteReturnsToChecking
      , quickCheckResult prop_protocolPrReviewReviewerEmitsStartThenCleanEvent
      , quickCheckResult prop_protocolPrReviewWorkerThenReviewerThenMergeCompletes
      , quickCheckResult prop_prReviewWatcherUnresolvedStartsWorker
      , quickCheckResult prop_prReviewWatcherUnresolvedSendsThreadSummaryToWorker
      , quickCheckResult prop_prReviewWatcherCleanStartsReviewer
      , quickCheckResult prop_prReviewWatcherWorkerIncompleteReturnsToChecking
      , quickCheckResult prop_prReviewWatcherCleanReviewerWaitsForMergeability
      , quickCheckResult prop_prReviewVerificationCleanResolvesFixedThreadsAndRechecks
      , quickCheckResult prop_prReviewVerificationCleanRechecksSummaryOnlyEvidence
      , quickCheckResult prop_prReviewVerificationCleanRequiresResolvedThreadIds
      , quickCheckResult prop_prReviewRemainingThreadsReplyAndQueueWorker
      , quickCheckResult prop_runtimeCommandSpecsHaveExecutable
      , quickCheckResult prop_runtimeGitPushDryRunNeverForces
      , quickCheckResult prop_runtimeGitPushNeverForces
      , quickCheckResult prop_runtimeGhPrViewUsesStructuredFields
      , quickCheckResult prop_runtimeGhPrChecksUsesCurrentCli
      , quickCheckResult prop_runtimeGhIssueCreateUsesRepoTitleAndBody
      , quickCheckResult prop_runtimeGhIssueCreateWithParentLinksSubIssue
      , quickCheckResult prop_runtimeGhIssueCloseCommentsAndCloses
      , quickCheckResult prop_runtimeGhPrCreateKeepsStdoutJsonOnly
      , quickCheckResult prop_runtimeGhPrBodyUpdateUsesPlanFile
      , quickCheckResult prop_runtimeGhReplyReviewThreadUsesGraphqlMutation
      , quickCheckResult prop_runtimeGhPrCommentReviewFindingsUsesPrComment
      , quickCheckResult prop_runtimeGhPrCleanReviewAndMergeCommentsBeforeMerge
      , quickCheckResult prop_runtimeGhReviewThreadCommandsUseGraphql
      , quickCheckResult prop_runtimeGhPrMergeUsesAdapterFlags
      , quickCheckResult prop_runtimeKillZeroOnlyChecksPid
      , quickCheckResult prop_ghGitParsesIssueAndPrLists
      , quickCheckResult prop_ghGitParsesRemoteIssueView
      , quickCheckResult prop_ghGitParsesRemotePrView
      , quickCheckResult prop_ghGitParsesRemotePrMetadataVariants
      , quickCheckResult prop_ghGitParsesPrCreateAndChecks
      , quickCheckResult prop_ghGitParsesReviewThreadsGraphql
      , quickCheckResult prop_ghGitParsesGitOutputs
      , quickCheckResult prop_appServerInitializeRequestMatchesJsonRpc
      , quickCheckResult prop_appServerInitializedNotificationMatchesJsonRpc
      , quickCheckResult prop_appServerThreadStartKeepsNodeNullFields
      , quickCheckResult prop_appServerTurnStartPlanModeEncodesCollaborationMode
      , quickCheckResult prop_appServerTurnStartOmitsAbsentOutputSchema
      , quickCheckResult prop_runtimeDefaultsCentralizeThreadAndTurnOptions
      , quickCheckResult prop_jsonPathHelpersDecodeNestedValues
      , quickCheckResult prop_appServerThreadReadAndInterruptUseThreadIds
      , quickCheckResult prop_appServerClientInitializesSingleRequestSessions
      , quickCheckResult prop_appServerClientDetectsSystemErrorThreadStatus
      , quickCheckResult prop_appServerClientMatchesSuccessResponse
      , quickCheckResult prop_appServerClientSkipsNotifications
      , quickCheckResult prop_appServerClientRejectsMismatchedResponseIds
      , quickCheckResult prop_appServerClientSurfacesJsonRpcErrors
      , quickCheckResult prop_appServerClientMaterializationFallbackRetriesWithoutTurns
      , quickCheckResult prop_appServerClientMaterializationFallbackMarksSyntheticResponse
      , quickCheckResult prop_appServerClientRejectsUnsupportedJsonRpcVersion
      , quickCheckResult prop_appServerClientParsesThreadReadTurns
      , quickCheckResult prop_appServerClientParsesTurnStartTurnId
      , quickCheckResult prop_appServerClientRejectsMalformedTurnStartTurnId
      , quickCheckResult prop_appServerClientParsesThreadStartThreadId
      , quickCheckResult prop_appServerClientRejectsMalformedThreadStartThreadId
      , quickCheckResult prop_appServerClientStartsThreadWithInterpreter
      , quickCheckResult prop_appServerClientParsesNestedThreadReadTurns
      , quickCheckResult prop_turnClassifierCompletionStates
      , quickCheckResult prop_turnClassifierMapsDomainOutputs
      , quickCheckResult prop_turnClassifierPrefersStructuredOutputs
      , quickCheckResult prop_turnClassifierBlocksMissingOutputs
      , quickCheckResult prop_effectInterpreterIssuePlanCompletionRecordsPlan
      , quickCheckResult prop_effectInterpreterPrBodyUpdateUsesIssuePlan
      , quickCheckResult prop_effectInterpreterIssueTurnsUsePhaseSpecificPrompts
      , quickCheckResult prop_defaultEffectRuntimeConfigUsesStructuredOutputSchemas
      , quickCheckResult prop_turnOutputSchemasRequireStructuredDetails
      , quickCheckResult prop_threadDeveloperPromptTemplatesPortNodeProtocols
      , quickCheckResult prop_structuredTurnOutcomeInstructionsFollowAgentPrinciple
      , quickCheckResult prop_promptPipelineAlignmentContracts
      , quickCheckResult prop_effectInterpreterIssuePlanTurnUsesIssuePlanModeDeveloperInstructions
      , quickCheckResult prop_effectInterpreterTwoTurnStartsUseMonotonicRequestIds
      , quickCheckResult prop_effectInterpreterRecordBlockedWritesBlockState
      , quickCheckResult prop_effectInterpreterRecordPlanningGraphWritesState
      , quickCheckResult prop_effectInterpreterCreateIssueUsesConfiguredEffect
      , quickCheckResult prop_effectInterpreterMergeUsesConfiguredRepoAndMethod
      , quickCheckResult prop_actionExecutorDryRunPreservesActionOrder
      , quickCheckResult prop_runtimeOwnerJsonAndParsing
      , quickCheckResult prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork
      , quickCheckResult prop_healthcheckDaemonRequiredStatuses
      , quickCheckResult prop_healthcheckIssueImplementLifecycleReporting
      , quickCheckResult prop_healthcheckSingletonDomains
      , quickCheckResult prop_healthcheckSummaryJsonKeepsKindField
      , quickCheckResult prop_healthcheckTypedAnalyzerDispatch
      , quickCheckResult prop_cliParsesHealthcheckAndRunLoop
      , quickCheckResult prop_cliParsesAppServerProbe
      , quickCheckResult prop_cliRejectsBadDomain
      , quickCheckResult prop_cliParsesGenericRunnerGuardDomains
      , quickCheckResult prop_supervisorRendersRestartAndLogrotate
      ]
  goldenOk <- goldenReplayCases
  eventLogOk <- goldenEventLogCases
  bootstrapOk <- goldenBootstrapCases
  runtimeProcessOk <- runtimeProcessSpecCapturesStreamsAndExit
  actionExecutorDryRunOk <- actionExecutorDryRunDoesNotCallInterpreters
  actionExecutorExecuteOk <- actionExecutorExecuteCallsInjectedInterpreters
  watcherLogRenderingOk <- watcherLogRenderingIncludesTimestampSeverityAndRedacts
  actionExecutorLogDryRunOk <- actionExecutorLogsDryRunWhenLoggerInjected
  actionExecutorLogFailureOk <- actionExecutorLogsCommandFailure
  daemonTickOk <- daemonTickDryRunReplaysEventsAndDoesNotExecute
  daemonTickCommandFailureOk <- daemonTickExecuteStopsOnCommandFailure
  observedDaemonDryRunOk <- observedDaemonTickDryRunDoesNotMutate
  observedDaemonExecuteOk <- observedDaemonTickExecuteAppendsWritesAndRunsEffects
  observedDaemonAuditOk <- observedDaemonTickAuditSeparatesPreAndPostReports
  observedDaemonFailureOk <- observedDaemonTickExecuteCommandFailureDoesNotAppendEvent
  workflowTransactionParityOk <- workflowTransactionDryRunExecuteParityUsesCommitBoundary
  preMergeHeadChangedOk <- observedDaemonTickPreMergeGateRechecksWhenHeadChanged
  preMergeCleanOk <- observedDaemonTickPreMergeGateMergesWhenClean
  preMergeUnstableOk <- observedDaemonTickPreMergeGateWaitsWhenUnstable
  preMergeUnstableChecksFailOk <- observedDaemonTickPreMergeGateQueuesWorkerWhenUnstableChecksFail
  preMergeDirtyOk <- observedDaemonTickPreMergeGateQueuesWorkerWhenDirty
  preMergeConflictingOk <- observedDaemonTickPreMergeGateQueuesWorkerWhenConflicting
  preMergeTransientOk <- observedDaemonTickPreMergeGateRetriesTransientGithubReads
  changesRequestedWorkerOk <- observedDaemonTickChangesRequestedStartsWorker
  checkingChecksFailOk <- observedDaemonTickCheckingQueuesWorkerWhenChecksFail
  checkingMergeStateFixOk <- observedDaemonTickCheckingQueuesMergeStateFixBeforeReviewThreads
  verificationMergeStateFixOk <- observedDaemonTickVerificationQueuesMergeStateFixBeforeReviewer
  automaticPlanningDryRunOk <- automaticDaemonLoopPlanningDryRunStartsSyntheticTurn
  automaticPlanningSnapshotOk <- automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart
  automaticPlanningFreshThreadOk <- automaticDaemonLoopPlanningExecuteStartsFreshPlannerThread
  automaticPlanningClosedScopeOk <- automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn
  automaticPlanningIssueCreationOk <- automaticDaemonLoopPlanningIssueCreationRequestsReplanning
  automaticPlanningGraphOk <- automaticDaemonLoopPlanningGraphWaitsAndRecords
  automaticPlanningClosedDepsOk <- automaticDaemonLoopPlanningGraphDropsClosedDependencies
  automaticPlanningCanonicalCoverageOk <- automaticDaemonLoopPlanningGraphCanonicalizesOpenScopeCoverage
  automaticExecutePrestartOk <- automaticDaemonLoopExecutePrestartsTurnOnce
  automaticActiveTurnOk <- automaticDaemonLoopActiveTurnCompletionObservesOutput
  automaticActiveTurnSystemErrorOk <- automaticDaemonLoopActiveTurnSystemErrorBlocksWatcher
  automaticPlanningSystemErrorRetryOk <- automaticPlanningSystemErrorRetriesWatcher
  automaticPlanningSystemErrorLimitOk <- automaticPlanningSystemErrorBlocksAfterRetryLimit
  automaticPlanWriteBeforeEventOk <- automaticDaemonLoopWritesPlanBeforePlanCompletedEvent
  automaticMissingPlanPreValidationOk <- automaticDaemonLoopEmptyPlanMarkdownBlocksBeforePlanCompleted
  automaticImplementationHandoffOk <- automaticDaemonLoopImplementationCompletionSequencesHandoff
  automaticIssueMergeClosedOk <- automaticIssueMergeWaitsForIssueClose
  automaticIssueFinalReviewReworkOk <- automaticIssueFinalReviewFindingsRequestRework
  automaticIssueFollowUpRefreshOk <- automaticIssueFollowUpRefreshesWorkerBeforePlanTurn
  automaticStaleTurnOk <- automaticStalePlanningTurnRetriesAfterThreeMisses
  automaticPrRetryOk <- automaticDaemonLoopRetriesPrCreateWhileWaitingForPr
  automaticMergedBranchAdvanceOk <- automaticDaemonLoopAdvancesMergedAttemptBranchBeforePrCreate
  automaticUnlinkedPrOk <- automaticDaemonLoopBlocksUnlinkedBranchPr
  automaticNewPrBodyOk <- automaticDaemonLoopUpdatesNewPrBodyBeforeImplementation
  automaticReusedPrBodyOk <- automaticDaemonLoopUpdatesReusedPrBodyBeforeImplementation
  automaticBodyThenImplementationOk <- automaticDaemonLoopStartsImplementationAfterPrBodyUpdate
  automaticImplementationIncompleteOk <- automaticDaemonLoopIncompleteImplementationRestartsWorker
  automaticImplementationMissingOutputOk <- automaticDaemonLoopMissingImplementationOutputBlocks
  automaticImplementationNoPrOk <- automaticDaemonLoopCompleteImplementationWithoutKnownPrStaysIncomplete
  automaticMissingPlanBodyOk <- automaticDaemonLoopMissingPlanFailsPrBodyUpdate
  automaticTerminalStopOk <- automaticDaemonLoopTerminalStateStops
  automaticLoopLoggingOk <- automaticDaemonLoopEmitsBoundaryLogs
  automaticLoopRetryPolicyOk <- automaticLoopRetryPolicyKeepsTransientFailuresAlive
  phaseActionValidationOk <- phaseActionValidationRejectsInvalidCombinations
  phaseActionDecisionValidationOk <- phaseActionValidationAcceptsStateMachineDecisions
  workflowFacadeOk <- workflowFacadeExtractionTests
  issuePlanningFanoutActiveOk <- issuePlanningFanoutDiscoversOnlyRunningImplementers
  runnerGuardOk <- runnerGuardIgnoresMissingPidForCompletePlanning
  runnerGuardRestartOk <- runnerGuardRestartsMissingPidForIncompletePlanning
  runnerGuardWaitingRestartOk <- runnerGuardRestartsMissingPidForWaitingPlanning
  runnerGuardRepairOk <- runnerGuardRepairsInvalidPlanningEventLog
  runtimeStatusOk <- runtimeStatusHelperCoversCommonCases
  runtimeStatusIssueImplementOk <- runtimeStatusIssueImplementTerminalRequiresIssueCloseVerifier
  runtimeOwnerLeaseOk <- runtimeOwnerLeaseParsingRejectsOwnerOnlyJson
  runtimeOwnerClaimOk <- runtimeOwnerClearRejectsRunningLease
  runtimeOwnerCleanupOk <- runtimeOwnerCleanupClearsOnlyCurrentProcessLease
  pidRestoreOk <- restoreOwnedPidFileRepairsMissingAndStalePid
  observeParsingOk <- observeOnceParsingCoversDomainsAndDefaults
  if
    all isSuccess results
      && goldenOk
      && eventLogOk
      && bootstrapOk
      && runtimeProcessOk
      && actionExecutorDryRunOk
      && actionExecutorExecuteOk
      && watcherLogRenderingOk
      && actionExecutorLogDryRunOk
      && actionExecutorLogFailureOk
      && daemonTickOk
      && daemonTickCommandFailureOk
      && observedDaemonDryRunOk
      && observedDaemonExecuteOk
      && observedDaemonAuditOk
      && observedDaemonFailureOk
      && workflowTransactionParityOk
      && preMergeHeadChangedOk
      && preMergeCleanOk
      && preMergeUnstableOk
      && preMergeUnstableChecksFailOk
      && preMergeDirtyOk
      && preMergeConflictingOk
      && preMergeTransientOk
      && changesRequestedWorkerOk
      && checkingChecksFailOk
      && checkingMergeStateFixOk
      && verificationMergeStateFixOk
      && automaticPlanningDryRunOk
      && automaticPlanningSnapshotOk
      && automaticPlanningFreshThreadOk
      && automaticPlanningClosedScopeOk
      && automaticPlanningIssueCreationOk
      && automaticPlanningGraphOk
      && automaticPlanningClosedDepsOk
      && automaticPlanningCanonicalCoverageOk
      && automaticExecutePrestartOk
      && automaticActiveTurnOk
      && automaticActiveTurnSystemErrorOk
      && automaticPlanningSystemErrorRetryOk
      && automaticPlanningSystemErrorLimitOk
      && automaticPlanWriteBeforeEventOk
      && automaticMissingPlanPreValidationOk
      && automaticImplementationHandoffOk
      && automaticIssueMergeClosedOk
      && automaticIssueFinalReviewReworkOk
      && automaticIssueFollowUpRefreshOk
      && automaticStaleTurnOk
      && automaticPrRetryOk
      && automaticMergedBranchAdvanceOk
      && automaticUnlinkedPrOk
      && automaticNewPrBodyOk
      && automaticReusedPrBodyOk
      && automaticBodyThenImplementationOk
      && automaticImplementationIncompleteOk
      && automaticImplementationMissingOutputOk
      && automaticImplementationNoPrOk
      && automaticMissingPlanBodyOk
      && automaticTerminalStopOk
      && automaticLoopLoggingOk
      && automaticLoopRetryPolicyOk
      && phaseActionValidationOk
      && phaseActionDecisionValidationOk
      && workflowFacadeOk
      && issuePlanningFanoutActiveOk
      && runnerGuardOk
      && runnerGuardRestartOk
      && runnerGuardWaitingRestartOk
      && runnerGuardRepairOk
      && runtimeStatusOk
      && runtimeStatusIssueImplementOk
      && runtimeOwnerLeaseOk
      && runtimeOwnerClaimOk
      && runtimeOwnerCleanupOk
      && pidRestoreOk
      && observeParsingOk
    then pure ()
    else exitFailure
