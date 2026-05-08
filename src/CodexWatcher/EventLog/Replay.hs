{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module CodexWatcher.EventLog.Replay
  ( applyEvent
  , initializeFromEvent
  , replayEventLog
  ) where

import CodexWatcher.Effects
import CodexWatcher.EventLog.Types
import CodexWatcher.StateMachine
import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId (..), TurnId (..))
import CodexWatcher.Core.Kinds (Domain (..), KnownDomain, Phase (..))
import CodexWatcher.Core.Reason (BlockedReason, StopReason (..))
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..), isTerminalState, someDomain, somePhase)
import CodexWatcher.Core.Thread (ActiveTurn (..), ReviewerThread (..), WorkerThread (..))
import CodexWatcher.Domain.IssuePlanning.Scope (planningGraphIssues, scopedGraphClosure)
import CodexWatcher.Domain.IssuePlanning.Types
  ( BlockedPlanningIssue (..)
  , IssueDependency (..)
  , PlannerConfig (..)
  , PlanningGraph (..)
  )
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), ReviewEvidence, reviewEvidenceFromThreads)
import Data.List (find, intersect)
import Data.Text (Text)
import Data.Text qualified as Text

replayEventLog :: [WatcherEvent] -> Either ReplayFailure EventReplayResult
replayEventLog = go 1 Nothing []
 where
  go _ (Just state) effects [] =
    Right EventReplayResult { replayState = state, replayEffects = reverse effects }
  go index Nothing effects (event : rest) =
    case initializeFromEvent event of
      Right (state, effectPlan) -> go (index + 1) (Just state) (effectPlan : effects) rest
      Left reason -> Left ReplayFailure { eventIndex = index, event, reason }
  go index (Just state) effects (event : rest) =
    case applyEvent state event of
      Right (state', effectPlan) -> go (index + 1) (Just state') (effectPlan : effects) rest
      Left reason -> Left ReplayFailure { eventIndex = index, event, reason }
  go index Nothing _ [] =
    Left ReplayFailure { eventIndex = index, event = WatcherStopped (StopReason "empty event log"), reason = "event log is empty" }

initializeFromEvent :: WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
initializeFromEvent = \case
  IssuePlanningInitialized config ->
    Right
      ( SomeWatcherState (PlanningReady config :: WatcherState 'IssuePlanning 'Initialized)
      , []
      )
  PrReviewInitialized config workerThread reviewerThread ->
    Right
      ( SomeWatcherState (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread) :: WatcherState 'PrReview 'CheckingReviews)
      , []
      )
  IssueImplementInitialized config workerThread ->
    Right
      ( SomeWatcherState (IssueImplementationReady config Nothing (WorkerIdle workerThread) :: WatcherState 'IssueImplement 'Implementing)
      , []
      )
  event ->
    Left ("first event must initialize a watcher, got " <> eventName event)

applyEvent :: SomeWatcherState -> WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
applyEvent state event
  | isTerminalState state =
      terminalEvent state event
applyEvent _ event@PrReviewInitialized {} =
  Left ("duplicate initialization event: " <> eventName event)
applyEvent _ event@IssueImplementInitialized {} =
  Left ("duplicate initialization event: " <> eventName event)
applyEvent _ event@IssuePlanningInitialized {} =
  Left ("duplicate initialization event: " <> eventName event)
applyEvent (SomeWatcherState (PrCheckingReviews config (WorkerIdle _oldWorker) (ReviewerIdle _oldReviewer))) (PrReviewThreadsRefreshed workerThread reviewerThread) =
  Right (SomeWatcherState (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread)), [])
applyEvent (SomeWatcherState (PrReviewFixQueued config evidence (WorkerIdle _oldWorker) (ReviewerIdle _oldReviewer))) (PrReviewThreadsRefreshed workerThread reviewerThread) =
  Right (SomeWatcherState (PrReviewFixQueued config evidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread)), [])
applyEvent (SomeWatcherState (PrFixingReviews config evidence worker@(WorkerActive activeTurn) (ReviewerIdle _oldReviewer))) (PrReviewThreadsRefreshed workerThread reviewerThread)
  | workerThread == activeThreadId activeTurn =
      Right (SomeWatcherState (PrFixingReviews config evidence worker (ReviewerIdle reviewerThread)), [])
  | otherwise =
      Left "PR review thread refresh worker thread does not match active worker turn"
