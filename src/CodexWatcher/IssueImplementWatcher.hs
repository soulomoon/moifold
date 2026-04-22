{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.IssueImplementWatcher
  ( IssueImplementObservation (..)
  , IssueImplementTick (..)
  , issueImplementObserve
  ) where

import CodexWatcher.Effects
import CodexWatcher.EventLog
import CodexWatcher.Observation
import CodexWatcher.StateMachine
import CodexWatcher.Types
import Data.Text (Text)

data IssueImplementObservation
  = ObservedTriageTurnStarted TurnId
  | ObservedTriageAlreadyFixed
  | ObservedTriageNeedsImplementation
  | ObservedTriageBlocked BlockedReason
  | ObservedPlanTurnStarted TurnId
  | ObservedPlanCompleted (Maybe TurnId)
  | ObservedPullRequestCreated PrNumber
  | ObservedPullRequestReused PrNumber
  | ObservedImplementationTurnStarted TurnId
  | ObservedImplementationIncomplete Text
  | ObservedImplementationBlocked BlockedReason
  | ObservedReviewHandoffInitialized PrNumber
  | ObservedReviewHandoffStarted PrNumber
  | ObservedImplementationCompleted PrNumber
  | ObservedPullRequestMerged PrNumber
  | ObservedIssueImplementBlocked BlockedReason
  deriving stock (Eq, Show)

data IssueImplementTick = IssueImplementTick
  { issueImplementTickEvent :: WatcherEvent
  , issueImplementTickState :: SomeWatcherState
  , issueImplementTickEffects :: EffectPlan
  }
  deriving stock (Show)

issueImplementObserve :: SomeWatcherState -> IssueImplementObservation -> Either Text IssueImplementTick
issueImplementObserve (SomeWatcherState state@(IssueNeedsTriage _config (WorkerIdle threadId))) (ObservedTriageTurnStarted turnId) =
  Right (tick (IssueTriageTurnStartedEvent turnId) (step state (StartIssueTriageTurn (ActiveTurn threadId turnId))))
issueImplementObserve (SomeWatcherState state@IssueTriageActive {}) ObservedTriageAlreadyFixed =
  Right (tick IssueTriageAlreadyFixedEvent (step state IssueTriageAlreadyFixed))
issueImplementObserve (SomeWatcherState state@IssueTriageActive {}) ObservedTriageNeedsImplementation =
  Right (tick IssueTriageNeedsImplementationEvent (step state IssueTriageNeedsImplementation))
issueImplementObserve (SomeWatcherState state@IssueTriageActive {}) (ObservedTriageBlocked reason) =
  Right (tick (IssueTriageBlockedEvent reason) (step state (IssueTriageBlocked reason)))
issueImplementObserve (SomeWatcherState state@(IssueNeedsTriage _config (WorkerIdle threadId))) (ObservedPlanTurnStarted turnId) =
  Right (tick (IssuePlanTurnStartedEvent turnId) (step state (StartIssuePlanTurn (ActiveTurn threadId turnId))))
issueImplementObserve (SomeWatcherState state@(IssueTriageActive {})) (ObservedPlanTurnStarted turnId) =
  Right (tick (IssuePlanTurnStartedEvent turnId) (step state (StartIssuePlanTurn (ActiveTurn (activeThreadIdFromTriage state) turnId))))
issueImplementObserve (SomeWatcherState state@(IssuePlanReady _config (WorkerIdle threadId))) (ObservedPlanTurnStarted turnId) =
  Right (tick (IssuePlanTurnStartedEvent turnId) (step state (StartReadyIssuePlanTurn (ActiveTurn threadId turnId))))
issueImplementObserve (SomeWatcherState state@(IssueInPlanMode _config (WorkerActive activeTurn))) (ObservedPlanCompleted maybeImplementationTurnId) =
  let nextTurn = ActiveTurn (activeThreadId activeTurn) <$> maybeImplementationTurnId
   in Right (tick (IssuePlanCompletedEvent maybeImplementationTurnId) (step state (IssuePlanCompleted nextTurn)))
issueImplementObserve (SomeWatcherState state@(IssuePlanReady _config (WorkerIdle threadId))) (ObservedPlanCompleted maybeImplementationTurnId) =
  let nextTurn = ActiveTurn threadId <$> maybeImplementationTurnId
   in Right (tick (IssuePlanCompletedEvent maybeImplementationTurnId) (step state (IssuePlanCompleted nextTurn)))
issueImplementObserve (SomeWatcherState state@IssueImplementationReady {}) (ObservedPullRequestCreated prNumber) =
  Right (tick (IssuePullRequestCreatedEvent prNumber) (step state (IssuePullRequestReady prNumber)))
issueImplementObserve (SomeWatcherState state@IssueImplementationReady {}) (ObservedPullRequestReused prNumber) =
  Right (tick (IssuePullRequestReusedEvent prNumber) (step state (IssuePullRequestReady prNumber)))
issueImplementObserve (SomeWatcherState state@(IssueImplementationReady _config _maybePr (WorkerIdle threadId))) (ObservedImplementationTurnStarted turnId) =
  Right (tick (IssueImplementationTurnStartedEvent turnId) (step state (StartIssueImplementationTurn (ActiveTurn threadId turnId))))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedImplementationIncomplete reason) =
  Right (tick (IssueImplementationIncompleteEvent reason) (step state IssueImplementationIncomplete))
