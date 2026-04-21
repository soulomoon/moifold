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
import CodexWatcher.EffectInterpreter
import CodexWatcher.Effects
import CodexWatcher.EventLog
import CodexWatcher.GoldenReplay
import CodexWatcher.Protocol
import CodexWatcher.Runtime
import CodexWatcher.Snapshot
import CodexWatcher.StateMachine
import CodexWatcher.Types
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
import Data.Text (Text)
import Data.Text qualified as Text
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
  arbitrary = PlannerConfig <$> arbitrary <*> (getPositive <$> arbitrary)

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

effectIsStartReviewer :: SomeEffect -> Bool
effectIsStartReviewer = \case
  SomeEffect StartReviewerTurn {} -> True
  _ -> False

effectIsCreatePr :: SomeEffect -> Bool
effectIsCreatePr = \case
  SomeEffect CreatePullRequest {} -> True
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
        && any effectIsStartWorker effects

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
        && any effectIsStartWorker effects
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
      phaseOf state == Initialized
        && not (hasMutation effects)

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

prop_eventLogFullIssuePlanningPathReturnsReady :: PlannerConfig -> ThreadId -> TurnId -> Bool
prop_eventLogFullIssuePlanningPathReturnsReady config plannerThread plannerTurn =
  case replayEventLog
    [ IssuePlanningInitialized config
    , IssuePlanningTurnStarted plannerThread plannerTurn
    , IssuePlanningTurnCompleted
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

canonicalEventExamples :: [WatcherEvent]
canonicalEventExamples =
  [ IssuePlanningInitialized plannerConfig
  , IssuePlanningTurnStarted plannerThread plannerTurn
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
  , WatcherBlocked blockedReason
  , WatcherStopped stopReason
  ]
 where
  repo = RepoName "owner/name"
  plannerConfig = PlannerConfig repo 8
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

runtimeCommandExamples :: [RuntimeCommand]
runtimeCommandExamples =
  [ CommandVersion "git"
  , GhAuthStatus
  , GhApiUser
  , GhIssueListOpen (RepoName "soulomoon/mlf2")
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
  , RawCommand "node" ["--version"] Nothing
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

prop_runtimeKillZeroOnlyChecksPid :: ThreadId -> Bool
prop_runtimeKillZeroOnlyChecksPid threadId =
  let pidText = unThreadId threadId
      spec = renderRuntimeCommand (KillZero pidText)
   in spec.command == "kill"
        && spec.args == ["-0", Text.unpack pidText]
        && spec.cwd == Nothing

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
            , turnCollaborationMode = Just collaborationMode
            }
   in request.requestMethod == "turn/start"
        && lookupValue "threadId" request.requestParams == Just (String (unThreadId threadId))
        && lookupValue "collaborationMode" request.requestParams == Just collaborationMode
        && lookupValue "summary" request.requestParams == Just Null
        && lookupValue "outputSchema" request.requestParams == Just Null

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
            && actionIsTurnStartFor (activeThreadId implementationTurn) (actions !! 2)
            && compiled.compiledNextRequestId == 11

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
      , goldenEventLogCase "golden/event-log/issue-planning/mlf2-planning-ready/events.jsonl" IssuePlanning Initialized
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
fakeActionExecutor = do
  calls <- newIORef []
  let record call = modifyIORef' calls (<> [call])
      runtime =
        RuntimeInterpreter
          { runtimeRunCommand = \command -> do
              record (FakeCommand command)
              pure CommandReport {ok = True, status = Just 0, stdout = "ok", stderr = "", errorMessage = Nothing}
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
              pure (object ["ok" .= True])
          }
      executor =
        ActionExecutor
          { actionRuntime = runtime
          , actionAppServer = appServer
          , actionSleepUntilNextPoll = record FakeSleep
          , actionStopDaemon = record FakeStop
          }
  pure (executor, readIORef calls)

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
      , turnCollaborationMode = Nothing
      }

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
      , quickCheckResult prop_terminalStateHasNoImplicitEffects
      , quickCheckResult prop_eventLogFullPrReviewPathCompletes
      , quickCheckResult prop_eventLogCannotReviewCleanWhileFixing
      , quickCheckResult prop_eventLogCannotMergeBeforeCleanReview
      , quickCheckResult prop_eventLogFullIssueImplementationPathCompletes
      , quickCheckResult prop_eventLogCannotCompleteIssueBeforePlanning
      , quickCheckResult prop_eventLogIssueAlreadyFixedCompletes
      , quickCheckResult prop_eventLogIssueIncompleteCanContinueToComplete
      , quickCheckResult prop_eventLogFullIssuePlanningPathReturnsReady
      , quickCheckResult prop_eventLogCannotCompletePlanningBeforeStart
      , quickCheckResult prop_eventLogCanonicalJsonRoundTrips
      , quickCheckResult prop_eventLogCanonicalIssuePlanStartName
      , quickCheckResult prop_eventLogRejectsLegacyIssuePlanAliases
      , quickCheckResult prop_eventLogRejectsEmptyReviewThreads
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
      , quickCheckResult prop_runtimeCommandSpecsHaveExecutable
      , quickCheckResult prop_runtimeGitPushDryRunNeverForces
      , quickCheckResult prop_runtimeGitPushNeverForces
      , quickCheckResult prop_runtimeGhPrViewUsesStructuredFields
      , quickCheckResult prop_runtimeKillZeroOnlyChecksPid
      , quickCheckResult prop_appServerInitializeRequestMatchesJsonRpc
      , quickCheckResult prop_appServerThreadStartKeepsNodeNullFields
      , quickCheckResult prop_appServerTurnStartPlanModeEncodesCollaborationMode
      , quickCheckResult prop_appServerThreadReadAndInterruptUseThreadIds
      , quickCheckResult prop_effectInterpreterIssuePlanCompletionOrdersPublishBeforeWorker
      , quickCheckResult prop_effectInterpreterTwoTurnStartsUseMonotonicRequestIds
      , quickCheckResult prop_effectInterpreterRecordBlockedWritesBlockState
      , quickCheckResult prop_effectInterpreterMergeUsesConfiguredRepoAndMethod
      , quickCheckResult prop_actionExecutorDryRunPreservesActionOrder
      ]
  goldenOk <- goldenReplayCases
  eventLogOk <- goldenEventLogCases
  actionExecutorDryRunOk <- actionExecutorDryRunDoesNotCallInterpreters
  actionExecutorExecuteOk <- actionExecutorExecuteCallsInjectedInterpreters
  if all isSuccess results && goldenOk && eventLogOk && actionExecutorDryRunOk && actionExecutorExecuteOk then pure () else exitFailure