applyEvent (SomeWatcherState (PrWaitingForMergeability config evidence (WorkerIdle _oldWorker) (ReviewerIdle _oldReviewer))) (PrReviewThreadsRefreshed workerThread reviewerThread) =
  Right (SomeWatcherState (PrWaitingForMergeability config evidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread)), [])
applyEvent (SomeWatcherState (PrVerifyingReviewFix config evidence (WorkerIdle _oldWorker) (ReviewerIdle _oldReviewer))) (PrReviewThreadsRefreshed workerThread reviewerThread) =
  Right (SomeWatcherState (PrVerifyingReviewFix config evidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread)), [])
applyEvent (SomeWatcherState state@PlanningReady {}) (IssuePlanningTurnStarted plannerThread turnId) =
  fromDecision (step state (StartPlanningTurn (ActiveTurn plannerThread turnId)))
applyEvent (SomeWatcherState state@PlanningTurnActive {}) (IssuePlanningIssuesRequested requests) =
  fromDecision (step state (PlannerRequestedIssueCreation requests))
applyEvent (SomeWatcherState state@PlanningTurnActive {}) (IssuePlanningGraphUpdated graph) =
  case state of
    PlanningTurnActive config _activeTurn ->
      case validatePlanningGraphForReplay config graph of
        Left reason -> Left reason
        Right () -> fromDecision (step state (PlannerUpdatedGraph graph))
applyEvent (SomeWatcherState state@PlanningWaitingForReadyIssues {}) IssuePlanningReadyIssuesFixed =
  fromDecision (step state PlannerReadyIssuesFixed)
applyEvent (SomeWatcherState state@PlanningReady {}) IssuePlanningScopeCompleted =
  fromDecision (step state PlannerScopeCompleted)
applyEvent (SomeWatcherState state@PlanningTurnActive {}) (IssuePlanningTurnRetryRequested reason) =
  fromDecision (step state (PlannerTurnRetryRequested reason))
applyEvent (SomeWatcherState state@PlanningTurnActive {}) IssuePlanningTurnCompleted =
  fromDecision (step state PlannerTurnCompleted)
applyEvent (SomeWatcherState state@(PrCheckingReviews _config (WorkerIdle workerThread) _reviewer)) (PrReviewUnresolvedFound threadIds commit turnId) =
  fromDecision (step state (ReviewThreadsFound (reviewEvidenceFromThreads threadIds commit) (ActiveTurn workerThread turnId)))
applyEvent (SomeWatcherState state@(PrCheckingReviews _config (WorkerIdle workerThread) _reviewer)) (PrReviewFeedbackFound evidence turnId) =
  applyPrReviewFeedbackFound state evidence workerThread turnId
applyEvent (SomeWatcherState state@(PrReviewFixQueued _config _storedEvidence (WorkerIdle workerThread) _reviewer)) (PrReviewFeedbackFound evidence turnId) =
  applyPrReviewFeedbackFound state evidence workerThread turnId
applyEvent (SomeWatcherState state@(PrCheckingReviews _config _worker (ReviewerIdle reviewerThread))) (PrReviewNoUnresolvedFound commit turnId) =
  fromDecision (step state (NoReviewThreadsFound commit (ActiveTurn reviewerThread turnId)))
applyEvent (SomeWatcherState state@(PrVerifyingReviewFix _config _storedEvidence (WorkerIdle workerThread) _reviewer)) (PrReviewUnresolvedFound threadIds commit turnId) =
  fromDecision (step state (ReviewThreadsFound (reviewEvidenceFromThreads threadIds commit) (ActiveTurn workerThread turnId)))
applyEvent (SomeWatcherState state@(PrVerifyingReviewFix _config _storedEvidence (WorkerIdle workerThread) _reviewer)) (PrReviewFeedbackFound evidence turnId) =
  applyPrReviewFeedbackFound state evidence workerThread turnId
applyEvent (SomeWatcherState state@(PrVerifyingReviewFix _config _storedEvidence _worker (ReviewerIdle reviewerThread))) (PrReviewNoUnresolvedFound commit turnId) =
  fromDecision (step state (NoReviewThreadsFound commit (ActiveTurn reviewerThread turnId)))
