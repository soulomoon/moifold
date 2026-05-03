{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.PrReview.Loop
  ( runPrCheckingReviews
  , runPrFixingReviews
  , runPrMerging
  , runPrReviewFixQueued
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
  withReviewTargetAfterBranchGate ops executor config events prConfig workerThread "review-thread check" \commit remote -> do
    report <- runGhReviewThreads executor.actionRuntime prConfig
    case report of
      Left reason -> pure (Left (DaemonLoopExternalFailure reason))
      Right reviewReport
        | Just evidence <- unresolvedReviewEvidence reviewReport commit ->
            ops.loopPrestartAndObserve executor config events (StartWorkerTurnKind evidence) workerThread \turnId ->
              DaemonPrReviewObservation (ObservedReviewThreads reviewReport commit turnId)
        | isChangesRequested remote.remotePullRequestReviewDecision ->
            let evidence = reviewEvidenceFromSummaries (changesRequestedFinding prConfig :| []) commit
             in startWorkerFeedbackTurn ops executor config events evidence workerThread
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

runPrReviewFixQueued
  :: DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> ReviewEvidence
  -> ThreadId
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runPrReviewFixQueued ops executor config events evidence workerThread =
  startWorkerFeedbackTurn ops executor config events evidence workerThread

runPrVerifyingReviewFix
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> PrConfig
  -> ReviewEvidence
  -> ThreadId
  -> ThreadId
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runPrVerifyingReviewFix ops executor config events prConfig evidence workerThread reviewerThread = do
  withReviewTargetAfterBranchGate ops executor config events prConfig workerThread "review-fix verification" \reviewTargetSha _remote ->
    ops.loopPrestartAndObserve executor config events (StartReviewerVerificationTurnKind prConfig evidence reviewTargetSha) reviewerThread \turnId ->
      DaemonPrReviewObservation (ObservedReviewFixVerificationStarted reviewTargetSha turnId)

withReviewTargetAfterBranchGate
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> PrConfig
  -> ThreadId
  -> Text
  -> (CommitSha -> RemotePullRequest -> m (Either DaemonLoopFailure DaemonLoopTickResult))
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
withReviewTargetAfterBranchGate ops executor config events prConfig workerThread context onReady = do
  targetResult <- loadReviewTargetAndRemote executor config prConfig context
  case targetResult of
    Left failure -> pure (Left failure)
    Right (commit, remote) -> do
      branchFix <- queueBranchMergeFixIfNeeded ops executor config events workerThread commit remote
      case branchFix of
        Just result -> pure result
        Nothing -> onReady commit remote

loadReviewTargetAndRemote
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> PrConfig
  -> Text
  -> m (Either DaemonLoopFailure (CommitSha, RemotePullRequest))
loadReviewTargetAndRemote executor config prConfig context = do
  status <-
    runGitWorktreeStatus
      executor.actionRuntime
      (runtimeWorkdirPath config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeWorkdir)
      prConfig.prBranch
  case status.gitHeadSha of
    Nothing -> pure (Left (DaemonLoopExternalFailure ("could not determine git HEAD for " <> context)))
    Just commit -> do
      remoteResult <- runGhPrView executor.actionRuntime prConfig.prRepo prConfig.prNumber
      case remoteResult of
        Left reason -> pure (Left (DaemonLoopExternalFailure reason))
        Right remote -> pure (Right (commit, remote))

queueBranchMergeFixIfNeeded
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> ThreadId
  -> CommitSha
  -> RemotePullRequest
  -> m (Maybe (Either DaemonLoopFailure DaemonLoopTickResult))
queueBranchMergeFixIfNeeded ops executor config events workerThread commit remote =
  case branchMergeFixEvidence commit remote of
    Nothing -> pure Nothing
    Just evidence ->
      Just <$> startWorkerFeedbackTurn ops executor config events evidence workerThread

startWorkerFeedbackTurn
  :: DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> ReviewEvidence
  -> ThreadId
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
startWorkerFeedbackTurn ops executor config events evidence workerThread =
  ops.loopPrestartAndObserve executor config events (StartWorkerTurnKind evidence) workerThread \turnId ->
    DaemonPrReviewObservation (ObservedReviewFeedback evidence turnId)

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
          PreMergeGateFixRequired reason ->
            ObservedMergeabilityFixRequired (reviewEvidenceFromSummaries (reason :| []) evidence.cleanReviewCommit)
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

branchMergeFixEvidence :: CommitSha -> RemotePullRequest -> Maybe ReviewEvidence
branchMergeFixEvidence commit remote =
  case classifyRemotePullRequestMergeState remote.remotePullRequestMergeStateStatus of
    RemotePullRequestMergeStateFixRequired status ->
      Just (reviewEvidenceFromSummaries (remotePullRequestMergeStateFixMessage "branch merge state" status :| []) commit)
    _ -> Nothing

changesRequestedFinding :: PrConfig -> Text
changesRequestedFinding prConfig =
  "GitHub reports reviewDecision=CHANGES_REQUESTED for PR #"
    <> Text.pack (show (unPrNumber prConfig.prNumber))
    <> "; inspect the latest request-changes review and address its findings."
