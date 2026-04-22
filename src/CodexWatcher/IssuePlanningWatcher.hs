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
import CodexWatcher.StateMachine
import CodexWatcher.Types
import Data.Text (Text)
import Data.Text qualified as Text

data IssuePlanningObservation
  = ObservedPlanningTurnStarted ThreadId TurnId
  | ObservedPlanningTurnCompleted
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
issuePlanningObserve (SomeWatcherState state@PlanningTurnActive {}) ObservedPlanningTurnCompleted =
  Right (tick IssuePlanningTurnCompleted (step state PlannerTurnCompleted))
issuePlanningObserve state observation =
  Left
    ( "issue planning observation "
        <> Text.pack (show observation)
        <> " is invalid in "
        <> Text.pack (show (someDomain state))
        <> "/"
        <> Text.pack (show (somePhase state))
    )

selectIssueImplementationStarts :: PlannerConfig -> [IssueNumber] -> [IssueNumber] -> [IssueNumber]
selectIssueImplementationStarts config activeIssues openIssues =
  take availableCapacity (filter (`notElem` activeIssues) openIssues)
 where
  availableCapacity = max 0 (plannerMaxParallel config - length activeIssues)

tick :: WatcherEvent -> Decision 'IssuePlanning -> IssuePlanningTick
tick event (Decision state effects) =
  IssuePlanningTick
    { issuePlanningTickEvent = event
    , issuePlanningTickState = SomeWatcherState state
    , issuePlanningTickEffects = effects
    }