applyEvent (SomeWatcherState state@(PrVerifyingReviewFix _config _storedEvidence _worker (ReviewerIdle reviewerThread))) (PrReviewFixVerificationStarted _eventEvidence reviewTargetSha turnId) =
  fromDecision (step state (StartReviewFixVerification reviewTargetSha (ActiveTurn reviewerThread turnId)))
applyEvent (SomeWatcherState state@PrFixingReviews {}) PrReviewFixCompleted =
  fromDecision (step state ReviewFixCompleted)
applyEvent (SomeWatcherState state@PrFixingReviews {}) (PrReviewFixIncomplete _reason) =
  fromDecision (step state ReviewFixIncomplete)
applyEvent (SomeWatcherState state@PrReviewingClean {}) (PrReviewCleanFound evidence resolvedThreadIds) =
  fromDecision (step state (ReviewerFoundClean evidence resolvedThreadIds))
applyEvent (SomeWatcherState state@PrReviewingClean {}) (PrReviewProblemsAdded evidence resolvedThreadIds) =
  fromDecision (step state (ReviewerFoundProblems evidence resolvedThreadIds))
applyEvent (SomeWatcherState state@PrReviewingClean {}) (PrReviewReviewIncomplete _reason) =
  fromDecision (step state ReviewerTurnIncomplete)
applyEvent (SomeWatcherState state@PrWaitingForMergeability {}) event@(PrReviewMergeabilityClean commitSha) =
  case state of
    PrWaitingForMergeability _config evidence _worker _reviewer
      | cleanReviewCommit evidence == commitSha ->
          fromDecision (step state MergeabilityClean)
      | otherwise ->
          Left ("event " <> eventName event <> " does not match reviewed commit")
applyEvent (SomeWatcherState state@PrWaitingForMergeability {}) (PrReviewMergeabilityWaiting reason) =
  fromDecision (step state (MergeabilityRetryLater reason))
applyEvent (SomeWatcherState state@PrWaitingForMergeability {}) (PrReviewMergeabilityRecheck reason) =
  fromDecision (step state (MergeabilityRecheckReviews reason))
applyEvent (SomeWatcherState state@PrWaitingForMergeability {}) (PrReviewMergeabilityFixRequired evidence) =
  fromDecision (step state (MergeabilityFixRequired evidence))
applyEvent (SomeWatcherState state@PrMerging {}) (PrReviewMergeCompleted mergeCommit) =
  fromDecision (step state (MergeCompleted mergeCommit))
applyEvent (SomeWatcherState state@(IssueReadyToPlan _config _prNumber (WorkerIdle threadId))) (IssuePlanTurnStartedEvent turnId) =
  fromDecision (step state (StartReadyIssuePlanTurn (ActiveTurn threadId turnId)))
applyEvent (SomeWatcherState state@IssueReadyToPlan {}) (IssueWorkerThreadRefreshed threadId) =
  fromDecision (step state (IssueWorkerThreadReady threadId))
applyEvent (SomeWatcherState state@(IssueInPlanMode _config _prNumber (WorkerActive activeTurn))) (IssuePlanCompletedEvent planMarkdown turnId) =
  fromDecision (step state (IssuePlanCompleted planMarkdown (ActiveTurn (activeThreadId activeTurn) <$> turnId)))
applyEvent (SomeWatcherState state@IssuePlanReady {}) (IssueWorkerThreadRefreshed threadId) =
  fromDecision (step state (IssueWorkerThreadReady threadId))
applyEvent (SomeWatcherState state@IssueImplementationReady {}) (IssueWorkerThreadRefreshed threadId) =
  fromDecision (step state (IssueWorkerThreadReady threadId))
applyEvent (SomeWatcherState state@IssueImplementationReady {}) (IssueAttemptBranchAdvancedEvent branch) =
  fromDecision (step state (IssueAttemptBranchAdvanced branch))
applyEvent (SomeWatcherState state@IssueHandoffReady {}) (IssueReviewerThreadReadyEvent threadId) =
  fromDecision (step state (IssueReviewerThreadReady threadId))
