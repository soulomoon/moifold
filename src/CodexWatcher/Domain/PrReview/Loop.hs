{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.PrReview.Loop
  ( runPrCheckingReviews
  , runPrFixingReviews
  , runPrMerging
  , runPrReviewingClean
  , runPrVerifyingReviewFix
  , runPrWaitingForMergeability
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.Daemon (DaemonObservation (..), DaemonOptions (..), PreMergeGateResult (..), runPreMergeGate)
import CodexWatcher.DaemonLoop.Types
import CodexWatcher.EffectInterpreter (EffectRuntimeConfig (..))
import CodexWatcher.EventLog.Types
import CodexWatcher.GhGit
import CodexWatcher.Domain.PrReview.TurnClassifier
import CodexWatcher.Domain.PrReview.Watcher
import CodexWatcher.Runtime.Paths (runtimeWorkdirPath)
import CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)
import CodexWatcher.Core.Reason (BlockedReason (..))
import CodexWatcher.Core.Thread (ActiveTurn)
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), MergeCommit (..), PrConfig (..), ReviewEvidence, reviewEvidenceFromSummaries)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text

runPrCheckingReviews
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> PrConfig
  -> ThreadId
  -> ThreadId
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runPrCheckingReviews ops executor config events prConfig workerThread reviewerThread = do
  status <-
    runGitWorktreeStatus
      executor.actionRuntime
      (runtimeWorkdirPath config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeWorkdir)
      prConfig.prBranch
  case status.gitHeadSha of
    Nothing -> pure (Left (DaemonLoopExternalFailure "could not determine git HEAD for review-thread check"))
    Just commit -> do
      report <- runGhReviewThreads executor.actionRuntime prConfig
      case report of
        Left reason -> pure (Left (DaemonLoopExternalFailure reason))
        Right reviewReport
          | not (null reviewReport.unresolvedReviewThreads) ->
              ops.loopPrestartAndObserve executor config events StartWorkerTurnKind workerThread \turnId ->
                DaemonPrReviewObservation (ObservedReviewThreads reviewReport commit turnId)
          | otherwise -> do
              remoteResult <- runGhPrView executor.actionRuntime prConfig.prRepo prConfig.prNumber
              case remoteResult of
                Left reason -> pure (Left (DaemonLoopExternalFailure reason))
                Right remote
                  | isChangesRequested remote.remotePullRequestReviewDecision ->
                      let evidence = reviewEvidenceFromSummaries (changesRequestedFinding prConfig :| []) commit
                       in ops.loopPrestartAndObserve executor config events StartWorkerTurnKind workerThread \turnId ->
                            DaemonPrReviewObservation (ObservedReviewFeedback evidence turnId)
                  | otherwise ->
                      ops.loopPrestartAndObserve executor config events (StartReviewerTurnKind prConfig commit) reviewerThread \turnId ->
                        DaemonPrReviewObservation (ObservedReviewThreads reviewReport commit turnId)

runPrFixingReviews
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> ActiveTurn
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runPrFixingReviews ops executor config events replay activeTurn =
  observeClassifiedActiveTurn ops executor config events replay activeTurn \turn ->
    fmap DaemonPrReviewObservation (classifyPrReviewWorkerTurn turn)

runPrVerifyingReviewFix
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> PrConfig
  -> ReviewEvidence
  -> ThreadId
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runPrVerifyingReviewFix ops executor config events prConfig evidence reviewerThread = do
  status <-
    runGitWorktreeStatus
      executor.actionRuntime
      (runtimeWorkdirPath config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeWorkdir)
      prConfig.prBranch
  case status.gitHeadSha of
    Nothing -> pure (Left (DaemonLoopExternalFailure "could not determine git HEAD for review-fix verification"))
    Just reviewTargetSha ->
      ops.loopPrestartAndObserve executor config events (StartReviewerVerificationTurnKind prConfig evidence reviewTargetSha) reviewerThread \turnId ->
        DaemonPrReviewObservation (ObservedReviewFixVerificationStarted reviewTargetSha turnId)

runPrReviewingClean
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> CommitSha
  -> ActiveTurn
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runPrReviewingClean ops executor config events replay commit activeTurn =
  observeClassifiedActiveTurn ops executor config events replay activeTurn \turn ->
    fmap DaemonPrReviewObservation (classifyPrReviewReviewerTurn commit turn)

runPrWaitingForMergeability
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> PrConfig
  -> CleanReviewEvidence
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runPrWaitingForMergeability ops executor config events prConfig evidence = do
  gate <- runPreMergeGate executor prConfig evidence
  let observation =
        case gate of
          PreMergeGatePassed ->
            ObservedMergeabilityClean evidence.cleanReviewCommit
          PreMergeGateRetry reason ->
            ObservedMergeabilityRetry reason
          PreMergeGateRecheck reason ->
            ObservedMergeabilityRecheck reason
          PreMergeGateBlocked reason ->
            ObservedPrReviewBlocked (BlockedReason reason)
  ops.loopObserveWithExecutor executor config events (DaemonPrReviewObservation observation)

runPrMerging
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> PrConfig
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runPrMerging ops executor config events replay prConfig = do
  pullRequest <- runGhPrView executor.actionRuntime prConfig.prRepo prConfig.prNumber
  case pullRequest of
    Left reason -> pure (Left (DaemonLoopExternalFailure reason))
    Right remote
      | remotePullRequestIsMerged remote
      , Just mergeCommit <- remote.remotePullRequestMergeCommit ->
          ops.loopObserveWithExecutor executor config events (DaemonPrReviewObservation (ObservedMergeCompleted (MergeCommit mergeCommit)))
      | otherwise ->
          ops.loopIdle executor config replay ("waiting for PR merge completion for #" <> Text.pack (show (unPrNumber prConfig.prNumber)))

isChangesRequested :: Maybe Text -> Bool
isChangesRequested =
  maybe False ((== "CHANGES_REQUESTED") . Text.toUpper . Text.strip)

changesRequestedFinding :: PrConfig -> Text
changesRequestedFinding prConfig =
  "GitHub reports reviewDecision=CHANGES_REQUESTED for PR #"
    <> Text.pack (show (unPrNumber prConfig.prNumber))
    <> "; inspect the latest request-changes review and address its findings."
