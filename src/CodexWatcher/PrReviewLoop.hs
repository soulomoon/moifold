{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.PrReviewLoop
  ( runPrCheckingReviews
  , runPrFixingReviews
  , runPrMerging
  , runPrReviewingClean
  , runPrWaitingForMergeability
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.Daemon (DaemonObservation (..), DaemonOptions (..), PreMergeGateResult (..), runPreMergeGate)
import CodexWatcher.DaemonLoop.Types
import CodexWatcher.EffectInterpreter (EffectRuntimeConfig (..))
import CodexWatcher.EventLog
import CodexWatcher.GhGit
import CodexWatcher.PrReviewWatcher
import CodexWatcher.TurnClassifier
import CodexWatcher.Types
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
        Right reviewReport ->
          let hasUnresolved = not (null reviewReport.unresolvedReviewThreads)
              targetThread = if hasUnresolved then workerThread else reviewerThread
           in ops.loopPrestartAndObserve executor config events (if hasUnresolved then StartWorkerTurnKind else StartReviewerTurnKind prConfig commit) targetThread \turnId ->
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
