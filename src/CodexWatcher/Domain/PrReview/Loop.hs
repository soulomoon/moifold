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
import CodexWatcher.Daemon (DaemonObservation (..), DaemonOptions (..), PreMergeGateResult (..), prChecksGate, runPreMergeGate)
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
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), MergeCommit (..), PrConfig (..), ReviewEvidence (..), ReviewFinding (..), reviewEvidenceFromSummaries)
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
  withReviewTargetAfterMergeStateFixGate ops executor config events prConfig workerThread "review-thread check" \commit remote -> do
    report <- runGhReviewThreads executor.actionRuntime prConfig
    case report of
      Left reason -> pure (Left (DaemonLoopExternalFailure reason))
      Right reviewReport -> do
        checkFindings <- checkingPrCheckFindings executor prConfig
        let reviewEvidence = unresolvedReviewEvidence reviewReport commit
            changeFindings =
              [changesRequestedFinding prConfig | isChangesRequested remote.remotePullRequestReviewDecision]
            summaryFindings = changeFindings <> checkFindings
            findingsEvidence = combineReviewEvidence reviewEvidence summaryFindings commit
        case (reviewEvidence, summaryFindings, findingsEvidence) of
          (Just evidence, [], _) ->
            ops.loopPrestartAndObserve executor config events (StartWorkerTurnKind evidence) workerThread \turnId ->
              DaemonPrReviewObservation (ObservedReviewThreads reviewReport commit turnId)
          (_, _, Just evidence) ->
            startWorkerFeedbackTurn ops executor config events evidence workerThread
          (_, _, Nothing) ->
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
  withReviewTargetAfterMergeStateFixGate ops executor config events prConfig workerThread "review-fix verification" \reviewTargetSha _remote ->
    ops.loopPrestartAndObserve executor config events (StartReviewerVerificationTurnKind prConfig evidence reviewTargetSha) reviewerThread \turnId ->
      DaemonPrReviewObservation (ObservedReviewFixVerificationStarted reviewTargetSha turnId)

withReviewTargetAfterMergeStateFixGate
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
withReviewTargetAfterMergeStateFixGate ops executor config events prConfig workerThread context onReady = do
  targetResult <- loadReviewTargetAndRemote executor config prConfig context
  case targetResult of
    Left failure -> pure (Left failure)
    Right (commit, remote) -> do
      mergeStateFix <- queueMergeStateFixIfNeeded ops executor config events workerThread commit remote
      case mergeStateFix of
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

queueMergeStateFixIfNeeded
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> ThreadId
  -> CommitSha
  -> RemotePullRequest
  -> m (Maybe (Either DaemonLoopFailure DaemonLoopTickResult))
queueMergeStateFixIfNeeded ops executor config events workerThread commit remote =
  case mergeStateFixEvidence commit remote of
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

checkingPrCheckFindings :: Monad m => ActionExecutor m -> PrConfig -> m [Text]
checkingPrCheckFindings executor prConfig = do
  checksGate <- prChecksGate executor prConfig
  pure case checksGate of
    PreMergeGateFixRequired reason -> [reason]
    _ -> []

combineReviewEvidence :: Maybe ReviewEvidence -> [Text] -> CommitSha -> Maybe ReviewEvidence
combineReviewEvidence maybeEvidence summaries commit =
  case (maybeEvidence, summaries) of
    (Just evidence, []) ->
      Just evidence
    (Just evidence, summary : rest) ->
      Just evidence {reviewFindings = evidence.reviewFindings <> (ReviewSummaryFinding summary :| fmap ReviewSummaryFinding rest)}
    (Nothing, summary : rest) ->
      Just (reviewEvidenceFromSummaries (summary :| rest) commit)
    (Nothing, []) ->
      Nothing

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
  effectiveGate <- mergeabilityRetryWithCheckOverride executor prConfig gate
  let observation =
        case effectiveGate of
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

mergeabilityRetryWithCheckOverride :: Monad m => ActionExecutor m -> PrConfig -> PreMergeGateResult -> m PreMergeGateResult
mergeabilityRetryWithCheckOverride executor prConfig gate =
  case gate of
    PreMergeGateRetry reason
      | Text.isPrefixOf "pre-merge merge state is " reason -> do
          checksGate <- prChecksGate executor prConfig
          pure case checksGate of
            PreMergeGatePassed -> gate
            PreMergeGateRetry checksReason -> PreMergeGateRetry checksReason
            PreMergeGateRecheck checksReason -> PreMergeGateRecheck checksReason
            PreMergeGateFixRequired checksReason -> PreMergeGateFixRequired checksReason
            PreMergeGateBlocked checksReason -> PreMergeGateBlocked checksReason
    _ ->
      pure gate

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

mergeStateFixEvidence :: CommitSha -> RemotePullRequest -> Maybe ReviewEvidence
mergeStateFixEvidence commit remote =
  case classifyRemotePullRequestMergeState remote.remotePullRequestMergeStateStatus of
    RemotePullRequestMergeStateFixRequired status ->
      Just (reviewEvidenceFromSummaries (remotePullRequestMergeStateFixMessage "merge state" status :| []) commit)
    _ -> Nothing

changesRequestedFinding :: PrConfig -> Text
changesRequestedFinding prConfig =
  "GitHub reports reviewDecision=CHANGES_REQUESTED for PR #"
    <> Text.pack (show (unPrNumber prConfig.prNumber))
    <> "; inspect the latest request-changes review and address its findings."
