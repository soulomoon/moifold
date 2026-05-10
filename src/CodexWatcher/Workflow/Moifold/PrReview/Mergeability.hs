{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Workflow.Moifold.PrReview.Mergeability
  ( PrReviewMergeabilityObservation (..)
  , observePrReviewMergeability
  ) where

import CodexWatcher.Observation (ObservedTick, invalidObservation, observedFromDecision)
import CodexWatcher.StateMachine (Event (..), step)
import CodexWatcher.Workflow.GitHub.Ids (CommitSha)
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..))
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), ReviewEvidence)
import CodexWatcher.EventLog.Types (WatcherEvent (..))
import Data.Text (Text)

data PrReviewMergeabilityObservation
  = MergeabilityObservedClean CommitSha
  | MergeabilityObservedRetry Text
  | MergeabilityObservedRecheck Text
  | MergeabilityObservedFixRequired ReviewEvidence
  deriving stock (Eq, Show)

observePrReviewMergeability :: SomeWatcherState -> PrReviewMergeabilityObservation -> Either Text ObservedTick
observePrReviewMergeability (SomeWatcherState state@PrWaitingForMergeability {}) observation =
  case observation of
    MergeabilityObservedClean commitSha ->
      case state of
        PrWaitingForMergeability _config evidence _worker _reviewer
          | cleanReviewCommit evidence == commitSha ->
              Right (observedFromDecision (PrReviewMergeabilityClean commitSha) (step state MergeabilityClean))
          | otherwise ->
              Left "mergeability clean commit does not match reviewed commit"
    MergeabilityObservedRetry reason ->
      Right (observedFromDecision (PrReviewMergeabilityWaiting reason) (step state (MergeabilityRetryLater reason)))
    MergeabilityObservedRecheck reason ->
      Right (observedFromDecision (PrReviewMergeabilityRecheck reason) (step state (MergeabilityRecheckReviews reason)))
    MergeabilityObservedFixRequired evidence ->
      Right (observedFromDecision (PrReviewMergeabilityFixRequired evidence) (step state (MergeabilityFixRequired evidence)))
observePrReviewMergeability state observation =
  invalidObservation "PR review mergeability observation" state observation
