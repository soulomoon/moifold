{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
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
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop
import CodexWatcher.EffectInterpreter
import CodexWatcher.Effects
import CodexWatcher.EventLog
import CodexWatcher.EventLogRepair
import CodexWatcher.GhGit
import CodexWatcher.Healthcheck
import CodexWatcher.GoldenReplay
import CodexWatcher.IssueImplementWatcher
import CodexWatcher.IssuePlanningFanout
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.Migration
import CodexWatcher.MigrationRehearsal
import CodexWatcher.Protocol
import CodexWatcher.PrReviewWatcher
import CodexWatcher.Runtime
import CodexWatcher.RunnerGuard
import CodexWatcher.Snapshot
import CodexWatcher.StateMachine
import CodexWatcher.Supervisor
import CodexWatcher.TurnClassifier
import CodexWatcher.TurnOutput
import CodexWatcher.Types
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
import Data.IORef
import Data.List.NonEmpty (NonEmpty (..))
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, removePathForcibly)
import System.FilePath ((</>))
import System.Exit (exitFailure)
import Test.QuickCheck

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

effectIsMerge :: SomeEffect -> Bool
effectIsMerge = \case
  SomeEffect MergePullRequest {} -> True
  _ -> False

effectIsStartWorker :: SomeEffect -> Bool
effectIsStartWorker = \case
  SomeEffect StartWorkerTurn {} -> True
  _ -> False

effectIsStartIssueImplementation :: SomeEffect -> Bool
effectIsStartIssueImplementation = \case
  SomeEffect StartIssueImplementationWorkerTurn {} -> True
  _ -> False

effectIsStartPlanner :: SomeEffect -> Bool
effectIsStartPlanner = \case
  SomeEffect StartPlannerTurn {} -> True
  _ -> False

effectIsStartReviewer :: SomeEffect -> Bool
effectIsStartReviewer = \case
  SomeEffect StartReviewerTurn {} -> True
  _ -> False

effectIsCreatePr :: SomeEffect -> Bool
effectIsCreatePr = \case
  SomeEffect CreatePullRequest {} -> True
  _ -> False

effectIsCreateIssue :: SomeEffect -> Bool
effectIsCreateIssue = \case
  SomeEffect CreateIssue {} -> True
  _ -> False

effectIsRecordPlanningGraph :: SomeEffect -> Bool
effectIsRecordPlanningGraph = \case
  SomeEffect RecordPlanningGraph {} -> True
  _ -> False

effectIsPush :: SomeEffect -> Bool
effectIsPush = \case
  SomeEffect PushBranch {} -> True
  _ -> False

effectIsRecordBlocked :: SomeEffect -> Bool
effectIsRecordBlocked = \case
  SomeEffect RecordBlocked {} -> True
  _ -> False

prop_blockingNonTerminalRecordsReasonAndStops :: IssueConfig -> ThreadId -> BlockedReason -> Bool
prop_blockingNonTerminalRecordsReasonAndStops config threadId reason =
  case step (IssueNeedsTriage config (WorkerIdle threadId)) (MarkBlocked reason) of
    Decision state effects ->
      phaseOf state == Blocked
        && any effectIsRecordBlocked effects
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
        && any effectIsStartWorker effects
        && not (any effectIsMerge effects)

prop_noUnresolvedReviewsStartsReviewerOnly :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> ActiveTurn -> Bool
prop_noUnresolvedReviewsStartsReviewerOnly config workerThread reviewerThread commit activeTurn =
  case step (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) (NoReviewThreadsFound commit activeTurn) of
    Decision state effects ->
      phaseOf state == ReviewingClean
        && any effectIsStartReviewer effects
        && not (any effectIsStartWorker effects)
        && not (any effectIsMerge effects)

prop_cleanReviewIsRequiredToMerge :: PrConfig -> CommitSha -> ThreadId -> ActiveTurn -> CleanReviewEvidence -> Bool
prop_cleanReviewIsRequiredToMerge config commit workerThread reviewerActive cleanEvidence =
  case step (PrReviewingClean config commit (WorkerIdle workerThread) (ReviewerActive reviewerActive)) (ReviewerFoundClean cleanEvidence) of
    Decision state effects ->
      phaseOf state == Merging
        && any effectIsMerge effects

prop_issuePlanCompletionCreatesPrBeforeImplementation :: IssueConfig -> ActiveTurn -> ActiveTurn -> Bool
prop_issuePlanCompletionCreatesPrBeforeImplementation config planningTurn implementationTurn =
  case step (IssueInPlanMode config (WorkerActive planningTurn)) (IssuePlanCompleted (Just implementationTurn)) of
    Decision state effects ->
      phaseOf state == Implementing
        && any effectIsPush effects
        && any effectIsCreatePr effects
        && any effectIsStartIssueImplementation effects

prop_issueTriageAlreadyFixedCompletesWithoutPlan :: IssueConfig -> ActiveTurn -> Bool
prop_issueTriageAlreadyFixedCompletesWithoutPlan config triageTurn =
  case step (IssueTriageActive config (WorkerActive triageTurn)) IssueTriageAlreadyFixed of
    Decision state effects ->
      phaseOf state == Complete
        && not (any effectIsCreatePr effects)
        && not (any effectIsStartWorker effects)

prop_issueTriageNeedsImplementationWaitsForPlan :: IssueConfig -> ActiveTurn -> Bool
prop_issueTriageNeedsImplementationWaitsForPlan config triageTurn =
  case step (IssueTriageActive config (WorkerActive triageTurn)) IssueTriageNeedsImplementation of
    Decision state effects ->
      phaseOf state == PlanMode
        && not (any effectIsCreatePr effects)
        && not (any effectIsStartWorker effects)

prop_issuePlanCompletionWithoutImmediateTurnCreatesPrOnly :: IssueConfig -> ActiveTurn -> Bool
prop_issuePlanCompletionWithoutImmediateTurnCreatesPrOnly config planningTurn =
  case step (IssueInPlanMode config (WorkerActive planningTurn)) (IssuePlanCompleted Nothing) of
    Decision state effects ->
      phaseOf state == Implementing
        && any effectIsPush effects
        && any effectIsCreatePr effects
        && not (any effectIsStartWorker effects)

prop_issueImplementationIncompleteRestartsWorker :: IssueConfig -> PrNumber -> ActiveTurn -> Bool
prop_issueImplementationIncompleteRestartsWorker config prNumber activeTurn =
  case step (IssueImplementing config (Just prNumber) (WorkerActive activeTurn)) IssueImplementationIncomplete of
    Decision state effects ->
      phaseOf state == Implementing
        && any effectIsStartIssueImplementation effects
        && not (any effectIsRecordBlocked effects)

prop_issueImplementationBlockedStops :: IssueConfig -> PrNumber -> ActiveTurn -> BlockedReason -> Bool
prop_issueImplementationBlockedStops config prNumber activeTurn reason =
  case step (IssueImplementing config (Just prNumber) (WorkerActive activeTurn)) (MarkBlocked reason) of
    Decision state effects ->
      phaseOf state == Blocked
        && any effectIsRecordBlocked effects
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
        && any effectIsRecordPlanningGraph effects
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
  case replayEventLog
    [ PrReviewInitialized config workerThread reviewerThread
    , PrReviewUnresolvedFound reviewThreadIds reviewedCommit workerTurn
    , PrReviewFixCompleted
    , PrReviewNoUnresolvedFound (cleanReviewCommit cleanEvidence) reviewerTurn
    , PrReviewCleanFound cleanEvidence
    , PrReviewMergeCompleted mergeCommit
    ] of
    Right replay ->
      someDomain replay.replayState == PrReview
        && somePhase replay.replayState == Complete
    Left _ -> False

prop_eventLogCannotReviewCleanWhileFixing :: PrConfig -> ThreadId -> ThreadId -> NonEmpty ReviewThreadId -> CommitSha -> TurnId -> TurnId -> Bool
prop_eventLogCannotReviewCleanWhileFixing config workerThread reviewerThread reviewThreadIds reviewedCommit workerTurn reviewerTurn =
  case replayEventLog
    [ PrReviewInitialized config workerThread reviewerThread
    , PrReviewUnresolvedFound reviewThreadIds reviewedCommit workerTurn
    , PrReviewNoUnresolvedFound reviewedCommit reviewerTurn
    ] of
    Left _ -> True
    Right _ -> False

prop_eventLogCannotMergeBeforeCleanReview :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> MergeCommit -> Bool
prop_eventLogCannotMergeBeforeCleanReview config workerThread reviewerThread commit reviewerTurn mergeCommit =
  case replayEventLog
    [ PrReviewInitialized config workerThread reviewerThread
    , PrReviewNoUnresolvedFound commit reviewerTurn
    , PrReviewMergeCompleted mergeCommit
    ] of
    Left _ -> True
    Right _ -> False

prop_eventLogFullIssueImplementationPathCompletes :: IssueConfig -> ThreadId -> TurnId -> TurnId -> PrNumber -> Bool
prop_eventLogFullIssueImplementationPathCompletes config workerThread planTurn implementationTurn prNumber =
  case replayEventLog
    [ IssueImplementInitialized config workerThread
    , IssuePlanTurnStartedEvent planTurn
    , IssuePlanCompletedEvent (Just implementationTurn)
    , IssueImplementationCompletedEvent prNumber
    ] of
    Right replay ->
      someDomain replay.replayState == IssueImplement
        && somePhase replay.replayState == Complete
    Left _ -> False

