{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.IssuePlanningWatcher
  ( IssuePlanningObservation (..)
  , IssuePlanningTick (..)
  , issuePlanningObserve
  , selectIssueImplementationStarts
  ) where

import CodexWatcher.Effects
import CodexWatcher.EventLog
import CodexWatcher.Observation
import CodexWatcher.StateMachine
import CodexWatcher.Types
import Data.Text (Text)

data IssuePlanningObservation
  = ObservedPlanningTurnStarted ThreadId TurnId
  | ObservedPlanningIssuesRequested [IssueCreationRequest]
  | ObservedPlanningGraphUpdated PlanningGraph
  | ObservedPlanningReadyIssuesFixed
  | ObservedPlanningTurnCompleted
  | ObservedPlanningBlocked BlockedReason
  deriving stock (Eq, Show)

data IssuePlanningTick = IssuePlanningTick
  { issuePlanningTickEvent :: WatcherEvent
  , issuePlanningTickState :: SomeWatcherState
  , issuePlanningTickEffects :: EffectPlan
  }
  deriving stock (Show)

issuePlanningObserve :: SomeWatcherState -> IssuePlanningObservation -> Either Text IssuePlanningTick
issuePlanningObserve (SomeWatcherState state@PlanningReady {}) (ObservedPlanningTurnStarted threadId turnId) =
  Right (tick (IssuePlanningTurnStarted threadId turnId) (step state (StartPlanningTurn (ActiveTurn threadId turnId))))
issuePlanningObserve (SomeWatcherState state@PlanningTurnActive {}) (ObservedPlanningIssuesRequested requests)
  | null requests =
      Left "issue planning issue creation observation must include at least one issue"
  | otherwise =
      Right (tick (IssuePlanningIssuesRequested requests) (step state (PlannerRequestedIssueCreation requests)))
issuePlanningObserve (SomeWatcherState state@PlanningTurnActive {}) (ObservedPlanningGraphUpdated graph) =
  Right (tick (IssuePlanningGraphUpdated graph) (step state (PlannerUpdatedGraph graph)))
issuePlanningObserve (SomeWatcherState state@PlanningWaitingForReadyIssues {}) ObservedPlanningReadyIssuesFixed =
  Right (tick IssuePlanningReadyIssuesFixed (step state PlannerReadyIssuesFixed))
issuePlanningObserve (SomeWatcherState state@PlanningTurnActive {}) ObservedPlanningTurnCompleted =
  Right (tick IssuePlanningTurnCompleted (step state PlannerTurnCompleted))
issuePlanningObserve (SomeWatcherState state@PlanningReady {}) (ObservedPlanningBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issuePlanningObserve (SomeWatcherState state@PlanningTurnActive {}) (ObservedPlanningBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issuePlanningObserve state observation =
  invalidObservation "issue planning observation" state observation

selectIssueImplementationStarts :: PlannerConfig -> [IssueNumber] -> [IssueNumber] -> [IssueNumber]
selectIssueImplementationStarts config activeIssues openIssues =
  take availableCapacity (filter (`notElem` activeIssues) openIssues)
 where
  availableCapacity = max 0 (plannerMaxParallel config - length activeIssues)

tick :: WatcherEvent -> Decision 'IssuePlanning -> IssuePlanningTick
tick event decision =
  fromObservedTick (observedFromDecision event decision)

fromObservedTick :: ObservedTick -> IssuePlanningTick
fromObservedTick observed =
  IssuePlanningTick
    { issuePlanningTickEvent = observed.observedEvent
    , issuePlanningTickState = observed.observedState
    , issuePlanningTickEffects = observed.observedEffects
    }
