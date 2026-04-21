{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Main (main) where

import CodexWatcher.Effects
import CodexWatcher.GoldenReplay
import CodexWatcher.Snapshot
import CodexWatcher.StateMachine
import CodexWatcher.Types
import Data.List.NonEmpty (NonEmpty (..))
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
      ]
  goldenOk <- goldenReplayCases
  if all isSuccess results && goldenOk then pure () else exitFailure