prop_eventLogCannotCompleteIssueBeforePlanning :: IssueConfig -> ThreadId -> PrNumber -> Bool
prop_eventLogCannotCompleteIssueBeforePlanning config workerThread prNumber =
  case replayEventLog
    [ IssueImplementInitialized config workerThread
    , IssueImplementationCompletedEvent prNumber
    ] of
    Left _ -> True
    Right _ -> False

prop_eventLogCannotCreatePrBeforeIssuePlan :: IssueConfig -> ThreadId -> TurnId -> PrNumber -> Bool
prop_eventLogCannotCreatePrBeforeIssuePlan config workerThread triageTurn prNumber =
  case replayEventLog
    [ IssueImplementInitialized config workerThread
    , IssueTriageTurnStartedEvent triageTurn
    , IssueTriageNeedsImplementationEvent
    , IssuePullRequestCreatedEvent prNumber
    ] of
    Left _ -> True
    Right _ -> False

prop_eventLogCannotCompleteIssueBeforeImplementationTurn :: IssueConfig -> ThreadId -> TurnId -> PrNumber -> Bool
prop_eventLogCannotCompleteIssueBeforeImplementationTurn config workerThread planTurn prNumber =
  case replayEventLog
    [ IssueImplementInitialized config workerThread
    , IssuePlanTurnStartedEvent planTurn
    , IssuePlanCompletedEvent Nothing
    , IssuePullRequestCreatedEvent prNumber
    , IssueImplementationCompletedEvent prNumber
    ] of
    Left _ -> True
    Right _ -> False

prop_eventLogIssueAlreadyFixedCompletes :: IssueConfig -> ThreadId -> TurnId -> Bool
prop_eventLogIssueAlreadyFixedCompletes config workerThread triageTurn =
  case replayEventLog
    [ IssueImplementInitialized config workerThread
    , IssueTriageTurnStartedEvent triageTurn
    , IssueTriageAlreadyFixedEvent
    ] of
    Right replay ->
      someDomain replay.replayState == IssueImplement
        && somePhase replay.replayState == Complete
    Left _ -> False

prop_eventLogIssueIncompleteCanContinueToComplete :: IssueConfig -> ThreadId -> TurnId -> TurnId -> TurnId -> PrNumber -> Bool
prop_eventLogIssueIncompleteCanContinueToComplete config workerThread triageTurn planTurn firstImplementationTurn prNumber =
  let secondImplementationTurn = TurnId (unTurnId firstImplementationTurn <> "-next")
   in case replayEventLog
        [ IssueImplementInitialized config workerThread
        , IssueTriageTurnStartedEvent triageTurn
        , IssueTriageNeedsImplementationEvent
        , IssuePlanTurnStartedEvent planTurn
        , IssuePlanCompletedEvent Nothing
        , IssuePullRequestCreatedEvent prNumber
        , IssueImplementationTurnStartedEvent firstImplementationTurn
        , IssueImplementationIncompleteEvent "incomplete"
        , IssueImplementationTurnStartedEvent secondImplementationTurn
        , IssueReviewHandoffInitializedEvent prNumber
        , IssueReviewHandoffStartedEvent prNumber
        , IssueImplementationCompletedEvent prNumber
        ] of
        Right replay ->
          someDomain replay.replayState == IssueImplement
            && somePhase replay.replayState == Complete
        Left _ -> False

prop_issueImplementWatcherTriageNeedsImplementation :: IssueConfig -> ThreadId -> TurnId -> Bool
prop_issueImplementWatcherTriageNeedsImplementation config workerThread triageTurn =
  let state = SomeWatcherState (IssueTriageActive config (WorkerActive (ActiveTurn workerThread triageTurn)))
   in case issueImplementObserve state ObservedTriageNeedsImplementation of
        Right tick ->
          issueImplementTickEvent tick == IssueTriageNeedsImplementationEvent
            && somePhase tick.issueImplementTickState == PlanMode
            && not (any effectIsCreatePr tick.issueImplementTickEffects)
        Left _ -> False

prop_issueImplementWatcherPlanCompletionPublishesBeforeImplementation :: IssueConfig -> ThreadId -> TurnId -> TurnId -> Bool
prop_issueImplementWatcherPlanCompletionPublishesBeforeImplementation config workerThread planTurn implementationTurn =
  let state = SomeWatcherState (IssueInPlanMode config (WorkerActive (ActiveTurn workerThread planTurn)))
   in case issueImplementObserve state (ObservedPlanCompleted (Just implementationTurn)) of
        Right tick ->
          issueImplementTickEvent tick == IssuePlanCompletedEvent (Just implementationTurn)
            && somePhase tick.issueImplementTickState == Implementing
            && any effectIsPush tick.issueImplementTickEffects
            && any effectIsCreatePr tick.issueImplementTickEffects
            && any effectIsStartIssueImplementation tick.issueImplementTickEffects
        Left _ -> False

prop_issueImplementWatcherIncompleteRestartsImplementation :: IssueConfig -> PrNumber -> ThreadId -> TurnId -> Bool
prop_issueImplementWatcherIncompleteRestartsImplementation config prNumber workerThread implementationTurn =
  let state = SomeWatcherState (IssueImplementing config (Just prNumber) (WorkerActive (ActiveTurn workerThread implementationTurn)))
   in case issueImplementObserve state (ObservedImplementationIncomplete "incomplete") of
        Right tick ->
          issueImplementTickEvent tick == IssueImplementationIncompleteEvent "incomplete"
            && somePhase tick.issueImplementTickState == Implementing
            && any effectIsStartIssueImplementation tick.issueImplementTickEffects
        Left _ -> False

prop_issueImplementWatcherRejectsCompletionBeforeImplementationTurn :: IssueConfig -> PrNumber -> ThreadId -> Bool
prop_issueImplementWatcherRejectsCompletionBeforeImplementationTurn config prNumber workerThread =
  let state = SomeWatcherState (IssueImplementationReady config (Just prNumber) (WorkerIdle workerThread))
   in case issueImplementObserve state (ObservedImplementationCompleted prNumber) of
        Left _ -> True
        Right _ -> False

prop_issueImplementWatcherBlockedStops :: IssueConfig -> PrNumber -> ThreadId -> TurnId -> BlockedReason -> Bool
prop_issueImplementWatcherBlockedStops config prNumber workerThread implementationTurn reason =
  let state = SomeWatcherState (IssueImplementing config (Just prNumber) (WorkerActive (ActiveTurn workerThread implementationTurn)))
   in case issueImplementObserve state (ObservedImplementationBlocked reason) of
        Right tick ->
          issueImplementTickEvent tick == IssueImplementationBlockedEvent reason
            && somePhase tick.issueImplementTickState == Blocked
            && any effectIsRecordBlocked tick.issueImplementTickEffects
            && SomeEffect StopDaemon `elem` tick.issueImplementTickEffects
        Left _ -> False

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

prop_eventLogIssuePlanningGraphWaitsForReadyIssues :: PlannerConfig -> ThreadId -> TurnId -> PlanningGraph -> Bool
prop_eventLogIssuePlanningGraphWaitsForReadyIssues config plannerThread plannerTurn graph =
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
            any effectIsRecordPlanningGraph graphEffects
              && SomeEffect SleepUntilNextPoll `elem` graphEffects
              && not (SomeEffect StopDaemon `elem` graphEffects)
          _ -> False
    Left _ -> False

prop_eventLogIssuePlanningReadyIssuesFixedReentersPlanning :: PlannerConfig -> ThreadId -> TurnId -> PlanningGraph -> Bool
prop_eventLogIssuePlanningReadyIssuesFixedReentersPlanning config plannerThread plannerTurn graph =
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
                && any effectIsStartPlanner started.issuePlanningTickEffects
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
                && any effectIsCreateIssue requested.issuePlanningTickEffects
                && issuePlanningTickEffects requested == [SomeEffect (CreateIssue (plannerRepo config) request), SomeEffect SleepUntilNextPoll]
            Left _ -> False
        Left _ -> False

prop_issuePlanningWatcherRecordsGraphBeforeFanoutAndWaits :: PlannerConfig -> ThreadId -> TurnId -> PlanningGraph -> Bool
prop_issuePlanningWatcherRecordsGraphBeforeFanoutAndWaits config threadId turnId graph =
  let ready = SomeWatcherState (PlanningReady config)
   in case issuePlanningObserve ready (ObservedPlanningTurnStarted threadId turnId) of
        Right started ->
          case issuePlanningObserve started.issuePlanningTickState (ObservedPlanningGraphUpdated graph) of
            Right graphed ->
              issuePlanningTickEvent graphed == IssuePlanningGraphUpdated graph
                && somePhase graphed.issuePlanningTickState == Initialized
                && any effectIsRecordPlanningGraph graphed.issuePlanningTickEffects
                && SomeEffect SleepUntilNextPoll `elem` graphed.issuePlanningTickEffects
                && case issuePlanningObserve graphed.issuePlanningTickState ObservedPlanningReadyIssuesFixed of
                  Right fixed ->
                    issuePlanningTickEvent fixed == IssuePlanningReadyIssuesFixed
                      && somePhase fixed.issuePlanningTickState == Initialized
                  Left _ -> False
            Left _ -> False
        Left _ -> False

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
      issueState = SomeWatcherState (IssueNeedsTriage (IssueConfig (RepoName "owner/name") (IssueNumber 42) (BranchName "codex/issue-42")) (WorkerIdle (ThreadId "worker-thread")))
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
  , PrReviewProblemsAdded commit
  , PrReviewReviewIncomplete "reviewer state missing required fields"
  , PrReviewMergeCompleted mergeCommit
  , IssueImplementInitialized issueConfig workerThread
  , IssueTriageTurnStartedEvent triageTurn
  , IssueTriageAlreadyFixedEvent
  , IssueTriageNeedsImplementationEvent
  , IssueTriageBlockedEvent blockedReason
  , IssuePlanTurnStartedEvent plannerTurn
  , IssuePlanCompletedEvent Nothing
  , IssuePlanCompletedEvent (Just implementationTurn)
  , IssuePullRequestCreatedEvent prNumber
  , IssuePullRequestReusedEvent prNumber
  , IssueImplementationTurnStartedEvent implementationTurn
  , IssueImplementationIncompleteEvent "implementation incomplete"
  , IssueImplementationBlockedEvent blockedReason
  , IssueReviewHandoffInitializedEvent prNumber
  , IssueReviewHandoffStartedEvent prNumber
  , IssueImplementationCompletedEvent prNumber
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
  triageTurn = TurnId "turn-triage"
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
        , IssueTriageTurnStartedEvent (TurnId "019db372-35d2-79e0-aac2-a50b23a3ef26")
        , IssueTriageNeedsImplementationEvent
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
                  SomeWatcherState (IssueImplementationReady _ (Just repairedPr) (WorkerIdle repairedThread)) ->
                    repairedPr == prNumber' && repairedThread == workerThread
                  _ -> False
              Left _ -> False
 where
  isRecovery = \case
    WatcherRecoveredInvalidState {} -> True
    _ -> False

