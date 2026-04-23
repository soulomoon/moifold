{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Main (main) where

import CodexWatcher.AppServerProtocol
import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.Cli
import CodexWatcher.CompatibilityState
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop
import CodexWatcher.EffectInterpreter
import CodexWatcher.EffectRuntimeCli
import CodexWatcher.Effects
import CodexWatcher.EventLog
import CodexWatcher.EventLogRepair
import CodexWatcher.GhGit (ReviewThread (..), ReviewThreadsReport (..))
import CodexWatcher.GoldenReplay
import CodexWatcher.IssueFanoutCli (readyIssueStatusFromRuntime)
import CodexWatcher.IssueImplementWatcher
import CodexWatcher.IssuePlanningFanout
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Observation
import CodexWatcher.ObserveCli (parseDaemonObservation)
import CodexWatcher.PlanningGraphCanonical
import CodexWatcher.Protocol
import CodexWatcher.PrReviewWatcher
import CodexWatcher.Runtime
import CodexWatcher.RuntimeDefaults
import CodexWatcher.RuntimeOwner
import CodexWatcher.RuntimeOwnerCli (clearRuntimeLease)
import CodexWatcher.RunnerGuard
import CodexWatcher.Snapshot
import CodexWatcher.StateMachine
import CodexWatcher.Supervisor
import CodexWatcher.TurnClassifier
import CodexWatcher.TurnOutput
import CodexWatcher.Types
import CodexWatcher.WatcherRuntimeStatus
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
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), addUTCTime, getCurrentTime, secondsToDiffTime)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, removePathForcibly)
import System.FilePath ((</>))
import System.Exit (ExitCode (..), exitFailure)
import System.Posix.Process (getProcessID)
import Test.QuickCheck
import AppServerSpec
  ( prop_appServerClientInitializesSingleRequestSessions
  , prop_appServerClientDetectsSystemErrorThreadStatus
  , prop_appServerClientMatchesSuccessResponse
  , prop_appServerClientParsesNestedThreadReadTurns
  , prop_appServerClientParsesThreadReadTurns
  , prop_appServerClientParsesThreadStartThreadId
  , prop_appServerClientStartsThreadWithInterpreter
  , prop_appServerClientParsesTurnStartTurnId
  , prop_appServerClientRejectsMismatchedResponseIds
  , prop_appServerClientRejectsUnsupportedJsonRpcVersion
  , prop_appServerClientSkipsNotifications
  , prop_appServerClientSurfacesJsonRpcErrors
  , prop_appServerInitializeRequestMatchesJsonRpc
  , prop_appServerInitializedNotificationMatchesJsonRpc
  , prop_appServerThreadReadAndInterruptUseThreadIds
  , prop_appServerThreadStartKeepsNodeNullFields
  , prop_appServerTurnStartPlanModeEncodesCollaborationMode
  )
import CliSpec
  ( prop_cliParsesGenericRunnerGuardDomains
  , prop_cliParsesHealthcheckAndRunLoop
  , prop_cliRejectsBadDomain
  )
import HealthcheckSpec
  ( prop_healthcheckDaemonRequiredStatuses
  , prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork
  )
