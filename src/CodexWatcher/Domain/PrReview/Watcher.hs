{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.PrReview.Watcher
  ( PrReviewObservation (..)
  , PrReviewTick (..)
  , prReviewObserve
  ) where

import CodexWatcher.Effects
import CodexWatcher.EventLog
import CodexWatcher.GhGit
import CodexWatcher.Observation
import CodexWatcher.Domain.PrReview.Protocol
import CodexWatcher.StateMachine
import CodexWatcher.Types
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)

data PrReviewObservation
  = ObservedReviewThreads ReviewThreadsReport CommitSha TurnId
  | ObservedWorkerOutcome WorkerOutcome
  | ObservedReviewerOutcome ReviewerOutcome
  | ObservedMergeabilityClean CommitSha
  | ObservedMergeabilityRetry Text
  | ObservedMergeabilityRecheck Text
  | ObservedMergeCompleted MergeCommit
  | ObservedPrReviewBlocked BlockedReason
  deriving stock (Eq, Show)

data PrReviewTick = PrReviewTick
  { prReviewTickEvent :: WatcherEvent
  , prReviewTickState :: SomeWatcherState
  , prReviewTickEffects :: EffectPlan
  }
  deriving stock (Show)

prReviewObserve :: SomeWatcherState -> PrReviewObservation -> Either Text PrReviewTick
prReviewObserve (SomeWatcherState state@PrCheckingReviews {}) (ObservedReviewThreads report commit turnId) =
  case unresolvedThreadIds report of
    Just threadIds ->
      case state of
        PrCheckingReviews _config (WorkerIdle workerThread) _reviewer ->
          let event = PrReviewUnresolvedFound threadIds commit turnId
              decision = step state (ReviewThreadsFound (ReviewEvidence threadIds commit) (ActiveTurn workerThread turnId))
           in Right (tick event decision)
    Nothing ->
      case state of
        PrCheckingReviews _config _worker (ReviewerIdle reviewerThread) ->
          let event = PrReviewNoUnresolvedFound commit turnId
              decision = step state (NoReviewThreadsFound commit (ActiveTurn reviewerThread turnId))
           in Right (tick event decision)
prReviewObserve (SomeWatcherState state@PrFixingReviews {}) (ObservedWorkerOutcome outcome) =
  case outcome of
    WorkerCompleted ->
      Right (tick PrReviewFixCompleted (step state ReviewFixCompleted))
    WorkerIncomplete reason ->
      Right (tick (PrReviewFixIncomplete reason) (step state ReviewFixIncomplete))
    WorkerBlocked reason ->
      Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrReviewingClean {}) (ObservedReviewerOutcome outcome) =
  case outcome of
    ReviewerClean evidence ->
      Right (tick (PrReviewCleanFound evidence) (step state (ReviewerFoundClean evidence)))
    ReviewerProblemsAdded commit ->
      Right (tick (PrReviewProblemsAdded commit) (step state ReviewerFoundProblems))
    ReviewerIncomplete reason ->
      Right (tick (PrReviewReviewIncomplete reason) (step state ReviewerTurnIncomplete))
    ReviewerBlocked reason ->
      Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrWaitingForMergeability {}) (ObservedMergeabilityClean commitSha) =
  case state of
    PrWaitingForMergeability _config evidence _worker _reviewer
      | cleanReviewCommit evidence == commitSha ->
          Right (tick (PrReviewMergeabilityClean commitSha) (step state MergeabilityClean))
      | otherwise ->
          Left "mergeability clean commit does not match reviewed commit"
prReviewObserve (SomeWatcherState state@PrWaitingForMergeability {}) (ObservedMergeabilityRetry reason) =
  Right (tick (PrReviewMergeabilityWaiting reason) (step state (MergeabilityRetryLater reason)))
prReviewObserve (SomeWatcherState state@PrWaitingForMergeability {}) (ObservedMergeabilityRecheck reason) =
  Right (tick (PrReviewMergeabilityRecheck reason) (step state (MergeabilityRecheckReviews reason)))
prReviewObserve (SomeWatcherState state@PrMerging {}) (ObservedMergeCompleted mergeCommit) =
  Right (tick (PrReviewMergeCompleted mergeCommit) (step state (MergeCompleted mergeCommit)))
prReviewObserve (SomeWatcherState state@PrCheckingReviews {}) (ObservedPrReviewBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrFixingReviews {}) (ObservedPrReviewBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrReviewingClean {}) (ObservedPrReviewBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrWaitingForMergeability {}) (ObservedPrReviewBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrMerging {}) (ObservedPrReviewBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve state observation =
  invalidObservation "PR review observation" state observation

tick :: WatcherEvent -> Decision 'PrReview -> PrReviewTick
tick event decision =
  fromObservedTick (observedFromDecision event decision)

fromObservedTick :: ObservedTick -> PrReviewTick
fromObservedTick observed =
  PrReviewTick
    { prReviewTickEvent = observed.observedEvent
    , prReviewTickState = observed.observedState
    , prReviewTickEffects = observed.observedEffects
    }

unresolvedThreadIds :: ReviewThreadsReport -> Maybe (NonEmpty ReviewThreadId)
unresolvedThreadIds report =
  case fmap reviewThreadId report.unresolvedReviewThreads of
    [] -> Nothing
    first : rest -> Just (first :| rest)