prop_eventLogRepairCompletionWithoutImplementationTurnDropsComplete :: Bool
prop_eventLogRepairCompletionWithoutImplementationTurnDropsComplete =
  let issueConfig = IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")
      workerThread = ThreadId "worker-thread"
      prNumber' = PrNumber 7
      invalidEvents =
        [ IssueImplementInitialized issueConfig workerThread
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        , IssuePlanCompletedEvent Nothing
        , IssuePullRequestCreatedEvent prNumber'
        , IssueImplementationCompletedEvent prNumber'
        ]
   in case repairIssueImplementEventLog invalidEvents of
        Left _ -> False
        Right plan ->
          IssueImplementationCompletedEvent prNumber' `elem` plan.repairDroppedEvents
            && case replayEventLog plan.repairRepairedEvents of
              Right replay -> somePhase replay.replayState == Implementing
              Left _ -> False

prop_eventLogRepairRejectsValidEventLog :: IssueConfig -> ThreadId -> TurnId -> TurnId -> PrNumber -> Bool
prop_eventLogRepairRejectsValidEventLog config workerThread planTurn implementationTurn prNumber' =
  case repairIssueImplementEventLog
    [ IssueImplementInitialized config workerThread
    , IssuePlanTurnStartedEvent planTurn
    , IssuePlanCompletedEvent Nothing
    , IssuePullRequestCreatedEvent prNumber'
    , IssueImplementationTurnStartedEvent implementationTurn
    , IssueImplementationCompletedEvent prNumber'
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

prop_protocolPrReviewReviewerCleanMovesToMerging :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> CleanReviewEvidence -> Bool
prop_protocolPrReviewReviewerCleanMovesToMerging config workerThread reviewerThread reviewTarget reviewerTurn cleanEvidence =
  let session = newPrReviewReviewerSession config reviewerThread reviewTarget
      (_finished, events) = runPrReviewReviewerProtocol reviewerTurn (ReviewerClean cleanEvidence) session
   in case replayEventLog (PrReviewInitialized config workerThread reviewerThread : events) of
        Right replay ->
          someDomain replay.replayState == PrReview
            && somePhase replay.replayState == Merging
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
      events = PrReviewInitialized config workerThread reviewerThread : workerEvents <> reviewerEvents <> [PrReviewMergeCompleted mergeCommit]
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
            && any effectIsStartWorker tick.prReviewTickEffects
        Left _ -> False

prop_prReviewWatcherCleanStartsReviewer :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> Bool
prop_prReviewWatcherCleanStartsReviewer config workerThread reviewerThread commit turnId =
  let state = SomeWatcherState (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      observation = ObservedReviewThreads (reviewThreadsReport []) commit turnId
   in case prReviewObserve state observation of
        Right tick ->
          prReviewTickEvent tick == PrReviewNoUnresolvedFound commit turnId
            && somePhase tick.prReviewTickState == ReviewingClean
            && any effectIsStartReviewer tick.prReviewTickEffects
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
            && not (any effectIsMerge tick.prReviewTickEffects)
        Left _ -> False

prop_prReviewWatcherCleanReviewerMovesToMerging :: PrConfig -> ThreadId -> ThreadId -> CommitSha -> TurnId -> CleanReviewEvidence -> Bool
prop_prReviewWatcherCleanReviewerMovesToMerging config workerThread reviewerThread commit turnId evidence =
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
            && somePhase tick.prReviewTickState == Merging
            && any effectIsMerge tick.prReviewTickEffects
        Left _ -> False

runtimeCommandExamples :: [RuntimeCommand]
runtimeCommandExamples =
  [ CommandVersion "git"
  , GhAuthStatus
  , GhApiUser
  , GhIssueListOpen (RepoName "soulomoon/mlf2")
  , GhIssueCreate (RepoName "soulomoon/mlf2") (IssueCreationRequest "Subissue title" "Subissue body" Nothing)
  , GhPrListOpen (RepoName "soulomoon/mlf2")
  , GhPrView (RepoName "soulomoon/mlf2") (PrNumber 6) ["state", "url"]
  , GhReviewThreads (PrConfig (RepoName "soulomoon/mlf2") (PrNumber 6) (BranchName "codex/example"))
  , GhCreatePullRequest (IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/example"))
  , GhResolveReviewThread (ReviewThreadId "PRRT_test")
  , GhPrMerge (RepoName "soulomoon/mlf2") (PrNumber 6) "merge"
  , GitBranchCurrent "/tmp/work"
  , GitRevParseHead "/tmp/work"
  , GitStatusPorcelain "/tmp/work"
  , GitLsRemoteBranch "/tmp/work" (BranchName "codex/example")
  , GitPushDryRun "/tmp/work" (BranchName "codex/example")
  , GitPush "/tmp/work" (BranchName "codex/example")
  , KillZero "123"
  , RawCommand "cabal" ["--version"] Nothing
  ]

prop_runtimeCommandSpecsHaveExecutable :: Bool
prop_runtimeCommandSpecsHaveExecutable =
  all (not . null . (.command) . renderRuntimeCommand) runtimeCommandExamples

prop_runtimeGitPushDryRunNeverForces :: BranchName -> Bool
prop_runtimeGitPushDryRunNeverForces branch =
  let spec = renderRuntimeCommand (GitPushDryRun "/tmp/work" branch)
   in spec.command == "git"
        && spec.cwd == Just "/tmp/work"
        && "--dry-run" `elem` spec.args
        && "--force" `notElem` spec.args
        && "--force-with-lease" `notElem` spec.args

prop_runtimeGitPushNeverForces :: BranchName -> Bool
prop_runtimeGitPushNeverForces branch =
  let spec = renderRuntimeCommand (GitPush "/tmp/work" branch)
   in spec.command == "git"
        && spec.cwd == Just "/tmp/work"
        && spec.args == ["push", "origin", Text.unpack (unBranchName branch)]
        && "--force" `notElem` spec.args
        && "--force-with-lease" `notElem` spec.args

prop_runtimeGhPrViewUsesStructuredFields :: RepoName -> PrNumber -> Bool
prop_runtimeGhPrViewUsesStructuredFields repo prNumber =
  let spec = renderRuntimeCommand (GhPrView repo prNumber ["state", "url", "headRefOid"])
   in spec.command == "gh"
        && spec.args
          == [ "pr"
             , "view"
             , show (unPrNumber prNumber)
             , "--repo"
             , Text.unpack (unRepoName repo)
             , "--json"
             , "state,url,headRefOid"
             ]

prop_runtimeGhIssueCreateUsesRepoTitleAndBody :: RepoName -> IssueCreationRequest -> Bool
prop_runtimeGhIssueCreateUsesRepoTitleAndBody repo requestWithMaybeParent =
  let request = requestWithMaybeParent {issueCreationParent = Nothing}
      spec = renderRuntimeCommand (GhIssueCreate repo request)
   in spec.command == "gh"
        && spec.args
          == [ "issue"
             , "create"
             , "--repo"
             , Text.unpack (unRepoName repo)
             , "--title"
             , Text.unpack (issueCreationTitle request)
             , "--body"
             , Text.unpack (issueCreationBody request)
             ]

prop_runtimeGhIssueCreateWithParentLinksSubIssue :: RepoName -> IssueCreationRequest -> IssueNumber -> Bool
prop_runtimeGhIssueCreateWithParentLinksSubIssue repo requestWithoutParent parentIssue =
  let request = requestWithoutParent {issueCreationParent = Just parentIssue}
      spec = renderRuntimeCommand (GhIssueCreate repo request)
      script = Text.pack (spec.args !! 1)
   in spec.command == "bash"
        && take 2 spec.args == ["-lc", Text.unpack script]
        && "sub_issues" `Text.isInfixOf` script
        && "sub_issue_id" `Text.isInfixOf` script
        && "-F \"sub_issue_id=$sub_issue_id\"" `Text.isInfixOf` script
        && spec.args
          == [ "-lc"
             , Text.unpack script
             , "codex-watcher-gh-sub-issue-create"
             , Text.unpack (unRepoName repo)
             , Text.unpack (issueCreationTitle request)
             , Text.unpack (issueCreationBody request)
             , show (unIssueNumber parentIssue)
             ]

prop_runtimeKillZeroOnlyChecksPid :: ThreadId -> Bool
prop_runtimeKillZeroOnlyChecksPid threadId =
  let pidText = unThreadId threadId
      spec = renderRuntimeCommand (KillZero pidText)
      termSpec = renderRuntimeCommand (KillTerm pidText)
   in spec.command == "kill"
        && spec.args == ["-0", Text.unpack pidText]
        && spec.cwd == Nothing
        && termSpec.command == "kill"
        && termSpec.args == ["-TERM", Text.unpack pidText]
        && termSpec.cwd == Nothing

jsonText :: Value -> Text
jsonText =
  Text.Encoding.decodeUtf8 . LazyByteString.toStrict . encode

prop_ghGitParsesIssueAndPrLists :: Bool
prop_ghGitParsesIssueAndPrLists =
  let issuesJson =
        jsonText
          (toJSON [object ["number" .= (42 :: Int), "title" .= ("Fix bug" :: Text)]])
      prsJson =
        jsonText
          ( toJSON
              [ object
                  [ "number" .= (7 :: Int)
                  , "title" .= ("Implement fix" :: Text)
                  , "headRefName" .= ("codex/issue-42" :: Text)
                  , "headRefOid" .= ("abc123" :: Text)
                  ]
              ]
          )
   in parseGhIssueList issuesJson == Right [GhIssue (IssueNumber 42) "Fix bug"]
        && parseGhPrList prsJson == Right [GhPullRequest (PrNumber 7) "Implement fix" (BranchName "codex/issue-42") (Just (CommitSha "abc123"))]

prop_ghGitParsesRemotePrView :: Bool
prop_ghGitParsesRemotePrView =
  let prJson =
        jsonText
          ( object
              [ "state" .= ("MERGED" :: Text)
              , "url" .= ("https://github.com/owner/name/pull/7" :: Text)
              , "headRefOid" .= ("head-sha" :: Text)
              , "mergeCommit" .= object ["oid" .= ("merge-sha" :: Text)]
              , "mergedAt" .= ("2026-04-21T00:00:00Z" :: Text)
              ]
          )
   in parseGhPrView prJson
        == Right
          RemotePullRequest
            { remotePullRequestState = "MERGED"
            , remotePullRequestUrl = Just "https://github.com/owner/name/pull/7"
            , remotePullRequestHeadRefOid = Just (CommitSha "head-sha")
            , remotePullRequestMergeCommit = Just (CommitSha "merge-sha")
            , remotePullRequestMergedAt = Just "2026-04-21T00:00:00Z"
            }

prop_ghGitParsesReviewThreadsGraphql :: Bool
prop_ghGitParsesReviewThreadsGraphql =
  let payload =
        jsonText
          ( object
              [ "data"
                  .= object
                    [ "repository"
                        .= object
                          [ "pullRequest"
                              .= object
                                [ "reviewThreads"
                                    .= object
                                      [ "nodes"
                                          .= [ object
                                                [ "id" .= ("thread-unresolved" :: Text)
                                                , "isResolved" .= False
                                                , "isOutdated" .= False
                                                , "path" .= ("src/File.hs" :: Text)
                                                , "line" .= (12 :: Int)
                                                , "startLine" .= (10 :: Int)
                                                , "comments"
                                                    .= object
                                                      [ "nodes"
                                                          .= [ object
                                                                [ "id" .= ("comment-1" :: Text)
                                                                , "body" .= ("please fix" :: Text)
                                                                , "author" .= object ["login" .= ("reviewer" :: Text)]
                                                                ]
                                                              ]
                                                         ]
                                                ]
                                             , object
                                                [ "id" .= ("thread-resolved" :: Text)
                                                , "isResolved" .= True
                                                , "isOutdated" .= False
                                                , "comments" .= object ["nodes" .= ([] :: [Value])]
                                                ]
                                             ]
                                      ]
                                ]
                          ]
                    ]
              ]
          )
   in case parseGhReviewThreads payload of
        Right report ->
          fmap reviewThreadId report.unresolvedReviewThreads == [ReviewThreadId "thread-unresolved"]
            && length report.reviewThreads == 2
            && maybe False ((== Just "reviewer") . reviewCommentAuthorLogin) (listToMaybe report.reviewThreads >>= listToMaybe . reviewThreadComments)
        Left _ -> False

prop_ghGitParsesGitOutputs :: Bool
prop_ghGitParsesGitOutputs =
  parseGitBranch "codex/example\n" == Just (BranchName "codex/example")
    && parseGitSha "abc123\n" == Just (CommitSha "abc123")
    && parseLsRemoteBranch "abc123\trefs/heads/codex/example\n" == Just (CommitSha "abc123")
    && parseGitBranch "\n" == Nothing

prop_appServerInitializeRequestMatchesJsonRpc :: Bool
prop_appServerInitializeRequestMatchesJsonRpc =
  toJSON (initializeRequest 1 "codex-script" "0.1.0")
    == object
      [ "jsonrpc" .= ("2.0" :: Text)
      , "id" .= (1 :: Int)
      , "method" .= ("initialize" :: Text)
      , "params" .= object
          [ "clientInfo" .= object ["name" .= ("codex-script" :: Text), "version" .= ("0.1.0" :: Text)]
          , "capabilities" .= object ["experimentalApi" .= True]
          ]
      ]

prop_appServerThreadStartKeepsNodeNullFields :: Bool
prop_appServerThreadStartKeepsNodeNullFields =
  let request =
        threadStartRequest
          2
          ThreadStartOptions
            { threadCwd = "/workspace/repo"
            , threadApprovalPolicy = "never"
            , threadSandbox = "danger-full-access"
            , threadModel = "gpt-5.4"
            , threadDeveloperInstructions = "developer"
            }
   in request.requestMethod == "thread/start"
        && all
          (\key -> lookupValue key request.requestParams == Just Null)
          ["modelProvider", "baseInstructions", "config", "personality", "serviceTier", "serviceName"]
        && lookupValue "ephemeral" request.requestParams == Just (Bool False)

prop_appServerTurnStartPlanModeEncodesCollaborationMode :: ThreadId -> Bool
prop_appServerTurnStartPlanModeEncodesCollaborationMode threadId =
  let collaborationMode = planCollaborationMode "plan only" "gpt-5.4" "xhigh"
      request =
        turnStartRequest
          3
          TurnStartOptions
            { turnThreadId = threadId
            , turnCwd = "/workspace/repo"
            , turnEffort = "xhigh"
            , turnModel = "gpt-5.4"
            , turnApprovalPolicy = "never"
            , turnSandboxPolicy = "danger-full-access"
            , turnInput = "write the plan"
            , turnOutputSchema = Just structuredTurnOutputSchema
            , turnCollaborationMode = Just collaborationMode
            }
   in request.requestMethod == "turn/start"
        && lookupValue "threadId" request.requestParams == Just (String (unThreadId threadId))
        && lookupValue "collaborationMode" request.requestParams == Just collaborationMode
        && lookupValue "sandboxPolicy" request.requestParams == Just (object ["type" .= ("dangerFullAccess" :: Text)])
        && lookupValue "summary" request.requestParams == Just Null
        && lookupValue "input" request.requestParams == Just (toJSON [object ["type" .= ("text" :: Text), "text" .= ("write the plan" :: Text)]])
        && lookupValue "outputSchema" request.requestParams == Just structuredTurnOutputSchema

prop_appServerThreadReadAndInterruptUseThreadIds :: ThreadId -> TurnId -> Bool
prop_appServerThreadReadAndInterruptUseThreadIds threadId turnId =
  let readRequest = threadReadRequest 4 threadId True
      interruptRequest = turnInterruptRequest 5 threadId turnId
   in readRequest.requestMethod == "thread/read"
        && lookupValue "threadId" readRequest.requestParams == Just (String (unThreadId threadId))
        && lookupValue "includeTurns" readRequest.requestParams == Just (Bool True)
        && interruptRequest.requestMethod == "turn/interrupt"
        && lookupValue "threadId" interruptRequest.requestParams == Just (String (unThreadId threadId))
        && lookupValue "turnId" interruptRequest.requestParams == Just (String (unTurnId turnId))

prop_appServerClientInitializesSingleRequestSessions :: ThreadId -> Bool
prop_appServerClientInitializesSingleRequestSessions threadId =
  let request = threadReadRequest 4 threadId True
      session = appServerRequestSession request
   in fmap requestMethod session == ["initialize", "thread/read"]
        && fmap requestId session == [0, 4]
        && appServerRequestSession (initializeRequest 10 "client" "1") == [initializeRequest 10 "client" "1"]

prop_appServerClientMatchesSuccessResponse :: Bool
prop_appServerClientMatchesSuccessResponse =
  let request = initializeRequest 80 "codex-watcher-hs" "0.1.0"
      result = object ["server" .= ("ready" :: Text)]
      response = object ["jsonrpc" .= ("2.0" :: Text), "id" .= (80 :: Int), "result" .= result]
   in case decodeAppServerIncomingValue response >>= matchAppServerIncoming request of
        Right (Just value) -> value == result
        _ -> False

prop_appServerClientSkipsNotifications :: Bool
prop_appServerClientSkipsNotifications =
  let request = initializeRequest 81 "codex-watcher-hs" "0.1.0"
      notification = object ["jsonrpc" .= ("2.0" :: Text), "method" .= ("turn/update" :: Text), "params" .= object ["status" .= ("running" :: Text)]]
   in case decodeAppServerIncomingValue notification >>= matchAppServerIncoming request of
        Right Nothing -> True
        _ -> False

prop_appServerClientRejectsMismatchedResponseIds :: Bool
prop_appServerClientRejectsMismatchedResponseIds =
  let request = initializeRequest 82 "codex-watcher-hs" "0.1.0"
      response = object ["jsonrpc" .= ("2.0" :: Text), "id" .= (83 :: Int), "result" .= object []]
   in case decodeAppServerIncomingValue response >>= matchAppServerIncoming request of
        Left (AppServerResponseIdMismatch 82 83) -> True
        _ -> False

prop_appServerClientSurfacesJsonRpcErrors :: Bool
prop_appServerClientSurfacesJsonRpcErrors =
  let request = initializeRequest 84 "codex-watcher-hs" "0.1.0"
      response =
        object
          [ "jsonrpc" .= ("2.0" :: Text)
          , "id" .= (84 :: Int)
          , "error" .= object ["code" .= (-32000 :: Int), "message" .= ("boom" :: Text)]
          ]
   in case decodeAppServerIncomingValue response >>= matchAppServerIncoming request of
        Left (AppServerJsonRpcFailure 84 errorValue) ->
          jsonRpcErrorCode errorValue == -32000 && jsonRpcErrorMessage errorValue == "boom"
        _ -> False

prop_appServerClientFallsBackForUnmaterializedThreadRead :: ThreadId -> Bool
prop_appServerClientFallsBackForUnmaterializedThreadRead threadId =
  let request = threadReadRequest 86 threadId True
      failure =
        AppServerJsonRpcFailure
          86
          JsonRpcError
            { jsonRpcErrorCode = -32000
            , jsonRpcErrorMessage = "thread " <> unThreadId threadId <> " is not materialized yet; includeTurns is unavailable before first user message"
            , jsonRpcErrorData = Nothing
            }
      nonThreadRequest = initializeRequest 86 "codex-watcher-hs" "0.1.0"
   in threadReadBeforeMaterializedFallback request failure == Just (object ["turns" .= ([] :: [Value])])
        && threadReadBeforeMaterializedFallback nonThreadRequest failure == Nothing

prop_appServerClientRejectsUnsupportedJsonRpcVersion :: Bool
prop_appServerClientRejectsUnsupportedJsonRpcVersion =
  let response = object ["jsonrpc" .= ("1.0" :: Text), "id" .= (85 :: Int), "result" .= object []]
   in case decodeAppServerIncomingValue response of
        Left AppServerDecodeFailure {} -> True
        _ -> False

prop_appServerClientParsesThreadReadTurns :: Bool
prop_appServerClientParsesThreadReadTurns =
  let response =
        object
          [ "turns"
              .= [ object
                    [ "id" .= ("turn-old" :: Text)
                    , "status" .= ("completed" :: Text)
                    , "output" .= ("old output" :: Text)
                    ]
                 , object
                    [ "turnId" .= ("turn-target" :: Text)
                    , "status" .= ("running" :: Text)
                    , "result" .= object ["text" .= ("target output" :: Text)]
                    ]
                 , object
                    [ "turnId" .= ("turn-target" :: Text)
                    , "status" .= ("completed" :: Text)
                    , "result" .= object ["text" .= ("latest output" :: Text)]
                    ]
                 , object
                    [ "turnId" .= ("turn-structured" :: Text)
                    , "status" .= ("completed" :: Text)
                    , "output" .= object ["outcome" .= ("blocked" :: Text), "reason" .= ("schema blocker" :: Text)]
                    ]
                 , object
                    [ "id" .= ("turn-agent-item" :: Text)
                    , "status" .= ("completed" :: Text)
                    , "items"
                        .= [ object
                              [ "type" .= ("userMessage" :: Text)
                              , "content" .= [object ["type" .= ("text" :: Text), "text" .= ("prompt" :: Text)]]
                              ]
                           , object
                              [ "type" .= ("agentMessage" :: Text)
                              , "phase" .= ("final_answer" :: Text)
                              , "text" .= ("{\"outcome\":\"complete\",\"summary\":\"ok\"}" :: Text)
                              ]
                           ]
                    ]
                 ]
          ]
   in case parseThreadReadTurns response of
        Right turns ->
          latestTurnById (TurnId "turn-target") turns
            == Just (AppServerTurn (TurnId "turn-target") "completed" (Just "latest output"))
            && ( (parseStructuredTurnOutcome =<< (appServerTurnOutput =<< latestTurnById (TurnId "turn-structured") turns))
                   == Just (StructuredBlocked "schema blocker")
               )
            && ( (parseStructuredTurnOutcome =<< (appServerTurnOutput =<< latestTurnById (TurnId "turn-agent-item") turns))
                   == Just (StructuredComplete "ok")
               )
        Left _ -> False

prop_appServerClientParsesTurnStartTurnId :: Bool
prop_appServerClientParsesTurnStartTurnId =
  parseTurnStartTurnId (object ["turn" .= object ["id" .= ("turn-created" :: Text)]])
    == Right (TurnId "turn-created")

prop_appServerClientParsesThreadStartThreadId :: Bool
prop_appServerClientParsesThreadStartThreadId =
  parseThreadStartThreadId (object ["thread" .= object ["id" .= ("thread-created" :: Text)]])
    == Right (ThreadId "thread-created")

prop_appServerClientParsesNestedThreadReadTurns :: Bool
prop_appServerClientParsesNestedThreadReadTurns =
  parseThreadReadTurns
    ( object
        [ "thread"
            .= object
              [ "turns"
                  .= [ object
                        [ "id" .= ("turn-nested" :: Text)
                        , "status" .= ("completed" :: Text)
                        ]
                     ]
              ]
        ]
    )
    == Right [AppServerTurn (TurnId "turn-nested") "completed" Nothing]

prop_turnClassifierCompletionStates :: Bool
prop_turnClassifierCompletionStates =
  classifyTurnCompletion (AppServerTurn (TurnId "running") "running" Nothing) == TurnStillRunning
    && classifyTurnCompletion (AppServerTurn (TurnId "done") "completed" (Just "complete")) == TurnCompleted (Just "complete")
    && classifyTurnCompletion (AppServerTurn (TurnId "failed") "failed" (Just "blocked by CI")) == TurnFailed "blocked by CI"

prop_turnClassifierMapsDomainOutputs :: Bool
prop_turnClassifierMapsDomainOutputs =
  classifyIssuePlanningTurn (AppServerTurn (TurnId "planning") "completed" (Just "stable issue set")) == Just ObservedPlanningTurnCompleted
    && classifyIssueTriageTurn (AppServerTurn (TurnId "triage") "completed" (Just "already fixed")) == Just ObservedTriageAlreadyFixed
    && classifyIssuePlanTurn (AppServerTurn (TurnId "plan") "completed" (Just "plan written")) == Just (ObservedPlanCompleted Nothing)
    && classifyIssueImplementationTurn (Just (PrNumber 7)) (AppServerTurn (TurnId "impl") "completed" (Just "ready for review")) == Just (ObservedImplementationCompleted (PrNumber 7))
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker") "completed" (Just "resolved")) == Just (ObservedWorkerOutcome WorkerCompleted)
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer") "completed" (Just "LGTM clean")) == Just (ObservedReviewerOutcome (ReviewerClean (CleanReviewEvidence (CommitSha "abc123") "LGTM clean")))

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
    && classifyIssueTriageTurn (AppServerTurn (TurnId "triage") "completed" (Just "{\"outcome\":\"already_fixed\",\"reason\":\"schema fixed\"}")) == Just ObservedTriageAlreadyFixed
    && classifyIssueImplementationTurn (Just (PrNumber 7)) (AppServerTurn (TurnId "impl") "completed" (Just "{\"outcome\":\"complete\",\"summary\":\"ready\"}")) == Just (ObservedImplementationCompleted (PrNumber 7))
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker") "completed" (Just "{\"status\":\"incomplete\",\"reason\":\"tests still failing\"}")) == Just (ObservedWorkerOutcome (WorkerIncomplete "tests still failing"))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer") "completed" (Just "{\"result\":\"clean\",\"comment\":\"schema LGTM\"}")) == Just (ObservedReviewerOutcome (ReviewerClean (CleanReviewEvidence (CommitSha "abc123") "schema LGTM")))

prop_turnClassifierBlocksMissingOutputs :: Bool
prop_turnClassifierBlocksMissingOutputs =
  classifyIssuePlanningTurn (AppServerTurn (TurnId "planning") "completed" Nothing) == Just (ObservedPlanningBlocked (BlockedReason "planning turn completed without output"))
    && classifyIssueTriageTurn (AppServerTurn (TurnId "triage") "completed" (Just "  ")) == Just (ObservedIssueImplementBlocked (BlockedReason "triage turn completed without output"))
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
    , effectRuntimePlannerTurn = turnRuntime "planner prompt" Nothing
    , effectRuntimeWorkerTurn = turnRuntime "worker prompt" Nothing
    , effectRuntimeIssueTriageTurn = turnRuntime "issue triage prompt" Nothing
    , effectRuntimeIssuePlanTurn = turnRuntime "issue plan prompt" (Just (planCollaborationMode "issue plan mode" "gpt-5.4" "xhigh"))
    , effectRuntimeIssueImplementationTurn = turnRuntime "issue implementation prompt" Nothing
    , effectRuntimeReviewerTurn = turnRuntime "reviewer prompt" Nothing
    }
 where
  turnRuntime input collaborationMode =
    TurnRuntimeConfig
      { turnRuntimeCwd = workdir
      , turnRuntimeModel = "gpt-5.4"
      , turnRuntimeEffort = "xhigh"
      , turnRuntimeApprovalPolicy = "never"
      , turnRuntimeSandboxPolicy = "danger-full-access"
      , turnRuntimeInput = input
      , turnRuntimeOutputSchema = Nothing
      , turnRuntimeCollaborationMode = collaborationMode
      }