import GhGitSpec
  ( prop_ghGitParsesGitOutputs
  , prop_ghGitParsesIssueAndPrLists
  , prop_ghGitParsesPrCreateAndChecks
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
  , prop_runtimeGhPrCommentReviewAndMergeCommentsBeforeMerge
  , prop_runtimeGhPrChecksUsesRequiredCurrentCli
  , prop_runtimeGhPrViewUsesStructuredFields
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
  arbitrary = PlannerConfig <$> arbitrary <*> (getPositive <$> arbitrary) <*> arbitrary

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
  | PushBranchTag
  | CreateIssueTag
  | CreatePullRequestTag
  | UpdatePullRequestBodyTag
  | CloseIssueTag
  | ResolveReviewThreadTag
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
  SomeEffect PushBranch {} -> PushBranchTag
  SomeEffect CreateIssue {} -> CreateIssueTag
  SomeEffect CreatePullRequest {} -> CreatePullRequestTag
  SomeEffect UpdatePullRequestBody {} -> UpdatePullRequestBodyTag
  SomeEffect CloseIssue {} -> CloseIssueTag
  SomeEffect ResolveReviewThread {} -> ResolveReviewThreadTag
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
   in SomeEffect (StartWorkerTurn threadId) == SomeEffect (StartWorkerTurn threadId)
        && SomeEffect (StartWorkerTurn threadId) /= SomeEffect (StartWorkerTurn otherThread)
        && SomeEffect (RecordBlocked reason) == SomeEffect (RecordBlocked reason)
        && SomeEffect StopDaemon /= SomeEffect SleepUntilNextPoll
        && SomeEffect (StartWorkerTurn threadId) /= SomeEffect (StartIssueImplementationWorkerTurn threadId)

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
  case step (PrReviewingClean config commit (WorkerIdle workerThread) (ReviewerActive reviewerActive)) (ReviewerFoundClean cleanEvidence) of
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
  case step (PlanningTurnActive config activeTurn) (PlannerRequestedIssueCreation [request]) of
    Decision state effects ->
      phaseOf state == Initialized
        && effects == [SomeEffect (CreateIssue (plannerRepo config) request), SomeEffect SleepUntilNextPoll]

prop_terminalStateHasNoImplicitEffects :: MergeCommit -> BlockedReason -> StopReason -> Bool
prop_terminalStateHasNoImplicitEffects mergeCommit blockedReason stopReason =
  all
    (not . hasMutation)
    [ effectsForTerminalState (CompleteState (PrMerged mergeCommit))
    , effectsForTerminalState (BlockedState blockedReason :: WatcherState 'PrReview 'Blocked)
    , effectsForTerminalState (StoppedState stopReason :: WatcherState 'PrReview 'Stopped)
    ]

prop_eventLogFullPrReviewPathCompletes :: PrConfig -> ThreadId -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> TurnId -> CleanReviewEvidence -> MergeCommit -> Bool
prop_eventLogFullPrReviewPathCompletes config workerThread reviewerThread reviewThreadIds reviewedCommit workerTurn reviewerTurn cleanEvidence mergeCommit =
  replaySatisfies
    [ PrReviewInitialized config workerThread reviewerThread
    , PrReviewUnresolvedFound reviewThreadIds reviewedCommit workerTurn
    , PrReviewFixCompleted
    , PrReviewNoUnresolvedFound (cleanReviewCommit cleanEvidence) reviewerTurn
    , PrReviewCleanFound cleanEvidence
    , PrReviewMergeabilityClean (cleanReviewCommit cleanEvidence)
    , PrReviewMergeCompleted mergeCommit
    ]
    \replay ->
      someDomain replay.replayState == PrReview
        && somePhase replay.replayState == Complete

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
  replaySatisfies
    [ IssueImplementInitialized config workerThread
    , IssuePullRequestCreatedEvent prNumber
    , IssuePlanTurnStartedEvent planTurn
    , IssuePlanCompletedEvent sampleIssuePlanMarkdown (Just implementationTurn)
    , IssuePullRequestBodyUpdatedEvent prNumber
    , IssueImplementationTurnStartedEvent implementationTurn
    , IssueImplementationCompletedEvent prNumber
    , IssueReviewHandoffInitializedEvent prNumber
    , IssueReviewHandoffStartedEvent prNumber
    , IssuePullRequestMergedEvent prNumber
    , IssueClosedEvent prNumber
    ]
    \replay ->
      someDomain replay.replayState == IssueImplement
        && somePhase replay.replayState == Complete

prop_eventLogCannotCompleteIssueBeforePlanning :: IssueConfig -> ThreadId -> PrNumber -> Bool
prop_eventLogCannotCompleteIssueBeforePlanning config workerThread prNumber =
  expectLeft
    ( replayEventLog
        [ IssueImplementInitialized config workerThread
        , IssuePullRequestMergedEvent prNumber
        ]
    )

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
        SomeWatcherState (PrReviewingClean _ _ _ (ReviewerActive activeTurn)) ->
          activeTurn.activeThreadId == newReviewer
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
   in case replayEventLog
        [ IssueImplementInitialized config workerThread
        , IssuePullRequestCreatedEvent prNumber
        , IssuePlanTurnStartedEvent planTurn
        , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
        , IssuePullRequestBodyUpdatedEvent prNumber
        , IssueImplementationTurnStartedEvent firstImplementationTurn
        , IssueImplementationIncompleteEvent "incomplete"
        , IssueImplementationTurnStartedEvent secondImplementationTurn
        , IssueImplementationCompletedEvent prNumber
        , IssueReviewHandoffInitializedEvent prNumber
        , IssueReviewHandoffStartedEvent prNumber
        , IssuePullRequestMergedEvent prNumber
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
   in expectLeft (issueImplementObserve state (ObservedImplementationCompleted prNumber))

prop_issueImplementWatcherRejectsStaleCompletionPrAfterHandoff :: Bool
prop_issueImplementWatcherRejectsStaleCompletionPrAfterHandoff =
  all rejectsStaleCompletion
    [ SomeWatcherState (IssueHandoffReady config expectedPr)
    , SomeWatcherState (IssueHandoffInitialized config expectedPr)
    , SomeWatcherState (IssueWaitingForPrMerge config expectedPr)
    ]
 where
  config = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
  expectedPr = PrNumber 7
  stalePr = PrNumber 8
  rejectsStaleCompletion state =
    expectRight (issueImplementObserve state (ObservedImplementationCompleted stalePr)) \tick ->
      issueImplementTickEvent tick == IssueImplementationCompletedEvent stalePr
        && somePhase tick.issueImplementTickState == Blocked
        && hasEffect RecordBlockedTag tick.issueImplementTickEffects
        && SomeEffect StopDaemon `elem` tick.issueImplementTickEffects

prop_issueImplementWatcherMergedWaitsForIssueClose :: IssueConfig -> PrNumber -> Bool
prop_issueImplementWatcherMergedWaitsForIssueClose config prNumber =
  let state = SomeWatcherState (IssueWaitingForPrMerge config prNumber)
   in expectRight (issueImplementObserve state (ObservedPullRequestMerged prNumber)) \tick ->
        issueImplementTickEvent tick == IssuePullRequestMergedEvent prNumber
          && somePhase tick.issueImplementTickState == Implementing
          && hasEffect CloseIssueTag tick.issueImplementTickEffects
          && lacksEffect StopDaemonTag tick.issueImplementTickEffects

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
        , SomeWatcherState (IssueWaitingForPrMerge config prNumber)
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
        , SomeWatcherState (PrReviewingClean config commit (WorkerIdle workerThread) (ReviewerActive (ActiveTurn reviewerThread (TurnId "reviewer-turn"))))
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
    , IssuePlanningIssuesRequested [request]
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

prop_issuePlanningWatcherCreatesIssuesBeforeReplanning :: PlannerConfig -> ThreadId -> TurnId -> IssueCreationRequest -> Bool
prop_issuePlanningWatcherCreatesIssuesBeforeReplanning config threadId turnId request =
  let ready = SomeWatcherState (PlanningReady config)
   in case issuePlanningObserve ready (ObservedPlanningTurnStarted threadId turnId) of
        Right started ->
          case issuePlanningObserve started.issuePlanningTickState (ObservedPlanningIssuesRequested [request]) of
            Right requested ->
              issuePlanningTickEvent requested == IssuePlanningIssuesRequested [request]
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
  let config = PlannerConfig (RepoName "owner/name") 8 [IssueNumber 12]
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

prop_canonicalPlanningGraphUsesDependencyHintsAndOpenChildren :: Bool
prop_canonicalPlanningGraphUsesDependencyHintsAndOpenChildren =
  canonicalPlanningGraph plannerConfig facts plannerOutput == expected
 where
  plannerConfig = PlannerConfig (RepoName "owner/name") 8 [IssueNumber 12, IssueNumber 26, IssueNumber 27]
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
  let config = PlannerConfig (RepoName "owner/name") 3 []
      active = [IssueNumber 2]
      open = [IssueNumber 1, IssueNumber 2, IssueNumber 3, IssueNumber 4]
   in selectIssueImplementationStarts config active open == [IssueNumber 1, IssueNumber 3]

prop_issuePlanningFanoutBuildsLaunchPlans :: Bool
prop_issuePlanningFanoutBuildsLaunchPlans =
  let plannerConfig = PlannerConfig (RepoName "owner/name") 3 []
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
  let config = PlannerConfig (RepoName "owner/name") 3 []
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
        && not (issuePlanningCompletionEvent IssuePlanningTurnCompleted)
        && not (issuePlanningCompletionEvent (IssuePlanningIssuesRequested [IssueCreationRequest "subissue" "details" Nothing]))
        && not (issuePlanningCompletionEvent (IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn")))

prop_issuePlanningFanoutUsesOnlyReadyIssues :: Bool
prop_issuePlanningFanoutUsesOnlyReadyIssues =
  let plannerConfig = PlannerConfig (RepoName "owner/name") 8 []
      fanoutConfig = defaultIssuePlanningFanoutConfig "/tmp/implementers"
      ready = [IssueNumber 10, IssueNumber 12]
      active = [IssueNumber 12]
      launchIssues = fmap (issueNumberOfConfig . launchIssueConfig) (planIssueImplementerLaunches fanoutConfig plannerConfig active ready)
   in launchIssues == [IssueNumber 10]
 where
  issueNumberOfConfig (IssueConfig _ issue _) = issue

prop_issuePlanningReadyFanoutDoesNotRecreateExistingImplementers :: Bool
prop_issuePlanningReadyFanoutDoesNotRecreateExistingImplementers =
  let plannerConfig = PlannerConfig (RepoName "owner/name") 2 []
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

canonicalEventExamples :: [WatcherEvent]
canonicalEventExamples =
  [ IssuePlanningInitialized plannerConfig
  , IssuePlanningTurnStarted plannerThread plannerTurn
  , IssuePlanningIssuesRequested [IssueCreationRequest "Subissue title" "Subissue body" Nothing]
  , IssuePlanningGraphUpdated planningGraph
  , IssuePlanningReadyIssuesFixed
  , IssuePlanningTurnCompleted
  , PrReviewInitialized prConfig workerThread reviewerThread
  , PrReviewUnresolvedFound (ReviewThreadId "review-thread-1" :| [ReviewThreadId "review-thread-2"]) commit workerTurn
  , PrReviewNoUnresolvedFound commit reviewerTurn
  , PrReviewFixCompleted
  , PrReviewFixIncomplete "worker marked incomplete"
  , PrReviewCleanFound cleanEvidence
  , PrReviewMergeabilityWaiting "mergeability still unstable"
  , PrReviewMergeabilityRecheck "reviewed head changed"
  , PrReviewMergeabilityClean commit
  , PrReviewProblemsAdded commit
  , PrReviewReviewIncomplete "reviewer state missing required fields"
  , PrReviewMergeCompleted mergeCommit
  , IssueImplementInitialized issueConfig workerThread
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
  , IssueImplementationCompletedEvent prNumber
  , IssuePullRequestMergedEvent prNumber
  , IssueClosedEvent prNumber
  , WatcherRecoveredInvalidState "synthetic recovery marker"
  , WatcherBlocked blockedReason
  , WatcherStopped stopReason
  ]
 where
  repo = RepoName "owner/name"
  plannerConfig = PlannerConfig repo 8 []
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
        , IssueImplementationCompletedEvent prNumber'
        ]
   in case repairIssueImplementEventLog invalidEvents of
        Left _ -> False
        Right plan ->
          any isRecovery plan.repairInsertedEvents
            && IssueImplementationCompletedEvent prNumber' `elem` plan.repairDroppedEvents
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
        , IssueImplementationCompletedEvent prNumber'
        ]
   in expectLeft (replayEventLog legacyEvents)
        && case repairIssueImplementEventLog legacyEvents of
          Left _ -> False
          Right plan ->
            IssueImplementationCompletedEvent prNumber' `elem` plan.repairDroppedEvents
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
  let config = PlannerConfig (RepoName "owner/name") 8 [IssueNumber 12]
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
  case repairIssueImplementEventLog
    [ IssueImplementInitialized config workerThread
    , IssuePullRequestCreatedEvent prNumber'
    , IssuePlanTurnStartedEvent planTurn
    , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
    , IssuePullRequestBodyUpdatedEvent prNumber'
    , IssueImplementationTurnStartedEvent implementationTurn
    , IssueImplementationCompletedEvent prNumber'
    , IssueReviewHandoffInitializedEvent prNumber'
    , IssueReviewHandoffStartedEvent prNumber'
    , IssuePullRequestMergedEvent prNumber'
    , IssueClosedEvent prNumber'
    ] of
    Left _ -> True
    Right _ -> False

prop_protocolPrReviewWorkerCompletedReturnsToChecking :: PrConfig -> ThreadId -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> Bool
prop_protocolPrReviewWorkerCompletedReturnsToChecking config workerThread reviewerThread reviewThreadIds reviewedCommit workerTurn =
  let session = newPrReviewWorkerSession config workerThread reviewThreadIds reviewedCommit
      (_finished, events) = runPrReviewWorkerProtocol workerTurn WorkerCompleted session
   in case replayEventLog (PrReviewInitialized config workerThread reviewerThread : events) of
        Right replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == CheckingReviews
        Left _ -> False

prop_protocolPrReviewWorkerIncompleteReturnsToChecking :: PrConfig -> ThreadId -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> BlockedReason -> Bool
prop_protocolPrReviewWorkerIncompleteReturnsToChecking config workerThread reviewerThread reviewThreadIds reviewedCommit workerTurn reason =
  let session = newPrReviewWorkerSession config workerThread reviewThreadIds reviewedCommit
      (_finished, events) = runPrReviewWorkerProtocol workerTurn (WorkerIncomplete (unBlockedReason reason)) session
   in case replayEventLog (PrReviewInitialized config workerThread reviewerThread : events) of
        Right replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == CheckingReviews
        Left _ -> False

prop_protocolPrReviewWorkerBlockedStopsInBlocked :: PrConfig -> ThreadId -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> BlockedReason -> Bool
prop_protocolPrReviewWorkerBlockedStopsInBlocked config workerThread reviewerThread reviewThreadIds reviewedCommit workerTurn reason =
  let session = newPrReviewWorkerSession config workerThread reviewThreadIds reviewedCommit
      (_finished, events) = runPrReviewWorkerProtocol workerTurn (WorkerBlocked reason) session
   in case replayEventLog (PrReviewInitialized config workerThread reviewerThread : events) of
        Right replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == Blocked
        Left _ -> False

prop_protocolPrReviewWorkerEmitsStartThenTerminalEvent :: PrConfig -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> Bool
prop_protocolPrReviewWorkerEmitsStartThenTerminalEvent config workerThread reviewThreadIds reviewedCommit workerTurn =
  let session = newPrReviewWorkerSession config workerThread reviewThreadIds reviewedCommit
      (_finished, events) = runPrReviewWorkerProtocol workerTurn WorkerCompleted session
   in case events of
        [PrReviewUnresolvedFound emittedThreads emittedCommit emittedTurn, PrReviewFixCompleted] ->
          emittedThreads == reviewThreadIds
            && emittedCommit == reviewedCommit
            && emittedTurn == workerTurn
        _ -> False

prop_protocolPrReviewReviewerCleanWaitsForMergeability :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> CleanReviewEvidence -> Bool
prop_protocolPrReviewReviewerCleanWaitsForMergeability config workerThread reviewerThread reviewTarget reviewerTurn cleanEvidence =
  let session = newPrReviewReviewerSession config reviewerThread reviewTarget
      (_finished, events) = runPrReviewReviewerProtocol reviewerTurn (ReviewerClean cleanEvidence) session
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
      (_finished, events) = runPrReviewReviewerProtocol reviewerTurn (ReviewerProblemsAdded reviewTarget) session
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
      (_finished, events) = runPrReviewReviewerProtocol reviewerTurn (ReviewerClean cleanEvidence) session
   in case events of
        [PrReviewNoUnresolvedFound emittedCommit emittedTurn, PrReviewCleanFound emittedEvidence] ->
          emittedCommit == reviewTarget
            && emittedTurn == reviewerTurn
            && emittedEvidence == cleanEvidence
        _ -> False

prop_protocolPrReviewWorkerThenReviewerThenMergeCompletes :: PrConfig -> ThreadId -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> TurnId -> MergeCommit -> Bool
prop_protocolPrReviewWorkerThenReviewerThenMergeCompletes config workerThread reviewerThread reviewThreadIds commit workerTurn reviewerTurn mergeCommit =
  let workerSession = newPrReviewWorkerSession config workerThread reviewThreadIds commit
      (_workerFinished, workerEvents) = runPrReviewWorkerProtocol workerTurn WorkerCompleted workerSession
      cleanEvidence = CleanReviewEvidence commit "LGTM"
      reviewerSession = newPrReviewReviewerSession config reviewerThread commit
      (_reviewerFinished, reviewerEvents) = runPrReviewReviewerProtocol reviewerTurn (ReviewerClean cleanEvidence) reviewerSession
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
      (\threadId -> ReviewThread threadId False False (Just "src/File.hs") (Just 12) Nothing [])
      unresolved
  resolvedThread =
    ReviewThread (ReviewThreadId "resolved-thread") True False Nothing Nothing Nothing []

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
              (ReviewEvidence (reviewThreadId :| []) commit)
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
              (WorkerIdle workerThread)
              (ReviewerActive (ActiveTurn reviewerThread turnId))
          )
   in case prReviewObserve state (ObservedReviewerOutcome (ReviewerClean evidence)) of
        Right tick ->
          prReviewTickEvent tick == PrReviewCleanFound evidence
            && somePhase tick.prReviewTickState == WaitingMergeability
            && hasEffect SleepUntilNextPollTag tick.prReviewTickEffects
            && lacksEffect MergePullRequestTag tick.prReviewTickEffects
        Left _ -> False

jsonText :: Value -> Text
jsonText =
  Text.Encoding.decodeUtf8 . LazyByteString.toStrict . encode

reviewerStateOutput :: Text -> CommitSha -> Text -> Int -> Maybe Text -> [Text] -> Maybe Text -> Text
reviewerStateOutput status commit promptVersion commentCount lgtmComment findings blockedReason =
  jsonText
    ( object
        [ "review_status" .= status
        , "reviewed_commit_sha" .= unCommitSha commit
        , "reviewer_prompt_version" .= promptVersion
        , "added_review_comment_count" .= commentCount
        , "lgtm_comment" .= lgtmComment
        , "findings_summary" .= findings
        , "blocked_reason" .= blockedReason
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
      cleanReviewOutput = reviewerStateOutput "clean" reviewerCommit reviewerPromptVersion 0 (Just "LGTM") [] Nothing
   in
  classifyIssuePlanningTurn (AppServerTurn (TurnId "planning") "completed" (Just "stable issue set")) == Just (ObservedPlanningBlocked (BlockedReason "planning turn completed without structured outcome"))
    && classifyIssuePlanTurn (AppServerTurn (TurnId "plan") "completed" (Just "plan written")) == Just (ObservedIssueImplementBlocked (BlockedReason "plan turn completed without structured plan output"))
    && classifyIssueImplementationTurn (Just (PrNumber 7)) (AppServerTurn (TurnId "impl") "completed" (Just "ready for review")) == Just (ObservedImplementationIncomplete "implementation turn completed without structured outcome")
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker") "completed" (Just "resolved")) == Just (ObservedWorkerOutcome (WorkerIncomplete "worker turn completed without structured outcome"))
    && classifyPrReviewReviewerTurn reviewerCommit (AppServerTurn (TurnId "reviewer") "completed" (Just cleanReviewOutput)) == Just (ObservedReviewerOutcome (ReviewerClean (CleanReviewEvidence reviewerCommit "LGTM")))

prop_turnClassifierPrefersStructuredOutputs :: Bool
prop_turnClassifierPrefersStructuredOutputs =
  let issueRequest = IssueCreationRequest "Subissue A" "Split from parent" Nothing
      subissueRequest = IssueCreationRequest "Subissue B" "Split from existing parent" (Just (IssueNumber 8))
      planningGraph =
        PlanningGraph
          [IssueNumber 15]
          [BlockedPlanningIssue (IssueNumber 16) [IssueNumber 15] "wait"]
          [IssueDependency (IssueNumber 16) [IssueNumber 15]]
   in parseStructuredTurnOutcome "{\"outcome\":\"blocked\",\"reason\":\"schema blocker\"}" == Just (StructuredBlocked "schema blocker")
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning") "completed" (Just "{\"outcome\":\"complete\",\"issues_to_create\":[{\"title\":\"Subissue A\",\"body\":\"Split from parent\"}]}")) == Just (ObservedPlanningIssuesRequested [issueRequest])
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-subissue") "completed" (Just "{\"outcome\":\"complete\",\"subissues_to_create\":[{\"title\":\"Subissue B\",\"body\":\"Split from existing parent\",\"parentIssueNumber\":8}]}")) == Just (ObservedPlanningIssuesRequested [subissueRequest])
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-invalid-subissue") "completed" (Just "{\"outcome\":\"complete\",\"subissues_to_create\":[{\"title\":\"Subissue B\",\"parentIssueNumber\":8}]}")) == Just (ObservedPlanningBlocked (BlockedReason "planning turn returned invalid issue creation payload"))
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-graph") "completed" (Just "{\"outcome\":\"complete\",\"ready_issues\":[15],\"blocked_issues\":[{\"issueNumber\":16,\"blockedBy\":[15],\"reason\":\"wait\"}],\"dependencies\":[{\"issueNumber\":16,\"dependsOn\":[15]}]}")) == Just (ObservedPlanningGraphUpdated planningGraph)
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-graph-rich") "completed" (Just "{\"outcome\":\"complete\",\"ready_issues\":[{\"number\":15,\"title\":\"ready\"}],\"blocked_issues\":[{\"number\":16,\"blocked_by\":[15],\"reason\":\"wait\"}],\"dependencies\":[{\"issue\":16,\"depends_on\":[15]}]}")) == Just (ObservedPlanningGraphUpdated planningGraph)
    && parseStructuredTurnOutcome "{\"outcome\":\"blocked\"}" == Nothing
    && classifyIssuePlanTurn (AppServerTurn (TurnId "plan") "completed" (Just "{\"outcome\":\"complete\",\"reason\":\"\",\"summary\":\"plan ready\",\"plan_markdown\":\"Implement the issue in small verified steps.\"}")) == Just (ObservedPlanCompleted sampleIssuePlanMarkdown Nothing)
    && classifyIssueImplementationTurn (Just (PrNumber 7)) (AppServerTurn (TurnId "impl") "completed" (Just "{\"outcome\":\"complete\",\"summary\":\"ready\"}")) == Just (ObservedImplementationCompleted (PrNumber 7))
    && classifyIssueImplementationTurn (Just (PrNumber 7)) (AppServerTurn (TurnId "impl-clean") "completed" (Just "{\"outcome\":\"clean\",\"summary\":\"review-only\"}")) == Just (ObservedImplementationIncomplete "implementation turn completed without structured outcome")
    && classifyIssueImplementationTurn (Just (PrNumber 7)) (AppServerTurn (TurnId "impl-problems") "completed" (Just "{\"outcome\":\"problems\",\"summary\":\"review-only\"}")) == Just (ObservedImplementationIncomplete "implementation turn completed without structured outcome")
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker") "completed" (Just "{\"outcome\":\"incomplete\",\"reason\":\"tests still failing\"}")) == Just (ObservedWorkerOutcome (WorkerIncomplete "tests still failing"))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer") "completed" (Just (reviewerStateOutput "clean" (CommitSha "abc123") reviewerPromptVersion 0 (Just "LGTM") [] Nothing))) == Just (ObservedReviewerOutcome (ReviewerClean (CleanReviewEvidence (CommitSha "abc123") "LGTM")))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-missing-state") "completed" (Just "{\"result\":\"clean\",\"comment\":\"schema LGTM\"}")) == Just (ObservedReviewerOutcome (ReviewerIncomplete "reviewer state missing required fields: review_status, reviewed_commit_sha, reviewer_prompt_version, added_review_comment_count, lgtm_comment, findings_summary, blocked_reason"))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-comments") "completed" (Just (reviewerStateOutput "comments_added" (CommitSha "abc123") reviewerPromptVersion 1 Nothing ["left inline comment"] Nothing))) == Just (ObservedReviewerOutcome (ReviewerProblemsAdded (CommitSha "abc123")))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-sha-mismatch") "completed" (Just (reviewerStateOutput "clean" (CommitSha "def456") reviewerPromptVersion 0 (Just "LGTM") [] Nothing))) == Just (ObservedReviewerOutcome (ReviewerIncomplete "reviewer inspected def456, expected abc123"))