issueImplementObserve (SomeWatcherState state@IssueImplementationReady {}) (ObservedImplementationBlocked reason) =
  Right (tick (IssueImplementationBlockedEvent reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedImplementationBlocked reason) =
  Right (tick (IssueImplementationBlockedEvent reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueImplementationReady {}) (ObservedReviewHandoffInitialized prNumber) =
  Right (tick (IssueReviewHandoffInitializedEvent prNumber) (step state (IssueReviewHandoffInitialized prNumber)))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedReviewHandoffInitialized prNumber) =
  Right (tick (IssueReviewHandoffInitializedEvent prNumber) (step state (IssueReviewHandoffInitialized prNumber)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForPrMerge {}) (ObservedReviewHandoffInitialized prNumber) =
  Right (tick (IssueReviewHandoffInitializedEvent prNumber) (step state (IssueReviewHandoffInitialized prNumber)))
issueImplementObserve (SomeWatcherState state@IssueImplementationReady {}) (ObservedReviewHandoffStarted prNumber) =
  Right (tick (IssueReviewHandoffStartedEvent prNumber) (step state (IssueReviewHandoffStarted prNumber)))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedReviewHandoffStarted prNumber) =
  Right (tick (IssueReviewHandoffStartedEvent prNumber) (step state (IssueReviewHandoffStarted prNumber)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForPrMerge {}) (ObservedReviewHandoffStarted prNumber) =
  Right (tick (IssueReviewHandoffStartedEvent prNumber) (step state (IssueReviewHandoffStarted prNumber)))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedImplementationCompleted prNumber) =
  Right (tick (IssueImplementationCompletedEvent prNumber) (step state (IssueImplementationCompleted prNumber)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForPrMerge {}) (ObservedImplementationCompleted prNumber) =
  Right (tick (IssueImplementationCompletedEvent prNumber) (step state (IssueImplementationCompleted prNumber)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForPrMerge {}) (ObservedPullRequestMerged prNumber) =
  Right (tick (IssuePullRequestMergedEvent prNumber) (step state (IssuePullRequestMerged prNumber)))
issueImplementObserve (SomeWatcherState state@IssueNeedsTriage {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueTriageActive {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssuePlanReady {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueInPlanMode {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueImplementationReady {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForPrMerge {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve state observation =
  invalidObservation "issue implementation observation" state observation

tick :: WatcherEvent -> Decision 'IssueImplement -> IssueImplementTick
tick event decision =
  fromObservedTick (observedFromDecision event decision)

fromObservedTick :: ObservedTick -> IssueImplementTick
fromObservedTick observed =
  IssueImplementTick
    { issueImplementTickEvent = observed.observedEvent
    , issueImplementTickState = observed.observedState
    , issueImplementTickEffects = observed.observedEffects
    }

activeThreadIdFromTriage :: WatcherState 'IssueImplement 'Triage -> ThreadId
activeThreadIdFromTriage (IssueTriageActive _config (WorkerActive activeTurn)) = activeThreadId activeTurn
activeThreadIdFromTriage (IssueNeedsTriage _config (WorkerIdle threadId)) = threadId