actionIsCommand :: (RuntimeCommand -> Bool) -> PlannedAction -> Bool
actionIsCommand predicate = \case
  PlannedCommand command -> predicate command
  _ -> False

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

prop_effectInterpreterIssuePlanCompletionOrdersPublishBeforeWorker :: IssueConfig -> ActiveTurn -> ActiveTurn -> Bool
prop_effectInterpreterIssuePlanCompletionOrdersPublishBeforeWorker config planningTurn implementationTurn =
  case step (IssueInPlanMode config (WorkerActive planningTurn)) (IssuePlanCompleted (Just implementationTurn)) of
    Decision _state effects ->
      let compiled =
            compileEffectPlan
              (effectRuntimeConfig (issueRepo config) "/tmp/work" 10)
              effects
          actions = compiled.compiledActions
       in length actions == 3
            && actionIsCommand (== GitPush "/tmp/work" (issueBranch config)) (actions !! 0)
            && actionIsCommand (== GhCreatePullRequest config) (actions !! 1)
            && actionIsTurnStartWithInput (activeThreadId implementationTurn) "issue implementation prompt" (actions !! 2)
            && compiled.compiledNextRequestId == 11

prop_effectInterpreterIssueTurnsUsePhaseSpecificPrompts :: ThreadId -> Bool
prop_effectInterpreterIssueTurnsUsePhaseSpecificPrompts threadId =
  let compiled =
        compileEffectPlan
          (effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 16)
          [ SomeEffect (StartIssueTriageWorkerTurn threadId)
          , SomeEffect (StartIssuePlanWorkerTurn threadId)
          , SomeEffect (StartIssueImplementationWorkerTurn threadId)
          , SomeEffect (StartWorkerTurn threadId)
          ]
      actions = compiled.compiledActions
   in length actions == 4
        && actionIsTurnStartWithInput threadId "issue triage prompt" (actions !! 0)
        && actionIsTurnStartWithInput threadId "issue plan prompt" (actions !! 1)
        && actionIsTurnStartWithInput threadId "issue implementation prompt" (actions !! 2)
        && actionIsTurnStartWithInput threadId "worker prompt" (actions !! 3)
        && compiled.compiledNextRequestId == 20