prop_turnClassifierBlocksMissingOutputs :: Bool
prop_turnClassifierBlocksMissingOutputs =
  classifyIssuePlanningTurn (AppServerTurn (TurnId "planning") "completed" Nothing) == Just (ObservedPlanningBlocked (BlockedReason "planning turn completed without output"))
    && classifyIssuePlanTurn (AppServerTurn (TurnId "plan") "completed" Nothing) == Just (ObservedIssueImplementBlocked (BlockedReason "plan turn completed without output"))
    && classifyIssueImplementationTurn (Just (PrNumber 7)) (AppServerTurn (TurnId "impl") "completed" Nothing) == Just (ObservedImplementationBlocked (BlockedReason "implementation turn completed without output"))
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker") "completed" Nothing) == Just (ObservedWorkerOutcome (WorkerBlocked (BlockedReason "worker turn completed without output")))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer") "completed" (Just "  ")) == Just (ObservedReviewerOutcome (ReviewerBlocked (BlockedReason "reviewer turn completed without output")))

effectRuntimeConfig :: RepoName -> FilePath -> Int -> EffectRuntimeConfig
effectRuntimeConfig repo workdir requestId =
  EffectRuntimeConfig
    { effectRuntimeRepo = repo
    , effectRuntimeWorkdir = workdir
    , effectRuntimeStateDir = workdir </> ".watcher"
    , effectRuntimeMergeMethod = "merge"
    , effectRuntimeNextRequestId = requestId
    , effectRuntimePlannerThreadInstructions = "planner developer instructions"
    , effectRuntimePlannerTurn = turnRuntime "planner prompt" Nothing
    , effectRuntimeWorkerTurn = turnRuntime "worker prompt" Nothing
    , effectRuntimeIssuePlanTurn = turnRuntime "issue plan prompt" Nothing
    , effectRuntimeIssueImplementationTurn = turnRuntime "issue implementation prompt" Nothing
    , effectRuntimeReviewerTurn = turnRuntime "reviewer prompt" Nothing
    }
 where
  turnRuntime input collaborationMode =
    TurnRuntimeConfig
      { turnRuntimeCwd = workdir
      , turnRuntimeModel = defaultModel
      , turnRuntimeEffort = defaultEffort
      , turnRuntimeApprovalPolicy = defaultApprovalPolicy
      , turnRuntimeSandboxPolicy = defaultSandboxPolicy
      , turnRuntimeInput = input
      , turnRuntimeOutputSchema = Nothing
      , turnRuntimeCollaborationMode = collaborationMode
      }

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
    lookupValue "outputSchema" request.requestParams
  _ ->
    Nothing

