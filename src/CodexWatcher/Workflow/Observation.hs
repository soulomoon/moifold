{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.Workflow.Observation
  ( DaemonObservation (..)
  , ObservedPolicyTick (..)
  , observeDaemonState
  ) where

import CodexWatcher.Effects (EffectPlan)
import CodexWatcher.EventLog.Types (WatcherEvent)
import CodexWatcher.Domain.IssueImplement.Watcher
  ( IssueImplementObservation
  , IssueImplementTick (..)
  , issueImplementObserve
  )
import CodexWatcher.Domain.IssuePlanning.Watcher
  ( IssuePlanningObservation
  , IssuePlanningTick (..)
  , issuePlanningObserve
  )
import CodexWatcher.Domain.PrReview.Watcher
  ( PrReviewObservation
  , PrReviewTick (..)
  , prReviewObserve
  )
import CodexWatcher.Core.State (SomeWatcherState)
import Data.Text (Text)
import GHC.Generics (Generic)

data DaemonObservation
  = DaemonPrReviewObservation PrReviewObservation
  | DaemonIssueImplementObservation IssueImplementObservation
  | DaemonIssuePlanningObservation IssuePlanningObservation
  deriving stock (Eq, Show, Generic)

data ObservedPolicyTick = ObservedPolicyTick
  { observedEvent :: WatcherEvent
  , observedState :: SomeWatcherState
  , observedEffects :: EffectPlan
  }

observeDaemonState :: SomeWatcherState -> DaemonObservation -> Either Text ObservedPolicyTick
observeDaemonState state = \case
  DaemonPrReviewObservation observation ->
    fromPrReviewTick <$> prReviewObserve state observation
  DaemonIssueImplementObservation observation ->
    fromIssueImplementTick <$> issueImplementObserve state observation
  DaemonIssuePlanningObservation observation ->
    fromIssuePlanningTick <$> issuePlanningObserve state observation

fromPrReviewTick :: PrReviewTick -> ObservedPolicyTick
fromPrReviewTick tick =
  ObservedPolicyTick tick.prReviewTickEvent tick.prReviewTickState tick.prReviewTickEffects

fromIssueImplementTick :: IssueImplementTick -> ObservedPolicyTick
fromIssueImplementTick tick =
  ObservedPolicyTick tick.issueImplementTickEvent tick.issueImplementTickState tick.issueImplementTickEffects

fromIssuePlanningTick :: IssuePlanningTick -> ObservedPolicyTick
fromIssuePlanningTick tick =
  ObservedPolicyTick tick.issuePlanningTickEvent tick.issuePlanningTickState tick.issuePlanningTickEffects