applyEvent (SomeWatcherState state@IssueHandoffInitialized {}) (IssueReviewerThreadReadyEvent threadId) =
  fromDecision (step state (IssueReviewerThreadReady threadId))
applyEvent (SomeWatcherState state@IssueWaitingForPrMerge {}) (IssueReviewerThreadReadyEvent threadId) =
  fromDecision (step state (IssueReviewerThreadReady threadId))
applyEvent (SomeWatcherState state@IssuePostMergeReviewPendingReviewer {}) (IssueReviewerThreadReadyEvent threadId) =
  fromDecision (step state (IssueReviewerThreadReady threadId))
applyEvent (SomeWatcherState state@IssuePostMergeReviewReady {}) (IssueReviewerThreadReadyEvent threadId) =
  fromDecision (step state (IssueReviewerThreadReady threadId))
applyEvent (SomeWatcherState state@(IssueImplementationReady _config _maybePr _worker)) (IssuePullRequestCreatedEvent prNumber) =
  fromDecision (step state (IssuePullRequestReady prNumber))
applyEvent (SomeWatcherState state@(IssueImplementationReady _config _maybePr _worker)) (IssuePullRequestReusedEvent prNumber) =
  fromDecision (step state (IssuePullRequestReady prNumber))
applyEvent (SomeWatcherState state@(IssueImplementing _config _maybePr _worker)) (IssuePullRequestCreatedEvent prNumber) =
  fromDecision (step state (IssuePullRequestReady prNumber))
applyEvent (SomeWatcherState state@(IssueImplementing _config _maybePr _worker)) (IssuePullRequestReusedEvent prNumber) =
  fromDecision (step state (IssuePullRequestReady prNumber))
applyEvent (SomeWatcherState state@(IssuePlanReady _config expectedPrNumber _worker)) event@(IssuePullRequestBodyUpdatedEvent prNumber)
  | expectedPrNumber == prNumber =
      fromDecision (step state (IssuePullRequestBodyUpdated prNumber))
  | otherwise =
      Left ("event " <> eventName event <> " does not match a known PR")
applyEvent (SomeWatcherState state@(IssueImplementationReady _config maybePr _worker)) event@(IssuePullRequestBodyUpdatedEvent prNumber)
  | maybePr == Just prNumber =
      fromDecision (step state (IssuePullRequestBodyUpdated prNumber))
  | otherwise =
      Left ("event " <> eventName event <> " does not match a known PR")
applyEvent (SomeWatcherState state@(IssueImplementing _config maybePr _worker)) event@(IssuePullRequestBodyUpdatedEvent prNumber)
  | maybePr == Just prNumber =
      fromDecision (step state (IssuePullRequestBodyUpdated prNumber))
  | otherwise =
      Left ("event " <> eventName event <> " does not match a known PR")
applyEvent (SomeWatcherState state@(IssueImplementationReady _config _maybePr (WorkerIdle threadId))) (IssueImplementationTurnStartedEvent turnId) =
  fromDecision (step state (StartIssueImplementationTurn (ActiveTurn threadId turnId)))
applyEvent (SomeWatcherState state@(IssueImplementing _config _maybePr _worker)) (IssueImplementationIncompleteEvent _reason) =
  fromDecision (step state IssueImplementationIncomplete)
applyEvent (SomeWatcherState state@IssueHandoffReady {}) (IssueReviewHandoffInitializedEvent prNumber) =
  fromDecision (step state (IssueReviewHandoffInitialized prNumber))
applyEvent (SomeWatcherState state@IssueHandoffInitialized {}) (IssueReviewHandoffInitializedEvent prNumber) =
  fromDecision (step state (IssueReviewHandoffInitialized prNumber))
applyEvent (SomeWatcherState state@IssueHandoffInitialized {}) (IssueReviewHandoffStartedEvent prNumber) =
  fromDecision (step state (IssueReviewHandoffStarted prNumber))
applyEvent (SomeWatcherState state@IssueWaitingForPrMerge {}) (IssueReviewHandoffInitializedEvent prNumber) =
  fromDecision (step state (IssueReviewHandoffInitialized prNumber))
applyEvent (SomeWatcherState state@IssueWaitingForPrMerge {}) (IssueReviewHandoffStartedEvent prNumber) =
  fromDecision (step state (IssueReviewHandoffStarted prNumber))
