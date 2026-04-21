{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Main (main) where

import CodexWatcher.AppServerProtocol
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
  , object
  , toJSON
  , (.=)
  )
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text
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
  case step (IssueInPlanMode config (WorkerActive planningTurn)) (IssuePlanCompleted implementationTurn) of
    Decision state effects ->
      phaseOf state == Implementing
        && any effectIsPush effects
        && any effectIsCreatePr effects
        && any effectIsStartWorker effects

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
    , IssueStartPlanMode planTurn
    , IssuePlanCompletedEvent implementationTurn
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
  , GhPrView (RepoName "soulomoon/mlf2") (PrNumber 6) ["state", "url"]
  , GitBranchCurrent "/tmp/work"
  , GitRevParseHead "/tmp/work"
  , GitStatusPorcelain "/tmp/work"
  , GitLsRemoteBranch "/tmp/work" (BranchName "codex/example")
  , GitPushDryRun "/tmp/work" (BranchName "codex/example")
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
      , goldenEventLogCase "golden/event-log/issue-planning/mlf2-planning-ready/events.jsonl" IssuePlanning Initialized
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
      , quickCheckResult prop_plannerCompletionReturnsToReady
      , quickCheckResult prop_terminalStateHasNoImplicitEffects
      , quickCheckResult prop_eventLogFullPrReviewPathCompletes
      , quickCheckResult prop_eventLogCannotReviewCleanWhileFixing
      , quickCheckResult prop_eventLogCannotMergeBeforeCleanReview
      , quickCheckResult prop_eventLogFullIssueImplementationPathCompletes
      , quickCheckResult prop_eventLogCannotCompleteIssueBeforePlanning
      , quickCheckResult prop_eventLogFullIssuePlanningPathReturnsReady
      , quickCheckResult prop_eventLogCannotCompletePlanningBeforeStart
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
      , quickCheckResult prop_runtimeGhPrViewUsesStructuredFields
      , quickCheckResult prop_runtimeKillZeroOnlyChecksPid
      , quickCheckResult prop_appServerInitializeRequestMatchesJsonRpc
      , quickCheckResult prop_appServerThreadStartKeepsNodeNullFields
      , quickCheckResult prop_appServerTurnStartPlanModeEncodesCollaborationMode
      , quickCheckResult prop_appServerThreadReadAndInterruptUseThreadIds
      ]
  goldenOk <- goldenReplayCases
  eventLogOk <- goldenEventLogCases
  if all isSuccess results && goldenOk && eventLogOk then pure () else exitFailure