prop_effectInterpreterTwoTurnStartsUseMonotonicRequestIds :: ThreadId -> ThreadId -> Bool
prop_effectInterpreterTwoTurnStartsUseMonotonicRequestIds workerThread reviewerThread =
  let compiled =
        compileEffectPlan
          (effectRuntimeConfig (RepoName "soulomoon/mlf2") "/tmp/work" 20)
          [ SomeEffect (StartWorkerTurn workerThread)
          , SomeEffect (StartReviewerTurn reviewerThread)
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
   in compiled.compiledActions == [PlannedCommand (GhPrMerge repo prNumber "squash")]

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

prop_migrationRuntimeOwnerJsonAndParsing :: Bool
prop_migrationRuntimeOwnerJsonAndParsing =
  parseRuntimeOwner "node" == Right NodeRuntime
    && parseRuntimeOwner "HASKELL" == Right HaskellRuntime
    && parseRuntimeOwner "unknown" /= Right NodeRuntime
    && runtimeOwnerJson HaskellRuntime == object ["owner" .= ("haskell" :: Text)]

prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork :: Bool
prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork =
  warnIssueImplementDirtyWorkdir True False
    && not (warnIssueImplementDirtyWorkdir True True)
    && not (warnIssueImplementDirtyWorkdir False False)
    && warnPrReviewDirtyWorkdir True False False
    && not (warnPrReviewDirtyWorkdir True True False)
    && not (warnPrReviewDirtyWorkdir True False True)

prop_cliParsesHealthcheckAndRunLoop :: Bool
prop_cliParsesHealthcheckAndRunLoop =
  parseCliCommand ["healthcheck", "--state-root", "/tmp/state", "--repo", "owner/name"]
    == Right
      ( CliHealthcheck
          HealthcheckCli
            { healthcheckCliStateRoot = "/tmp/state"
            , healthcheckCliRepo = Just (RepoName "owner/name")
            , healthcheckCliEndpoint = Nothing
            }
      )
    && parseCliCommand
      [ "run-issue-planning"
      , "--events"
      , "/tmp/events.jsonl"
      , "--state-dir"
      , "/tmp/state"
      , "--repo"
      , "owner/name"
      , "--app-server-host"
      , "127.0.0.1"
      , "--app-server-port"
      , "3000"
      , "--thread-id"
      , "planner-thread"
      , "--scope-issue"
      , "12"
      , "--loop"
      , "--iterations"
      , "2"
      ]
      == Right
        ( CliRunLoop
            LoopCli
              { loopCliDomain = CliIssuePlanning
              , loopCliEventsPath = "/tmp/events.jsonl"
              , loopCliStateDir = "/tmp/state"
              , loopCliRepo = RepoName "owner/name"
              , loopCliWorkdir = "."
              , loopCliEndpoint = AppServerEndpoint "127.0.0.1" 3000 "/"
              , loopCliPollSeconds = 30
              , loopCliExecute = False
              , loopCliLoop = True
              , loopCliIterations = Just 2
              , loopCliPidFile = Nothing
              , loopCliPlannerThread = Just (ThreadId "planner-thread")
              , loopCliScopeIssues = [IssueNumber 12]
              , loopCliImplementersRoot = Nothing
              , loopCliOpenIssues = Nothing
              , loopCliActiveIssues = Nothing
              , loopCliImplementerWorkdirRoot = Nothing
              , loopCliWorkdirRoot = Nothing
              , loopCliBranchPrefix = "codex/issue-"
              , loopCliThreadPrefix = "issue-worker-"
              , loopCliStartChildren = False
              , loopCliChildPollSeconds = Nothing
              }
        )
    && parseCliCommand
      [ "guard-issue-planning"
      , "--events"
      , "/tmp/events.jsonl"
      , "--state-dir"
      , "/tmp/state"
      , "--repo"
      , "owner/name"
      , "--app-server-host"
      , "127.0.0.1"
      , "--app-server-port"
      , "3000"
      , "--thread-id"
      , "planner-thread"
      , "--execute"
      , "--loop"
      , "--guard-pid-file"
      , "/tmp/state/runner-guard.pid"
      , "--guard-poll-seconds"
      , "15"
      , "--stale-seconds"
      , "120"
      , "--repair-cwd"
      , "/tmp/repo"
      ]
      == Right
        ( CliGuardIssuePlanning
            GuardIssuePlanningCli
              { guardCliLoop =
                  LoopCli
                    { loopCliDomain = CliIssuePlanning
                    , loopCliEventsPath = "/tmp/events.jsonl"
                    , loopCliStateDir = "/tmp/state"
                    , loopCliRepo = RepoName "owner/name"
                    , loopCliWorkdir = "."
                    , loopCliEndpoint = AppServerEndpoint "127.0.0.1" 3000 "/"
                    , loopCliPollSeconds = 30
                    , loopCliExecute = True
                    , loopCliLoop = True
                    , loopCliIterations = Nothing
                    , loopCliPidFile = Nothing
                    , loopCliPlannerThread = Just (ThreadId "planner-thread")
                    , loopCliScopeIssues = []
                    , loopCliImplementersRoot = Nothing
                    , loopCliOpenIssues = Nothing
                    , loopCliActiveIssues = Nothing
                    , loopCliImplementerWorkdirRoot = Nothing
                    , loopCliWorkdirRoot = Nothing
                    , loopCliBranchPrefix = "codex/issue-"
                    , loopCliThreadPrefix = "issue-worker-"
                    , loopCliStartChildren = False
                    , loopCliChildPollSeconds = Nothing
                    }
              , guardCliPidFile = Just "/tmp/state/runner-guard.pid"
              , guardCliPollSeconds = 15
              , guardCliStaleSeconds = 120
              , guardCliRepairCwd = Just "/tmp/repo"
              }
        )
    && parseCliCommand
      [ "validate-migration"
      , "--source-state-dir"
      , "/tmp/source"
      , "--target-state-dir"
      , "/tmp/target"
      , "--domain"
      , "pr-review"
      ]
      == Right
        ( CliValidateMigration
            ValidateMigrationCli
              { validateMigrationCliSourceStateDir = "/tmp/source"
              , validateMigrationCliTargetStateDir = "/tmp/target"
              , validateMigrationCliDomain = CliPrReview
              , validateMigrationCliEventsPath = Nothing
              }
        )

prop_cliRejectsBadDomain :: Bool
prop_cliRejectsBadDomain =
  case parseCliCommand ["stop-daemon", "--state-dir", "/tmp/state", "--domain", "unknown"] of
    Left _ -> True
    Right _ -> False

prop_migrationRehearsalPlanSkipsRuntimeFiles :: Bool
prop_migrationRehearsalPlanSkipsRuntimeFiles =
  defaultRehearsalTarget "/tmp/rehearsal" "/workspace/artifacts/source-state" == "/tmp/rehearsal/source-state"
    && not (shouldCopyStateEntry "runtime-owner.json")
    && not (shouldCopyStateEntry "watcher.pid")
    && not (shouldCopyStateEntry "issue-watcher.pid")
    && shouldCopyStateEntry "events.jsonl"
    && renderBackoutCommands "/tmp/rehearsal/source-state" "pr-review"
      == [ "codex-watcher-hs stop-daemon --state-dir \"/tmp/rehearsal/source-state\" --domain pr-review"
         ]

prop_migrationReadinessRequiresHaskellTarget :: Bool
prop_migrationReadinessRequiresHaskellTarget =
  let ready =
        migrationReadinessReport
          "/tmp/target"
          "issue-planning"
          MigrationReadinessInput
            { readinessSourceOwner = Just NodeRuntime
            , readinessTargetOwner = Just HaskellRuntime
            , readinessOwnerProblems = []
            , readinessReplayDomain = Just IssuePlanning
            , readinessExpectedDomain = IssuePlanning
            , readinessReplayProblem = Nothing
            , readinessTargetPidExists = False
            }
      badTarget =
        migrationReadinessReport
          "/tmp/target"
          "issue-planning"
          MigrationReadinessInput
            { readinessSourceOwner = Just NodeRuntime
            , readinessTargetOwner = Just NodeRuntime
            , readinessOwnerProblems = []
            , readinessReplayDomain = Just IssuePlanning
            , readinessExpectedDomain = IssuePlanning
            , readinessReplayProblem = Nothing
            , readinessTargetPidExists = False
            }
      wrongDomain =
        migrationReadinessReport
          "/tmp/target"
          "issue-planning"
          MigrationReadinessInput
            { readinessSourceOwner = Just NodeRuntime
            , readinessTargetOwner = Just HaskellRuntime
            , readinessOwnerProblems = []
            , readinessReplayDomain = Just PrReview
            , readinessExpectedDomain = IssuePlanning
            , readinessReplayProblem = Nothing
            , readinessTargetPidExists = False
            }
   in migrationReady ready
        && migrationBackout ready == renderBackoutCommands "/tmp/target" "issue-planning"
        && not (migrationReady badTarget)
        && "target runtime-owner.json must be haskell, got node" `elem` migrationProblems badTarget
        && not (migrationReady wrongDomain)
        && any ("does not match expected" `Text.isInfixOf`) (migrationProblems wrongDomain)

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
      , goldenReplayCase "golden/pr-review/mlf2-pr6-clean-ready" PrReview Merging False
      , goldenReplayCase "golden/issue-implement/mlf2-issue42-already-resolved" IssueImplement Complete False
      , goldenReplayCase "golden/issue-implement/mlf2-issue42-plan-ready" IssueImplement PlanMode True
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
      , goldenEventLogCase "golden/event-log/issue-implement/mlf2-issue42-already-fixed/events.jsonl" IssueImplement Complete
      , goldenEventLogCase "golden/event-log/issue-implement/mlf2-issue42-triage-blocked/events.jsonl" IssueImplement Blocked
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
      , goldenBootstrapCase "golden/issue-implement/mlf2-issue42-already-resolved"
      , goldenBootstrapCase "golden/issue-implement/mlf2-issue42-plan-ready"
      , goldenBootstrapCase "golden/issue-implement/mlf2-issue42-incomplete"
      , goldenBootstrapCase "golden/issue-implement/mlf2-issue42-blocked"
      ]
  pure (and results)

