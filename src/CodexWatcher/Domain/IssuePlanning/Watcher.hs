{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.IssuePlanning.Watcher
  ( IssuePlanningObservation (..)
  , IssuePlanningTick (..)
  , issuePlanningObserve
  , selectIssueImplementationStarts
  ) where

import CodexWatcher.Effects
import CodexWatcher.EventLog.Types
import CodexWatcher.Observation
import CodexWatcher.StateMachine
import CodexWatcher.Types
import Data.List (find, intersect)
import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Data.Text qualified as Text

data IssuePlanningObservation
  = ObservedPlanningTurnStarted ThreadId TurnId
  | ObservedPlanningIssuesRequested (NonEmpty IssueCreationRequest)
  | ObservedPlanningGraphUpdated PlanningGraph
  | ObservedPlanningReadyIssuesFixed
  | ObservedPlanningScopeCompleted
  | ObservedPlanningTurnRetryRequested BlockedReason
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
issuePlanningObserve (SomeWatcherState state@PlanningTurnActive {}) (ObservedPlanningIssuesRequested requests) =
  Right (tick (IssuePlanningIssuesRequested requests) (step state (PlannerRequestedIssueCreation requests)))
issuePlanningObserve (SomeWatcherState state@PlanningTurnActive {}) (ObservedPlanningGraphUpdated graph) =
  case state of
    PlanningTurnActive config _activeTurn ->
      case validatePlanningGraph config graph of
        Left reason -> Right (tick (WatcherBlocked (BlockedReason reason)) (step state (MarkBlocked (BlockedReason reason))))
        Right () -> Right (tick (IssuePlanningGraphUpdated graph) (step state (PlannerUpdatedGraph graph)))
issuePlanningObserve (SomeWatcherState state@PlanningWaitingForReadyIssues {}) ObservedPlanningReadyIssuesFixed =
  Right (tick IssuePlanningReadyIssuesFixed (step state PlannerReadyIssuesFixed))
issuePlanningObserve (SomeWatcherState state@PlanningReady {}) ObservedPlanningScopeCompleted =
  Right (tick IssuePlanningScopeCompleted (step state PlannerScopeCompleted))
issuePlanningObserve (SomeWatcherState state@PlanningTurnActive {}) (ObservedPlanningTurnRetryRequested reason) =
  Right (tick (IssuePlanningTurnRetryRequested reason) (step state (PlannerTurnRetryRequested reason)))
issuePlanningObserve (SomeWatcherState state@PlanningTurnActive {}) ObservedPlanningTurnCompleted =
  Right (tick IssuePlanningTurnCompleted (step state PlannerTurnCompleted))
issuePlanningObserve (SomeWatcherState state@PlanningReady {}) (ObservedPlanningBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issuePlanningObserve (SomeWatcherState state@PlanningTurnActive {}) (ObservedPlanningBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issuePlanningObserve (SomeWatcherState state@PlanningWaitingForReadyIssues {}) (ObservedPlanningBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issuePlanningObserve state observation =
  invalidObservation "issue planning observation" state observation

selectIssueImplementationStarts :: PlannerConfig -> [IssueNumber] -> [IssueNumber] -> [IssueNumber]
selectIssueImplementationStarts config activeIssues openIssues =
  take availableCapacity (filter (`notElem` activeIssues) openIssues)
 where
  availableCapacity = max 0 (unMaxParallel (plannerMaxParallel config) - length activeIssues)

validatePlanningGraph :: PlannerConfig -> PlanningGraph -> Either Text ()
validatePlanningGraph config graph
  | Just issue <- firstDuplicate graph.planningReadyIssues =
      Left ("planning graph has duplicate ready issue #" <> issueText issue)
  | Just issue <- firstDuplicate blockedIssues =
      Left ("planning graph has duplicate blocked issue #" <> issueText issue)
  | Just issue <- firstDuplicate dependencyIssues =
      Left ("planning graph has duplicate dependency entry for issue #" <> issueText issue)
  | firstOverlap : _ <- readyBlockedOverlap =
      Left ("planning graph marks issue #" <> issueText firstOverlap <> " as both ready and blocked")
  | Just dependency <- find readyIssueHasDependency graph.planningDependencies =
      Left ("planning graph marks issue #" <> issueText dependency.dependencyIssue <> " ready while it still depends on " <> issueListText dependency.dependencyDependsOn)
  | Just issue <- outOfScopeIssue =
      Left ("planning graph references issue #" <> issueText issue <> " outside configured scope")
  | otherwise =
      Right ()
 where
  blockedIssues = fmap blockedPlanningIssue graph.planningBlockedIssues
  dependencyIssues = fmap dependencyIssue graph.planningDependencies
  dependencyRefs = concatMap dependencyDependsOn graph.planningDependencies
  graphIssues = graph.planningReadyIssues <> blockedIssues <> dependencyIssues <> dependencyRefs
  outOfScopeIssue =
    case plannerScopeIssues config of
      [] -> Nothing
      scopeIssues -> find (`notElem` scopeIssues) graphIssues
  readyBlockedOverlap = graph.planningReadyIssues `intersect` blockedIssues
  readyIssueHasDependency dependency =
    dependency.dependencyIssue `elem` graph.planningReadyIssues && not (null dependency.dependencyDependsOn)

firstDuplicate :: Eq a => [a] -> Maybe a
firstDuplicate [] = Nothing
firstDuplicate (item : rest)
  | item `elem` rest = Just item
  | otherwise = firstDuplicate rest

issueText :: IssueNumber -> Text
issueText =
  Text.pack . show . unIssueNumber

issueListText :: [IssueNumber] -> Text
issueListText issues =
  Text.intercalate ", " (fmap (("#" <>) . issueText) issues)

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