applyEvent (SomeWatcherState state@IssueImplementationReady {}) (IssueImplementationBlockedEvent reason) =
  fromDecision (step state (MarkBlocked reason))
applyEvent (SomeWatcherState state@IssueImplementing {}) (IssueImplementationBlockedEvent reason) =
  fromDecision (step state (MarkBlocked reason))
applyEvent (SomeWatcherState state@IssueHandoffReady {}) (IssueImplementationBlockedEvent reason) =
  fromDecision (step state (MarkBlocked reason))
applyEvent (SomeWatcherState state@IssueHandoffInitialized {}) (IssueImplementationBlockedEvent reason) =
  fromDecision (step state (MarkBlocked reason))
applyEvent (SomeWatcherState state@IssueWaitingForPrMerge {}) (IssueImplementationBlockedEvent reason) =
  fromDecision (step state (MarkBlocked reason))
applyEvent (SomeWatcherState state@(IssueImplementing _config _maybePr _worker)) (IssueImplementationCompletedEvent prNumber maybeReviewerThreadId) =
  fromDecision (step state (IssueImplementationCompleted prNumber maybeReviewerThreadId))
applyEvent (SomeWatcherState state@IssueHandoffReady {}) (IssueImplementationCompletedEvent prNumber maybeReviewerThreadId) =
  fromDecision (step state (IssueImplementationCompleted prNumber maybeReviewerThreadId))
applyEvent (SomeWatcherState state@IssueHandoffInitialized {}) (IssueImplementationCompletedEvent prNumber maybeReviewerThreadId) =
  fromDecision (step state (IssueImplementationCompleted prNumber maybeReviewerThreadId))
applyEvent (SomeWatcherState state@IssueWaitingForPrMerge {}) (IssueImplementationCompletedEvent prNumber maybeReviewerThreadId) =
  fromDecision (step state (IssueImplementationCompleted prNumber maybeReviewerThreadId))
applyEvent (SomeWatcherState state@IssueImplementationReady {}) (IssuePullRequestMergedEvent prNumber) =
  fromDecision (step state (IssuePullRequestMerged prNumber))
applyEvent (SomeWatcherState state@IssueImplementing {}) (IssuePullRequestMergedEvent prNumber) =
  fromDecision (step state (IssuePullRequestMerged prNumber))
applyEvent (SomeWatcherState state@IssueHandoffReady {}) (IssuePullRequestMergedEvent prNumber) =
  fromDecision (step state (IssuePullRequestMerged prNumber))
applyEvent (SomeWatcherState state@IssueHandoffInitialized {}) (IssuePullRequestMergedEvent prNumber) =
  fromDecision (step state (IssuePullRequestMerged prNumber))
applyEvent (SomeWatcherState state@IssueWaitingForPrMerge {}) (IssuePullRequestMergedEvent prNumber) =
  fromDecision (step state (IssuePullRequestMerged prNumber))
applyEvent (SomeWatcherState state@IssuePostMergeReviewPendingReviewer {}) (IssuePullRequestMergedEvent prNumber) =
  fromDecision (step state (IssuePullRequestMerged prNumber))
applyEvent (SomeWatcherState state@IssuePostMergeReviewReady {}) (IssuePullRequestMergedEvent prNumber) =
  fromDecision (step state (IssuePullRequestMerged prNumber))
applyEvent (SomeWatcherState state@IssuePostMergeReviewing {}) (IssuePullRequestMergedEvent prNumber) =
  fromDecision (step state (IssuePullRequestMerged prNumber))
applyEvent (SomeWatcherState state@IssueWaitingForIssueClose {}) (IssuePullRequestMergedEvent prNumber) =
  fromDecision (step state (IssuePullRequestMerged prNumber))
applyEvent (SomeWatcherState state@(IssuePostMergeReviewReady _config _prNumber _worker (ReviewerIdle reviewerThread))) (IssuePostMergeReviewStartedEvent commit turnId) =
  fromDecision (step state (StartIssuePostMergeReview commit (ActiveTurn reviewerThread turnId)))
applyEvent (SomeWatcherState state@IssuePostMergeReviewing {}) (IssuePostMergeReviewCleanEvent evidence) =
  fromDecision (step state (IssuePostMergeReviewSatisfied evidence))