data FakeActionCall
  = FakeCommand RuntimeCommand
  | FakeReadJson FilePath
  | FakeWriteJson FilePath Value
  | FakeAppendJsonLine FilePath Value
  | FakeAppServer AppServerRequest
  | FakeSleep
  | FakeStop
  deriving stock (Eq, Show)

fakeActionExecutor :: IO (ActionExecutor IO, IO [FakeActionCall])
fakeActionExecutor =
  fakeActionExecutorWith defaultFakeCommand defaultFakeAppServer

fakeActionExecutorWith :: (RuntimeCommand -> CommandReport) -> (AppServerRequest -> Value) -> IO (ActionExecutor IO, IO [FakeActionCall])
fakeActionExecutorWith commandResponse appServerResponse = do
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
          }
  pure (executor, readIORef calls)

defaultFakeCommand :: RuntimeCommand -> CommandReport
defaultFakeCommand _command =
  CommandReport {ok = True, status = Just 0, stdout = "ok", stderr = "", errorMessage = Nothing}

defaultFakeAppServer :: AppServerRequest -> Value
defaultFakeAppServer request
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
    TurnStartOptions
      { turnThreadId = threadId
      , turnCwd = "/tmp/work"
      , turnEffort = "xhigh"
      , turnModel = "gpt-5.4"
      , turnApprovalPolicy = "never"
      , turnSandboxPolicy = "danger-full-access"
      , turnInput = "worker prompt"
      , turnOutputSchema = Nothing
      , turnCollaborationMode = Nothing
      }

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
          [ assert "observed execute appends event first" (take 1 calls == [FakeAppendJsonLine "/tmp/events.jsonl" (toJSON expectedEvent)])
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
      loopConfig = DaemonLoopConfig options (Just (ThreadId "planner-thread"))
      events = [IssuePlanningInitialized (PlannerConfig (RepoName "soulomoon/mlf2") 8 [])]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let observedEvent = daemonObservedEvent <$> tick.loopObservedTick
      results <-
        sequence
          [ assert "automatic planning dry-run emits a planning start" (observedEvent == Just (IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "dry-run-planner-turn-120")))
          , assert "automatic planning dry-run does not call interpreters" (null calls)
          , assert "automatic planning dry-run reports start action" (length tick.loopActionReports == 1)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic planning dry-run: " <> Text.unpack (formatDaemonLoopFailure failure))
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
      events = [IssueImplementInitialized issueConfig (ThreadId "worker-thread")]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      let expectedEvent = IssueTriageTurnStartedEvent (TurnId "turn-started")
      results <-
        sequence
          [ assert "automatic execute prestarts app-server turn once" (length [() | FakeAppServer request <- calls, request.requestMethod == "turn/start"] == 1)
          , assert "automatic execute appends returned turn event" (FakeAppendJsonLine "/tmp/events.jsonl" (toJSON expectedEvent) `elem` calls)
          , assert "automatic execute reaches triage active" (maybe False ((== Triage) . somePhase . daemonObservedState) tick.loopObservedTick)
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
                          [ "id" .= ("turn-triage" :: Text)
                          , "status" .= ("completed" :: Text)
                          , "output" .= ("already fixed" :: Text)
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
        , IssueTriageTurnStartedEvent (TurnId "turn-triage")
        ]
  result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
  calls <- getCalls
  case result of
    Right tick -> do
      results <-
        sequence
          [ assert "automatic active turn reads app-server thread" (length [() | FakeAppServer request <- calls, request.requestMethod == "thread/read"] == 1)
          , assert "automatic active turn emits already-fixed event" (maybe False ((== IssueTriageAlreadyFixedEvent) . daemonObservedEvent) tick.loopObservedTick)
          , assert "automatic active turn reaches complete" (maybe False ((== Complete) . somePhase . daemonObservedState) tick.loopObservedTick)
          ]
      pure (and results)
    Left failure -> do
      putStrLn ("FAIL automatic active turn completion: " <> Text.unpack (formatDaemonLoopFailure failure))
      pure False

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
                          , "output" .= ("ready for review" :: Text)
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
        , IssuePlanTurnStartedEvent (TurnId "turn-plan")
        , IssuePlanCompletedEvent Nothing
        , IssuePullRequestReusedEvent prNumber
        , IssueImplementationTurnStartedEvent (TurnId "turn-impl")
        ]
      observedEventFor events = do
        result <- runAutomaticDaemonLoopOnceWithEvents executor loopConfig events
        pure $ case result of
          Right tick -> daemonObservedEvent <$> tick.loopObservedTick
          Left _ -> Nothing
  firstEvent <- observedEventFor baseEvents
  secondEvent <- observedEventFor (baseEvents <> [IssueReviewHandoffInitializedEvent prNumber])
  thirdEvent <- observedEventFor (baseEvents <> [IssueReviewHandoffInitializedEvent prNumber, IssueReviewHandoffStartedEvent prNumber])
  results <-
    sequence
      [ assert "automatic implementation completion initializes handoff first" (firstEvent == Just (IssueReviewHandoffInitializedEvent prNumber))
      , assert "automatic implementation completion starts handoff second" (secondEvent == Just (IssueReviewHandoffStartedEvent prNumber))
      , assert "automatic implementation completion completes after handoff" (thirdEvent == Just (IssueImplementationCompletedEvent prNumber))
      ]
  pure (and results)

main :: IO ()
main = do
  results <-
    sequence
      [ quickCheckResult prop_blockingNonTerminalRecordsReasonAndStops
      , quickCheckResult prop_stoppedTerminalDoesNotMutate
      , quickCheckResult prop_completeTerminalStopDoesNotMutate
      , quickCheckResult prop_unresolvedReviewsStartWorkerButDoNotMerge
      , quickCheckResult prop_noUnresolvedReviewsStartsReviewerOnly
      , quickCheckResult prop_cleanReviewIsRequiredToMerge
      , quickCheckResult prop_issuePlanCompletionCreatesPrBeforeImplementation
      , quickCheckResult prop_issueTriageAlreadyFixedCompletesWithoutPlan
      , quickCheckResult prop_issueTriageNeedsImplementationWaitsForPlan
      , quickCheckResult prop_issuePlanCompletionWithoutImmediateTurnCreatesPrOnly
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
      , quickCheckResult prop_eventLogCannotCreatePrBeforeIssuePlan
      , quickCheckResult prop_eventLogCannotCompleteIssueBeforeImplementationTurn
      , quickCheckResult prop_eventLogIssueAlreadyFixedCompletes
      , quickCheckResult prop_eventLogIssueIncompleteCanContinueToComplete
      , quickCheckResult prop_issueImplementWatcherTriageNeedsImplementation
      , quickCheckResult prop_issueImplementWatcherPlanCompletionPublishesBeforeImplementation
      , quickCheckResult prop_issueImplementWatcherIncompleteRestartsImplementation
      , quickCheckResult prop_issueImplementWatcherRejectsCompletionBeforeImplementationTurn
      , quickCheckResult prop_issueImplementWatcherBlockedStops
      , quickCheckResult prop_eventLogFullIssuePlanningPathReturnsReady
      , quickCheckResult prop_eventLogIssuePlanningIssueCreationReturnsReady
      , quickCheckResult prop_eventLogIssuePlanningGraphWaitsForReadyIssues
      , quickCheckResult prop_eventLogIssuePlanningReadyIssuesFixedReentersPlanning
      , quickCheckResult prop_eventLogCannotCompletePlanningBeforeStart
      , quickCheckResult prop_issuePlanningWatcherStartsAndCompletesTurn
      , quickCheckResult prop_issuePlanningWatcherCreatesIssuesBeforeReplanning
      , quickCheckResult prop_issuePlanningWatcherRecordsGraphBeforeFanoutAndWaits
      , quickCheckResult prop_issuePlanningSelectionRespectsMaxParallelAndSkipsActive
      , quickCheckResult prop_issuePlanningFanoutBuildsLaunchPlans
      , quickCheckResult prop_issuePlanningFanoutParsesImplementerConfig
      , quickCheckResult prop_issuePlanningFanoutDetectsCompletionBoundary
      , quickCheckResult prop_issuePlanningFanoutUsesOnlyReadyIssues
      , quickCheckResult prop_eventLogCanonicalJsonRoundTrips
      , quickCheckResult prop_eventLogCanonicalIssuePlanStartName
      , quickCheckResult prop_eventLogRejectsLegacyIssuePlanAliases
      , quickCheckResult prop_eventLogRejectsEmptyReviewThreads
      , quickCheckResult prop_eventLogRepairIssue26MissingPlanReentersImplementation
      , quickCheckResult prop_eventLogRepairCompletionWithoutImplementationTurnDropsComplete
      , quickCheckResult prop_eventLogRepairRejectsValidEventLog
      , quickCheckResult prop_protocolPrReviewWorkerCompletedReturnsToChecking
      , quickCheckResult prop_protocolPrReviewWorkerIncompleteReturnsToChecking
      , quickCheckResult prop_protocolPrReviewWorkerBlockedStopsInBlocked
      , quickCheckResult prop_protocolPrReviewWorkerEmitsStartThenTerminalEvent
      , quickCheckResult prop_protocolPrReviewReviewerCleanMovesToMerging
      , quickCheckResult prop_protocolPrReviewReviewerBlockedStopsInBlocked
      , quickCheckResult prop_protocolPrReviewReviewerProblemsReturnToChecking
      , quickCheckResult prop_protocolPrReviewReviewerIncompleteReturnsToChecking
      , quickCheckResult prop_protocolPrReviewReviewerEmitsStartThenCleanEvent
      , quickCheckResult prop_protocolPrReviewWorkerThenReviewerThenMergeCompletes
      , quickCheckResult prop_prReviewWatcherUnresolvedStartsWorker
      , quickCheckResult prop_prReviewWatcherCleanStartsReviewer
      , quickCheckResult prop_prReviewWatcherWorkerIncompleteReturnsToChecking
      , quickCheckResult prop_prReviewWatcherCleanReviewerMovesToMerging
      , quickCheckResult prop_runtimeCommandSpecsHaveExecutable
      , quickCheckResult prop_runtimeGitPushDryRunNeverForces
      , quickCheckResult prop_runtimeGitPushNeverForces
      , quickCheckResult prop_runtimeGhPrViewUsesStructuredFields
      , quickCheckResult prop_runtimeGhIssueCreateUsesRepoTitleAndBody
      , quickCheckResult prop_runtimeGhIssueCreateWithParentLinksSubIssue
      , quickCheckResult prop_runtimeKillZeroOnlyChecksPid
      , quickCheckResult prop_ghGitParsesIssueAndPrLists
      , quickCheckResult prop_ghGitParsesRemotePrView
      , quickCheckResult prop_ghGitParsesReviewThreadsGraphql
      , quickCheckResult prop_ghGitParsesGitOutputs
      , quickCheckResult prop_appServerInitializeRequestMatchesJsonRpc
      , quickCheckResult prop_appServerThreadStartKeepsNodeNullFields
      , quickCheckResult prop_appServerTurnStartPlanModeEncodesCollaborationMode
      , quickCheckResult prop_appServerThreadReadAndInterruptUseThreadIds
      , quickCheckResult prop_appServerClientInitializesSingleRequestSessions
      , quickCheckResult prop_appServerClientMatchesSuccessResponse
      , quickCheckResult prop_appServerClientSkipsNotifications
      , quickCheckResult prop_appServerClientRejectsMismatchedResponseIds
      , quickCheckResult prop_appServerClientSurfacesJsonRpcErrors
      , quickCheckResult prop_appServerClientFallsBackForUnmaterializedThreadRead
      , quickCheckResult prop_appServerClientRejectsUnsupportedJsonRpcVersion
      , quickCheckResult prop_appServerClientParsesThreadReadTurns
      , quickCheckResult prop_appServerClientParsesTurnStartTurnId
      , quickCheckResult prop_appServerClientParsesThreadStartThreadId
      , quickCheckResult prop_appServerClientParsesNestedThreadReadTurns
      , quickCheckResult prop_turnClassifierCompletionStates
      , quickCheckResult prop_turnClassifierMapsDomainOutputs
      , quickCheckResult prop_turnClassifierPrefersStructuredOutputs
      , quickCheckResult prop_turnClassifierBlocksMissingOutputs
      , quickCheckResult prop_effectInterpreterIssuePlanCompletionOrdersPublishBeforeWorker
      , quickCheckResult prop_effectInterpreterIssueTurnsUsePhaseSpecificPrompts
      , quickCheckResult prop_effectInterpreterTwoTurnStartsUseMonotonicRequestIds
      , quickCheckResult prop_effectInterpreterRecordBlockedWritesBlockState
      , quickCheckResult prop_effectInterpreterRecordPlanningGraphWritesState
      , quickCheckResult prop_effectInterpreterCreateIssueUsesConfiguredEffect
      , quickCheckResult prop_effectInterpreterMergeUsesConfiguredRepoAndMethod
      , quickCheckResult prop_actionExecutorDryRunPreservesActionOrder
      , quickCheckResult prop_migrationRuntimeOwnerJsonAndParsing
      , quickCheckResult prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork
      , quickCheckResult prop_cliParsesHealthcheckAndRunLoop
      , quickCheckResult prop_cliRejectsBadDomain
      , quickCheckResult prop_migrationRehearsalPlanSkipsRuntimeFiles
      , quickCheckResult prop_migrationReadinessRequiresHaskellTarget
      , quickCheckResult prop_supervisorRendersRestartAndLogrotate
      ]
  goldenOk <- goldenReplayCases
  eventLogOk <- goldenEventLogCases
  bootstrapOk <- goldenBootstrapCases
  actionExecutorDryRunOk <- actionExecutorDryRunDoesNotCallInterpreters
  actionExecutorExecuteOk <- actionExecutorExecuteCallsInjectedInterpreters
  daemonTickOk <- daemonTickDryRunReplaysEventsAndDoesNotExecute
  observedDaemonDryRunOk <- observedDaemonTickDryRunDoesNotMutate
  observedDaemonExecuteOk <- observedDaemonTickExecuteAppendsWritesAndRunsEffects
  automaticPlanningDryRunOk <- automaticDaemonLoopPlanningDryRunStartsSyntheticTurn
  automaticPlanningIssueCreationOk <- automaticDaemonLoopPlanningIssueCreationRequestsReplanning
  automaticPlanningGraphOk <- automaticDaemonLoopPlanningGraphWaitsAndRecords
  automaticExecutePrestartOk <- automaticDaemonLoopExecutePrestartsTurnOnce
  automaticActiveTurnOk <- automaticDaemonLoopActiveTurnCompletionObservesOutput
  automaticImplementationHandoffOk <- automaticDaemonLoopImplementationCompletionSequencesHandoff
  runnerGuardOk <- runnerGuardIgnoresMissingPidForCompletePlanning
  runnerGuardRestartOk <- runnerGuardRestartsMissingPidForIncompletePlanning
  runnerGuardRepairOk <- runnerGuardRepairsInvalidPlanningEventLog
  if
    all isSuccess results
      && goldenOk
      && eventLogOk
      && bootstrapOk
      && actionExecutorDryRunOk
      && actionExecutorExecuteOk
      && daemonTickOk
      && observedDaemonDryRunOk
      && observedDaemonExecuteOk
      && automaticPlanningDryRunOk
      && automaticPlanningIssueCreationOk
      && automaticPlanningGraphOk
      && automaticExecutePrestartOk
      && automaticActiveTurnOk
      && automaticImplementationHandoffOk
      && runnerGuardOk
      && runnerGuardRestartOk
      && runnerGuardRepairOk
    then pure ()
    else exitFailure