actionTurnCollaborationMode :: PlannedAction -> Maybe Value
actionTurnCollaborationMode = \case
  PlannedAppServerRequest request ->
    lookupValue "collaborationMode" request.requestParams
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
            && compiled.compiledNextRequestId == 10

prop_effectInterpreterPrBodyUpdateUsesIssuePlan :: IssueConfig -> PrNumber -> Bool
prop_effectInterpreterPrBodyUpdateUsesIssuePlan issueConfig prNumber =
  let config = effectRuntimeConfig issueConfig.issueRepo "/tmp/work" 11
      compiled = compileEffectPlan config [SomeEffect (UpdatePullRequestBody issueConfig prNumber)]
   in compiled.compiledActions == [PlannedCommand (GhUpdatePullRequestBody "/tmp/work" issueConfig prNumber "/tmp/work/.watcher/issue-plan.md")]
        && compiled.compiledNextRequestId == 11

prop_effectInterpreterIssueTurnsUsePhaseSpecificPrompts :: ThreadId -> Bool
prop_effectInterpreterIssueTurnsUsePhaseSpecificPrompts threadId =
  let issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 26) (BranchName "codex/issue-26")
      prNumber = PrNumber 29
      compiled =
        compileEffectPlan
          (effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 16)
          [ SomeEffect (StartIssuePlanWorkerTurn issueConfig prNumber threadId)
          , SomeEffect (StartIssueImplementationWorkerTurn threadId)
          , SomeEffect (StartWorkerTurn threadId)
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
        && actionIsTurnStartWithInput threadId "worker prompt" (actions !! 2)
        && compiled.compiledNextRequestId == 19

prop_defaultEffectRuntimeConfigUsesStructuredOutputSchemas :: Bool
prop_defaultEffectRuntimeConfigUsesStructuredOutputSchemas =
  let repo = RepoName "soulomoon/mlf2"
      issueConfig = IssueConfig repo (IssueNumber 26) (BranchName "codex/issue-26")
      prConfig = PrConfig repo (PrNumber 29) (BranchName "codex/issue-26")
      issuePrNumber = PrNumber 29
      plannerThread = ThreadId "planner"
      workerThread = ThreadId "worker"
      reviewerThread = ThreadId "reviewer"
      compiled =
        compileEffectPlan
          (defaultEffectRuntimeConfig repo "/tmp/work" "/tmp/state")
          [ SomeEffect (StartPlannerTurn plannerThread)
          , SomeEffect (StartIssuePlanWorkerTurn issueConfig issuePrNumber workerThread)
          , SomeEffect (StartIssueImplementationWorkerTurn workerThread)
          , SomeEffect (StartWorkerTurn workerThread)
          , SomeEffect (StartReviewerTurn prConfig (CommitSha "abc123") reviewerThread)
          ]
      actions = compiled.compiledActions
   in length actions == 5
        && map actionTurnOutputSchema actions
          == [ Just plannerTurnOutputSchema
             , Just issuePlanTurnOutputSchema
             , Just issueImplementationTurnOutputSchema
             , Just prReviewWorkerTurnOutputSchema
             , Just reviewerTurnOutputSchema
             ]
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
    && "plan_markdown" `elem` schemaRequiredFields issuePlanTurnOutputSchema

schemaRequiresOutcomeReasonSummary :: Value -> Bool
schemaRequiresOutcomeReasonSummary schema =
  let requiredFields = schemaRequiredFields schema
   in all (`elem` requiredFields) ["outcome", "reason", "summary"]

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
      planModePrompt = issuePlanModeDeveloperInstructions "/tmp/work" "/tmp/state/issue26" issueConfig (PrNumber 31)
   in promptContainsAll
        workerPrompt
        [ "Publishing protocol, required for this environment:"
        , "gh auth setup-git"
        , "Completion contract:"
        , "remaining_unresolved_thread_ids"
        , "/tmp/state/pr29/agent-state.json"
        , "Stage only files related to the current issue/PR"
        , "never stage watcher state or runtime files"
        , "If unrelated dirty changes make safe staging unclear"
        ]
        && promptContainsAll
          reviewerPrompt
          [ "dedicated English-only PR reviewer"
          , "add inline GitHub PR review comments"
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
          , "only classify the listed root issues"
          , "concrete body with scope, acceptance criteria"
          , "Ignore repository-local legacy orchestrator prompts"
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
          , plannerPrompt
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
    , "additional schema-required fields such as plan_markdown"
    , "Plain prose completion is not accepted"
    , "outcome=blocked with a non-empty reason"
    , "outcome=incomplete with a non-empty reason"
    , "outcome=complete with a non-empty summary"
    ]
    && reviewerPromptVersion == "haskell-pro-style-v3-agent-principle"

prop_promptPipelineAlignmentContracts :: Bool
prop_promptPipelineAlignmentContracts =
  promptContainsAll
    plannerTurnInput
    [ "Read the current issue snapshot"
    , "return the issue-planning decision JSON"
    , "Inspect existing GitHub issues and sub-issues when needed"
    ]
    && promptContainsNone
      plannerTurnInput
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
      , "Only write state files explicitly named by the completion contract"
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
            && compiled.compiledNextRequestId == 41
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
  let compiled =
        compileEffectPlan
          (effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 20)
          [ SomeEffect (StartWorkerTurn workerThread)
          , SomeEffect (StartReviewerTurn (PrConfig (RepoName "soulomoon/mlf2") (PrNumber 7) (BranchName "codex/issue-7")) (CommitSha "abc123") reviewerThread)
          ]
   in fmap appServerRequestId compiled.compiledActions == [Just 20, Just 21]
        && compiled.compiledNextRequestId == 22

prop_effectInterpreterRecordBlockedWritesBlockState :: BlockedReason -> Bool
prop_effectInterpreterRecordBlockedWritesBlockState reason =
  let config = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 30
      compiled = compileEffectPlan config [SomeEffect (RecordBlocked reason)]
      expectedPath = config.effectRuntimeStateDir </> "block-state.json"
      expectedJson = object ["blocked" .= True, "reason" .= unBlockedReason reason]
   in compiled.compiledActions == [PlannedWriteJson expectedPath expectedJson]
        && compiled.compiledNextRequestId == 30

prop_effectInterpreterRecordPlanningGraphWritesState :: PlanningGraph -> Bool
prop_effectInterpreterRecordPlanningGraphWritesState graph =
  let config = effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 32
      compiled = compileEffectPlan config [SomeEffect (RecordPlanningGraph graph)]
      expectedPath = config.effectRuntimeStateDir </> "planning-state.json"
   in compiled.compiledActions == [PlannedWriteJson expectedPath (toJSON graph)]
        && compiled.compiledNextRequestId == 32

prop_effectInterpreterCreateIssueUsesConfiguredEffect :: RepoName -> IssueCreationRequest -> Bool
prop_effectInterpreterCreateIssueUsesConfiguredEffect repo request =
  let config = effectRuntimeConfig repo "/tmp/work" 35
      compiled = compileEffectPlan config [SomeEffect (CreateIssue repo request)]
   in compiled.compiledActions == [PlannedCommand (GhIssueCreate repo request)]
        && compiled.compiledNextRequestId == 35

prop_effectInterpreterMergeUsesConfiguredRepoAndMethod :: PrNumber -> CleanReviewEvidence -> Bool
prop_effectInterpreterMergeUsesConfiguredRepoAndMethod prNumber cleanEvidence =
  let repo = RepoName "soulomoon/mlf2"
      config = (effectRuntimeConfig repo "/tmp/work" 40) {effectRuntimeMergeMethod = "squash"}
      compiled = compileEffectPlan config [SomeEffect (MergePullRequest prNumber cleanEvidence)]
   in compiled.compiledActions == [PlannedCommand (GhPrCommentReviewAndMerge repo prNumber cleanEvidence "squash")]

prop_actionExecutorDryRunPreservesActionOrder :: Bool
prop_actionExecutorDryRunPreservesActionOrder =
  let compiled =
        compileEffectPlan
          (effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 50)
          [ SomeEffect (PushBranch (BranchName "codex/example"))
          , SomeEffect (StartWorkerTurn (ThreadId "worker-thread"))
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
  let stateDir = "/tmp/codex-watcher-hs-runtime-owner"
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
  let stateDir = "/tmp/codex-watcher-hs-runtime-owner-clear"
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
  let stateDir = "/tmp/codex-watcher-hs-runner-guard-complete"
      eventsPath = stateDir </> "events.jsonl"
      pidPath = stateDir </> "watcher.pid"
      events =
        [ IssuePlanningInitialized (PlannerConfig (RepoName "owner/name") 8 [])
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn")
        , IssuePlanningTurnCompleted
        ]
      config =
        RunnerGuardConfig
          { guardRepo = RepoName "owner/name"
          , guardDomain = IssuePlanning
          , guardEventsPath = eventsPath
          , guardStateDir = stateDir
          , guardWatcherPidFile = pidPath
          , guardAppServerEndpoint = AppServerEndpoint "127.0.0.1" 9 "/"
          , guardStaleSeconds = 1
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
  let stateDir = "/tmp/codex-watcher-hs-runner-guard-restart"
      eventsPath = stateDir </> "events.jsonl"
      pidPath = stateDir </> "watcher.pid"
      events = [IssuePlanningInitialized (PlannerConfig (RepoName "owner/name") 8 [])]
      config =
        RunnerGuardConfig
          { guardRepo = RepoName "owner/name"
          , guardDomain = IssuePlanning
          , guardEventsPath = eventsPath
          , guardStateDir = stateDir
          , guardWatcherPidFile = pidPath
          , guardAppServerEndpoint = AppServerEndpoint "127.0.0.1" 9 "/"
          , guardStaleSeconds = 999999
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
  let stateDir = "/tmp/codex-watcher-hs-runner-guard-waiting"
      eventsPath = stateDir </> "events.jsonl"
      pidPath = stateDir </> "watcher.pid"
      events =
        [ IssuePlanningInitialized (PlannerConfig (RepoName "owner/name") 8 [])
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn")
        , IssuePlanningGraphUpdated (PlanningGraph [IssueNumber 42] [] [])
        ]
      config =
        RunnerGuardConfig
          { guardRepo = RepoName "owner/name"
          , guardDomain = IssuePlanning
          , guardEventsPath = eventsPath
          , guardStateDir = stateDir
          , guardWatcherPidFile = pidPath
          , guardAppServerEndpoint = AppServerEndpoint "127.0.0.1" 9 "/"
          , guardStaleSeconds = 999999
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
  let stateDir = "/tmp/codex-watcher-hs-runner-guard-repair"
      eventsPath = stateDir </> "events.jsonl"
      pidPath = stateDir </> "watcher.pid"
      events =
        [ IssuePlanningInitialized (PlannerConfig (RepoName "owner/name") 8 [])
        , IssuePlanningTurnCompleted
        ]
      config =
        RunnerGuardConfig
          { guardRepo = RepoName "owner/name"
          , guardDomain = IssuePlanning
          , guardEventsPath = eventsPath
          , guardStateDir = stateDir
          , guardWatcherPidFile = pidPath
          , guardAppServerEndpoint = AppServerEndpoint "127.0.0.1" 9 "/"
          , guardStaleSeconds = 999999
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
  let stateDir = "/tmp/codex-watcher-hs-runtime-status"
      configPath = stateDir </> "config.json"
      eventsPath = stateDir </> "events.jsonl"
      pidPath = stateDir </> "watcher.pid"
      plannerConfig = PlannerConfig (RepoName "owner/name") 8 []
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
        watcherRuntimeStatus
          WatcherRuntimeStatusConfig
            { watcherRuntimeExpectedDomain = IssuePlanning
            , watcherRuntimeConfigPath = configPath
            , watcherRuntimeEventsPath = eventsPath
            , watcherRuntimePidPath = pidPath
            , watcherRuntimeMissingIsTerminal = pure missingIsTerminal
            , watcherRuntimeReplayTerminalIsTerminal = \replay ->
                pure $
                  terminalIsTerminal
                    && someDomain replay.replayState == IssuePlanning
                    && isTerminalPhase (somePhase replay.replayState)
            }
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

appServerRequestId :: PlannedAction -> Maybe Int
appServerRequestId = \case
  PlannedAppServerRequest request -> Just request.requestId
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
    sequence
      [ goldenEventLogCase "golden/event-log/pr-review/mlf2-pr6-merged/events.jsonl" PrReview Complete
      , goldenEventLogCase "golden/event-log/pr-review/mlf2-pr6-reviewer-comments/events.jsonl" PrReview CheckingReviews
      , goldenEventLogCase "golden/event-log/pr-review/mlf2-pr6-worker-incomplete/events.jsonl" PrReview CheckingReviews
      , goldenEventLogCase "golden/event-log/pr-review/mlf2-pr6-reviewer-incomplete/events.jsonl" PrReview CheckingReviews
      , goldenEventLogCase "golden/event-log/issue-implement/mlf2-issue42-complete/events.jsonl" IssueImplement Complete
      , goldenEventLogCase "golden/event-log/issue-implement/mlf2-issue42-pr-created/events.jsonl" IssueImplement Implementing
      , goldenEventLogCase "golden/event-log/issue-implement/mlf2-issue42-pr-reused/events.jsonl" IssueImplement Implementing
      , goldenEventLogCase "golden/event-log/issue-implement/mlf2-issue42-incomplete-then-complete/events.jsonl" IssueImplement Complete
      , goldenEventLogCase "golden/event-log/issue-implement/mlf2-issue42-implementation-blocked/events.jsonl" IssueImplement Blocked
      , goldenEventLogCase "golden/event-log/issue-planning/mlf2-planning-ready/events.jsonl" IssuePlanning Complete
      ]
  pure (and results)

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
  let compiled =
        compileEffectPlan
          (effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 60)
          [ SomeEffect (PushBranch (BranchName "codex/example"))
          , SomeEffect (StartWorkerTurn (ThreadId "worker-thread"))
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
      compiled =
        compileEffectPlan
          config
          [ SomeEffect (PushBranch (BranchName "codex/example"))
          , SomeEffect (StartWorkerTurn (ThreadId "worker-thread"))
          , SomeEffect (RecordBlocked blockedReason)
          , SomeEffect SleepUntilNextPoll
          , SomeEffect StopDaemon
          ]
  reports <- executeCompiledEffectPlan executor ExecuteActions compiled
  calls <- getCalls
  let expectedBlockPath = config.effectRuntimeStateDir </> "block-state.json"
      expectedBlockJson = object ["blocked" .= True, "reason" .= unBlockedReason blockedReason]
      expectedCalls =
        [ FakeCommand (GitPush "/tmp/work" (BranchName "codex/example"))
        , FakeAppServer (turnStartRequest 70 (turnStartOptionsForTest (ThreadId "worker-thread")))
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
 where
  turnStartOptionsForTest threadId =
    defaultTurnStartOptions threadId "/tmp/work" "worker prompt"

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
        [ IssuePlanningInitialized (PlannerConfig (RepoName "soulomoon/mlf2") 8 [])
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
      events = [IssuePlanningInitialized (PlannerConfig (RepoName "soulomoon/mlf2") 8 [])]
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
      events = [IssuePlanningInitialized (PlannerConfig (RepoName "soulomoon/mlf2") 8 [])]
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
      events = [IssuePlanningInitialized (PlannerConfig (RepoName "soulomoon/mlf2") 8 [])]
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
          , assert "observed execute runs effect actions" (any isFakeAppServer calls)
          , assert "observed execute reaches plan mode" (somePhase tick.daemonObservedState == PlanMode)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL observed daemon execute: " <> Text.unpack (formatDaemonFailure failure))
      pure False
 where
  isFakeAppServer = \case
    FakeAppServer {} -> True
    _ -> False

observedDaemonTickExecuteCommandFailureDoesNotAppendEvent :: IO Bool
observedDaemonTickExecuteCommandFailureDoesNotAppendEvent = do
  let repo = RepoName "soulomoon/mlf2"
      plannerConfig = PlannerConfig repo 4 []
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
      observation = DaemonIssuePlanningObservation (ObservedPlanningIssuesRequested [issueRequest])
  result <- runObservedDaemonTickWithEvents executor options events observation
  calls <- getCalls
  results <-
    sequence
      [ assert "observed execute fails failed command before event commit" (case result of Left DaemonActionFailed {} -> True; _ -> False)
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
        , PrReviewCleanFound cleanEvidence
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
    FakeCommand GhPrCommentReviewAndMerge {} -> True
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
        , PrReviewCleanFound cleanEvidence
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
          , assert "pre-merge gate reads required checks" (FakeCommand (GhPrChecks repo prNumber) `elem` calls)
          , assert "pre-merge gate merges after passing checks" (any isMerge calls)
          , assert "pre-merge gate reaches merging state" (observedPhase == Just Merging)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL pre-merge clean gate: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isMerge = \case
    FakeCommand GhPrCommentReviewAndMerge {} -> True
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
        , PrReviewCleanFound cleanEvidence
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
    FakeCommand GhPrCommentReviewAndMerge {} -> True
    _ -> False
  isBlockWrite = \case
    FakeWriteJson path _ -> path == "/tmp/work/.watcher/block-state.json"
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
      events = [IssuePlanningInitialized (PlannerConfig (RepoName "soulomoon/mlf2") 8 [])]
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
      events = [IssuePlanningInitialized (PlannerConfig repo 8 [issueNumber])]
      snapshotPath = runtimeConfig.effectRuntimeStateDir </> "issue-snapshot.json"
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
          , assert "automatic planning execute emits start event" (observedEvent == Just (IssuePlanningTurnStarted (ThreadId "thread-started") (TurnId "turn-started")))
          , assert "automatic planning execute starts one turn" (length starts == 1)
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
      events = [IssuePlanningInitialized (PlannerConfig repo 8 [issueNumber])]
      snapshotPath = runtimeConfig.effectRuntimeStateDir </> "issue-snapshot.json"
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
        [ IssuePlanningInitialized (PlannerConfig repo 8 [])
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
          , assert "planning issue creation emits request event" (observedEvent == Just (IssuePlanningIssuesRequested [issueRequest]))
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
        [ IssuePlanningInitialized (PlannerConfig repo 8 [])
        , IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "turn-plan")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
          expectedPath = runtimeConfig.effectRuntimeStateDir </> "planning-state.json"
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
        [ IssuePlanningInitialized (PlannerConfig repo 8 [IssueNumber 12, IssueNumber 26, IssueNumber 27, IssueNumber 28])
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
        [ IssuePlanningInitialized (PlannerConfig repo 8 [IssueNumber 12, IssueNumber 26, IssueNumber 27, IssueNumber 28])
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
          , assert "canonical planning graph records normalized state" (FakeWriteJson (runtimeConfig.effectRuntimeStateDir </> "planning-state.json") (toJSON expectedGraph) `elem` calls)
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
  secondEvent <- observedEventFor (baseEvents <> [IssueImplementationCompletedEvent prNumber])
  thirdEvent <- observedEventFor (baseEvents <> [IssueImplementationCompletedEvent prNumber, IssueReviewHandoffInitializedEvent prNumber])
  fourthEvent <- observedEventFor (baseEvents <> [IssueImplementationCompletedEvent prNumber, IssueReviewHandoffInitializedEvent prNumber, IssueReviewHandoffStartedEvent prNumber])
  results <-
    sequence
      [ assert "automatic implementation completion records implementation completion first" (firstEvent == Just (IssueImplementationCompletedEvent prNumber))
      , assert "automatic implementation completion initializes handoff second" (secondEvent == Just (IssueReviewHandoffInitializedEvent prNumber))
      , assert "automatic implementation completion starts handoff third" (thirdEvent == Just (IssueReviewHandoffStartedEvent prNumber))
      , assert "automatic implementation completion waits for PR merge after handoff" (fourthEvent == Nothing)
      ]
  pure (and results)

automaticIssueMergeWaitsForIssueClose :: IO Bool
automaticIssueMergeWaitsForIssueClose = do
  merged <- runIssueMergeCheck issueEvents mergedPrCommand
  closed <- runIssueMergeCheck (issueEvents <> [IssuePullRequestMergedEvent (PrNumber 7)]) closedIssueCommand
  open <- runIssueMergeTick (issueEvents <> [IssuePullRequestMergedEvent (PrNumber 7)]) openIssueCommand
  results <-
    sequence
      [ assert "merged PR moves issue implementer to issue-close wait" (merged == Just (IssuePullRequestMergedEvent (PrNumber 7), Implementing))
      , assert "closed issue completes issue implementer" (closed == Just (IssueClosedEvent (PrNumber 7), Complete))
      , assert "open issue waits after scheduling close" (maybe False issueCloseScheduled open)
      ]
  pure (and results)
 where
  mergedPrCommand = \case
      GhPrView {} -> jsonCommandReport (object ["state" .= ("MERGED" :: Text)])
      command -> defaultFakeCommand command
  closedIssueCommand = \case
      GhIssueView {} -> jsonCommandReport (object ["state" .= ("CLOSED" :: Text), "closed" .= True])
      command -> defaultFakeCommand command
  openIssueCommand = \case
      GhIssueView {} -> jsonCommandReport (object ["state" .= ("OPEN" :: Text), "closed" .= False])
      command -> defaultFakeCommand command
  runIssueMergeCheck events commandHandler = do
    tick <- runIssueMergeTick events commandHandler
    pure $ tick >>= \result -> (\observed -> (observed.daemonObservedEvent, somePhase observed.daemonObservedState)) <$> result.loopObservedTick
  runIssueMergeTick events commandHandler = do
    (executor, _getCalls) <-
      fakeActionExecutorWith
        commandHandler
        defaultFakeAppServer
    let repo = RepoName "soulomoon/mlf2"
        runtimeConfig = effectRuntimeConfig repo "/tmp/work" 155
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
  issueEvents =
    let issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
     in
          [ IssueImplementInitialized issueConfig (ThreadId "worker-thread")
          , IssuePullRequestReusedEvent (PrNumber 7)
          , IssuePlanTurnStartedEvent (TurnId "turn-plan")
          , IssuePlanCompletedEvent sampleIssuePlanMarkdown Nothing
          , IssuePullRequestBodyUpdatedEvent (PrNumber 7)
          , IssueImplementationTurnStartedEvent (TurnId "turn-impl")
          , IssueImplementationCompletedEvent (PrNumber 7)
          , IssueReviewHandoffInitializedEvent (PrNumber 7)
          , IssueReviewHandoffStartedEvent (PrNumber 7)
          ]
  issueCloseScheduled tick =
    case tick.loopObservedTick of
      Nothing -> any isGhIssueCloseReport tick.loopActionReports
      Just _ -> False
  isGhIssueCloseReport report =
    case report.actionExecutionAction of
      PlannedCommand GhIssueClose {} -> True
      _ -> False

automaticStaleActiveTurnBlocksAfterThreeMisses :: IO Bool
automaticStaleActiveTurnBlocksAfterThreeMisses = do
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
        [ IssuePlanningInitialized (PlannerConfig repo 1 [])
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
          "third missing active turn blocks"
          ( eventOf third
              == Just (WatcherBlocked (BlockedReason "active turn not found after 3 consecutive checks: missing-turn"))
          )
      , assert "stale active turn marker is persisted" (not (null markerWrites))
      , assert "stale active turn marker is cleared on block" (last markerWrites == Null)
      ]
  pure (and results)

automaticDaemonLoopRetriesPrCreateWhileWaitingForPr :: IO Bool
automaticDaemonLoopRetriesPrCreateWhileWaitingForPr = do
  (executor, getCalls) <-
    fakeActionExecutorWith
      ( \case
          GhPrListOpen {} -> CommandReport {ok = True, status = Just 0, stdout = "[]", stderr = "", errorMessage = Nothing}
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
          , assert "missing PR retry checks open PRs" (FakeCommand (GhPrListOpen repo) `elem` calls)
          , assert "missing PR retry re-runs create PR" (FakeCommand (GhCreatePullRequest "/tmp/work" issueConfig) `elem` calls)
          , assert "missing PR retry sleeps after create attempt" (FakeSleep `elem` calls)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic PR retry: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

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
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      results <-
        sequence
          [ assert (caseName <> " body update emits event") ((daemonObservedEvent <$> tick.loopObservedTick) == Just (IssuePullRequestBodyUpdatedEvent prNumber))
          , assert (caseName <> " body update writes plan before command") (callBefore expectedWrite (FakeCommand expectedCommand) calls)
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
      results <-
        sequence
          [ assert "body-updated PR starts implementation" ((daemonObservedEvent <$> tick.loopObservedTick) == Just (IssueImplementationTurnStartedEvent (TurnId "turn-started")))
          , assert "body-updated PR does not update body again" (FakeCommand (GhUpdatePullRequestBody "/tmp/work" issueConfig prNumber "/tmp/work/.watcher/issue-plan.md") `notElem` calls)
          , assert "body-updated PR starts app-server turn" (any isTurnStartCall calls)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic implementation start after PR body update: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False
 where
  isTurnStartCall = \case
    FakeAppServer request -> request.requestMethod == "turn/start"
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
        , PrReviewCleanFound cleanEvidence
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
        , PrReviewCleanFound cleanEvidence
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

observeOnceParsingCoversDomainsAndDefaults :: IO Bool
observeOnceParsingCoversDomainsAndDefaults = do
  planning <-
    parseDaemonObservation
      ( (baseObserveCli CliIssuePlanning "turn-started")
          { observeCliThreadId = Just (ThreadId "planner-thread")
          , observeCliTurnId = Just (TurnId "planner-turn")
          }
      )
  issueIncomplete <-
    parseDaemonObservation
      (baseObserveCli CliIssueImplement "implementation-incomplete")
  prWorkerIncomplete <-
    parseDaemonObservation
      (baseObserveCli CliPrReview "worker-incomplete")
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

baseObserveCli :: CliDomain -> String -> ObserveOnceCli
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
      , quickCheckResult prop_terminalStateHasNoImplicitEffects
      , quickCheckResult prop_eventLogFullPrReviewPathCompletes
      , quickCheckResult prop_eventLogCannotReviewCleanWhileFixing
      , quickCheckResult prop_eventLogCannotMergeBeforeCleanReview
      , quickCheckResult prop_eventLogFullIssueImplementationPathCompletes
      , quickCheckResult prop_eventLogCannotCompleteIssueBeforePlanning
      , quickCheckResult prop_eventLogRefreshesIdleIssueWorkerThread
      , quickCheckResult prop_eventLogRefreshesIdlePrReviewThreads
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
      , quickCheckResult prop_issueImplementWatcherMergedWaitsForIssueClose
      , quickCheckResult prop_issueImplementWatcherIssueClosedCompletes
      , quickCheckResult prop_issueImplementWatcherBlockedStops
      , quickCheckResult prop_issueImplementationCompatibilityWritesPrUrl
      , quickCheckResult prop_prReviewCompatibilityClearsCheckerState
      , quickCheckResult prop_eventLogFullIssuePlanningPathReturnsReady
      , quickCheckResult prop_eventLogIssuePlanningIssueCreationReturnsReady
      , quickCheckResult prop_eventLogIssuePlanningGraphWaitsForReadyIssues
      , quickCheckResult prop_eventLogIssuePlanningReadyIssuesFixedReentersPlanning
      , quickCheckResult prop_eventLogCannotCompletePlanningBeforeStart
      , quickCheckResult prop_issuePlanningWatcherStartsAndCompletesTurn
      , quickCheckResult prop_issuePlanningWatcherCreatesIssuesBeforeReplanning
      , quickCheckResult prop_issuePlanningWatcherRecordsGraphBeforeFanoutAndWaits
      , quickCheckResult prop_issuePlanningWatcherBlocksOutOfScopeGraph
      , quickCheckResult prop_canonicalPlanningGraphUsesDependencyHintsAndOpenChildren
      , quickCheckResult prop_issuePlanningSelectionRespectsMaxParallelAndSkipsActive
      , quickCheckResult prop_issuePlanningFanoutBuildsLaunchPlans
      , quickCheckResult prop_issuePlanningFanoutParsesImplementerConfig
      , quickCheckResult prop_issuePlanningFanoutDetectsCompletionBoundary
      , quickCheckResult prop_issuePlanningFanoutUsesOnlyReadyIssues
      , quickCheckResult prop_issuePlanningReadyFanoutDoesNotRecreateExistingImplementers
      , quickCheckResult prop_eventLogCanonicalJsonRoundTrips
      , quickCheckResult prop_eventLogCanonicalIssuePlanStartName
      , quickCheckResult prop_eventLogRejectsLegacyIssuePlanAliases
      , quickCheckResult prop_eventLogRejectsEmptyReviewThreads
      , quickCheckResult prop_eventLogRepairIssue26MissingPlanReentersImplementation
      , quickCheckResult prop_eventLogRepairDropsCompletionWithoutImplementationTurn
      , quickCheckResult prop_eventLogRepairDropsStalePlanningReadyIssuesFixed
      , quickCheckResult prop_eventLogRepairRejectsValidEventLog
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
      , quickCheckResult prop_prReviewWatcherCleanStartsReviewer
      , quickCheckResult prop_prReviewWatcherWorkerIncompleteReturnsToChecking
      , quickCheckResult prop_prReviewWatcherCleanReviewerWaitsForMergeability
      , quickCheckResult prop_runtimeCommandSpecsHaveExecutable
      , quickCheckResult prop_runtimeGitPushDryRunNeverForces
      , quickCheckResult prop_runtimeGitPushNeverForces
      , quickCheckResult prop_runtimeGhPrViewUsesStructuredFields
      , quickCheckResult prop_runtimeGhPrChecksUsesRequiredCurrentCli
      , quickCheckResult prop_runtimeGhIssueCreateUsesRepoTitleAndBody
      , quickCheckResult prop_runtimeGhIssueCreateWithParentLinksSubIssue
      , quickCheckResult prop_runtimeGhIssueCloseCommentsAndCloses
      , quickCheckResult prop_runtimeGhPrCreateKeepsStdoutJsonOnly
      , quickCheckResult prop_runtimeGhPrBodyUpdateUsesPlanFile
      , quickCheckResult prop_runtimeGhPrCommentReviewAndMergeCommentsBeforeMerge
      , quickCheckResult prop_runtimeKillZeroOnlyChecksPid
      , quickCheckResult prop_ghGitParsesIssueAndPrLists
      , quickCheckResult prop_ghGitParsesRemoteIssueView
      , quickCheckResult prop_ghGitParsesRemotePrView
      , quickCheckResult prop_ghGitParsesPrCreateAndChecks
      , quickCheckResult prop_ghGitParsesReviewThreadsGraphql
      , quickCheckResult prop_ghGitParsesGitOutputs
      , quickCheckResult prop_appServerInitializeRequestMatchesJsonRpc
      , quickCheckResult prop_appServerInitializedNotificationMatchesJsonRpc
      , quickCheckResult prop_appServerThreadStartKeepsNodeNullFields
      , quickCheckResult prop_appServerTurnStartPlanModeEncodesCollaborationMode
      , quickCheckResult prop_runtimeDefaultsCentralizeThreadAndTurnOptions
      , quickCheckResult prop_jsonPathHelpersDecodeNestedValues
      , quickCheckResult prop_appServerThreadReadAndInterruptUseThreadIds
      , quickCheckResult prop_appServerClientInitializesSingleRequestSessions
      , quickCheckResult prop_appServerClientDetectsSystemErrorThreadStatus
      , quickCheckResult prop_appServerClientMatchesSuccessResponse
      , quickCheckResult prop_appServerClientSkipsNotifications
      , quickCheckResult prop_appServerClientRejectsMismatchedResponseIds
      , quickCheckResult prop_appServerClientSurfacesJsonRpcErrors
      , quickCheckResult prop_appServerClientRejectsUnsupportedJsonRpcVersion
      , quickCheckResult prop_appServerClientParsesThreadReadTurns
      , quickCheckResult prop_appServerClientParsesTurnStartTurnId
      , quickCheckResult prop_appServerClientParsesThreadStartThreadId
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
      , quickCheckResult prop_cliParsesHealthcheckAndRunLoop
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
  observedDaemonFailureOk <- observedDaemonTickExecuteCommandFailureDoesNotAppendEvent
  preMergeHeadChangedOk <- observedDaemonTickPreMergeGateRechecksWhenHeadChanged
  preMergeCleanOk <- observedDaemonTickPreMergeGateMergesWhenClean
  preMergeUnstableOk <- observedDaemonTickPreMergeGateWaitsWhenUnstable
  automaticPlanningDryRunOk <- automaticDaemonLoopPlanningDryRunStartsSyntheticTurn
  automaticPlanningSnapshotOk <- automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart
  automaticPlanningClosedScopeOk <- automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn
  automaticPlanningIssueCreationOk <- automaticDaemonLoopPlanningIssueCreationRequestsReplanning
  automaticPlanningGraphOk <- automaticDaemonLoopPlanningGraphWaitsAndRecords
  automaticPlanningClosedDepsOk <- automaticDaemonLoopPlanningGraphDropsClosedDependencies
  automaticPlanningCanonicalCoverageOk <- automaticDaemonLoopPlanningGraphCanonicalizesOpenScopeCoverage
  automaticExecutePrestartOk <- automaticDaemonLoopExecutePrestartsTurnOnce
  automaticActiveTurnOk <- automaticDaemonLoopActiveTurnCompletionObservesOutput
  automaticActiveTurnSystemErrorOk <- automaticDaemonLoopActiveTurnSystemErrorBlocksWatcher
  automaticPlanWriteBeforeEventOk <- automaticDaemonLoopWritesPlanBeforePlanCompletedEvent
  automaticMissingPlanPreValidationOk <- automaticDaemonLoopEmptyPlanMarkdownBlocksBeforePlanCompleted
  automaticImplementationHandoffOk <- automaticDaemonLoopImplementationCompletionSequencesHandoff
  automaticIssueMergeClosedOk <- automaticIssueMergeWaitsForIssueClose
  automaticStaleTurnOk <- automaticStaleActiveTurnBlocksAfterThreeMisses
  automaticPrRetryOk <- automaticDaemonLoopRetriesPrCreateWhileWaitingForPr
  automaticUnlinkedPrOk <- automaticDaemonLoopBlocksUnlinkedBranchPr
  automaticNewPrBodyOk <- automaticDaemonLoopUpdatesNewPrBodyBeforeImplementation
  automaticReusedPrBodyOk <- automaticDaemonLoopUpdatesReusedPrBodyBeforeImplementation
  automaticBodyThenImplementationOk <- automaticDaemonLoopStartsImplementationAfterPrBodyUpdate
  automaticMissingPlanBodyOk <- automaticDaemonLoopMissingPlanFailsPrBodyUpdate
  automaticTerminalStopOk <- automaticDaemonLoopTerminalStateStops
  automaticLoopLoggingOk <- automaticDaemonLoopEmitsBoundaryLogs
  runnerGuardOk <- runnerGuardIgnoresMissingPidForCompletePlanning
  runnerGuardRestartOk <- runnerGuardRestartsMissingPidForIncompletePlanning
  runnerGuardWaitingRestartOk <- runnerGuardRestartsMissingPidForWaitingPlanning
  runnerGuardRepairOk <- runnerGuardRepairsInvalidPlanningEventLog
  runtimeStatusOk <- runtimeStatusHelperCoversCommonCases
  runtimeOwnerLeaseOk <- runtimeOwnerLeaseParsingRejectsOwnerOnlyJson
  runtimeOwnerClaimOk <- runtimeOwnerClearRejectsRunningLease
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
      && observedDaemonFailureOk
      && preMergeHeadChangedOk
      && preMergeCleanOk
      && preMergeUnstableOk
      && automaticPlanningDryRunOk
      && automaticPlanningSnapshotOk
      && automaticPlanningClosedScopeOk
      && automaticPlanningIssueCreationOk
      && automaticPlanningGraphOk
      && automaticPlanningClosedDepsOk
      && automaticPlanningCanonicalCoverageOk
      && automaticExecutePrestartOk
      && automaticActiveTurnOk
      && automaticActiveTurnSystemErrorOk
      && automaticPlanWriteBeforeEventOk
      && automaticMissingPlanPreValidationOk
      && automaticImplementationHandoffOk
      && automaticIssueMergeClosedOk
      && automaticStaleTurnOk
      && automaticPrRetryOk
      && automaticUnlinkedPrOk
      && automaticNewPrBodyOk
      && automaticReusedPrBodyOk
      && automaticBodyThenImplementationOk
      && automaticMissingPlanBodyOk
      && automaticTerminalStopOk
      && automaticLoopLoggingOk
      && runnerGuardOk
      && runnerGuardRestartOk
      && runnerGuardWaitingRestartOk
      && runnerGuardRepairOk
      && runtimeStatusOk
      && runtimeOwnerLeaseOk
      && runtimeOwnerClaimOk
      && observeParsingOk
    then pure ()
    else exitFailure