applyEvent (SomeWatcherState state@IssuePostMergeReviewing {}) (IssuePostMergeReviewFollowUpEvent evidence) =
  fromDecision (step state (IssuePostMergeReviewFollowUp evidence))
applyEvent (SomeWatcherState state@IssuePostMergeReviewing {}) (IssuePostMergeReviewIncompleteEvent reason) =
  fromDecision (step state (IssuePostMergeReviewIncomplete reason))
applyEvent (SomeWatcherState state@IssueWaitingForIssueClose {}) (IssueClosedEvent prNumber) =
  fromDecision (step state (IssueClosed prNumber))
applyEvent (SomeWatcherState state) (WatcherRecoveredInvalidState _reason) =
  Right (SomeWatcherState state, [])
applyEvent (SomeWatcherState state) (WatcherBlocked reason) =
  Right (blockSameDomain state reason, [SomeEffect (RecordBlocked reason), SomeEffect StopDaemon])
applyEvent (SomeWatcherState state) (WatcherStopped reason) =
  Right (stopSameDomain state reason, [SomeEffect StopDaemon])
applyEvent state event =
  Left ("event " <> eventName event <> " is invalid in " <> Text.pack (show (someDomain state)) <> "/" <> Text.pack (show (somePhase state)))

terminalEvent :: SomeWatcherState -> WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
terminalEvent state event =
  case event of
    WatcherStopped reason ->
      case state of
        SomeWatcherState typedState -> Right (stopSameDomain typedState reason, [SomeEffect StopDaemon])
    _ ->
      Left ("event " <> eventName event <> " cannot run after terminal phase " <> Text.pack (show (somePhase state)))

fromDecision :: KnownDomain domain => Decision domain -> Either Text (SomeWatcherState, EffectPlan)
fromDecision (Decision state effects) = Right (SomeWatcherState state, effects)

applyPrReviewFeedbackFound :: WatcherState 'PrReview 'CheckingReviews -> ReviewEvidence -> ThreadId -> TurnId -> Either Text (SomeWatcherState, EffectPlan)
applyPrReviewFeedbackFound state evidence workerThread turnId =
  fromDecision (step state (ReviewThreadsFound evidence (ActiveTurn workerThread turnId)))

blockSameDomain :: forall domain phase. KnownDomain domain => WatcherState domain phase -> BlockedReason -> SomeWatcherState
blockSameDomain _ reason = SomeWatcherState (BlockedState reason :: WatcherState domain 'Blocked)

stopSameDomain :: forall domain phase. KnownDomain domain => WatcherState domain phase -> StopReason -> SomeWatcherState
stopSameDomain _ reason = SomeWatcherState (StoppedState reason :: WatcherState domain 'Stopped)

validatePlanningGraphForReplay :: PlannerConfig -> PlanningGraph -> Either Text ()
validatePlanningGraphForReplay config graph
  | hasDuplicate graph.planningReadyIssues =
      Left "planning graph has duplicate ready issues"
  | hasDuplicate blockedIssues =
      Left "planning graph has duplicate blocked issues"
  | not (null (graph.planningReadyIssues `intersect` blockedIssues)) =
      Left "planning graph marks an issue as both ready and blocked"
  | any readyIssueHasDependency graph.planningDependencies =
      Left "planning graph marks a dependent issue as ready"
  | Just issue <- outOfScopeIssue =
      Left ("planning graph references issue outside configured scope: #" <> Text.pack (show (unIssueNumber issue)))
  | otherwise =
      Right ()
 where
  blockedIssues = fmap blockedPlanningIssue graph.planningBlockedIssues
  graphIssues = planningGraphIssues graph
  outOfScopeIssue =
    case plannerScopeIssues config of
      [] -> Nothing
      scopeIssues -> find (`notElem` scopedGraphClosure scopeIssues graph) graphIssues
  readyIssueHasDependency dependency =
    dependency.dependencyIssue `elem` graph.planningReadyIssues && not (null dependency.dependencyDependsOn)

hasDuplicate :: Eq a => [a] -> Bool
hasDuplicate [] = False
hasDuplicate (item : rest) = item `elem` rest || hasDuplicate rest
