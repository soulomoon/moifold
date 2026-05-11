{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.Core.State
  ( CompletionEvidence (..)
  , WatcherState (..)
  , SomeWatcherState (..)
  , domainOf
  , phaseOf
  , knownDomain
  , knownPhase
  , someDomain
  , someDomainIs
  , somePhase
  , somePhaseIs
  , withDomain
  , isTerminalState
  ) where

import CodexWatcher.Core.Kinds
import CodexWatcher.Core.Reason
import CodexWatcher.Core.Thread
import CodexWatcher.Domain.IssueImplement.Types
import CodexWatcher.Domain.IssuePlanning.Types
import CodexWatcher.Domain.PrReview.Types
import CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)
import Data.Proxy (Proxy (..))
import Data.Singletons (SingI (..), SingKind (..))

data CompletionEvidence (domain :: Domain) where
  PlanningComplete :: CompletionEvidence 'IssuePlanning
  IssueComplete :: PrNumber -> CompletionEvidence 'IssueImplement
  PrMerged :: MergeCommit -> CompletionEvidence 'PrReview

deriving stock instance Eq (CompletionEvidence domain)
deriving stock instance Show (CompletionEvidence domain)

data WatcherState (domain :: Domain) (phase :: Phase) where
  PlanningReady
    :: PlannerConfig
    -> WatcherState 'IssuePlanning 'Initialized

  PlanningTurnActive
    :: PlannerConfig
    -> ActiveTurn
    -> WatcherState 'IssuePlanning 'PlanMode

  PlanningWaitingForReadyIssues
    :: PlannerConfig
    -> PlanningGraph
    -> WatcherState 'IssuePlanning 'Initialized

  IssueReadyToPlan
    :: IssueConfig
    -> PrNumber
    -> WorkerThread 'Idle
    -> WatcherState 'IssueImplement 'PlanMode

  IssueInPlanMode
    :: IssueConfig
    -> PrNumber
    -> WorkerThread 'Active
    -> WatcherState 'IssueImplement 'PlanMode

  IssuePlanReady
    :: IssueConfig
    -> PrNumber
    -> WorkerThread 'Idle
    -> WatcherState 'IssueImplement 'Implementing

  IssueImplementationReady
    :: IssueConfig
    -> Maybe PrNumber
    -> WorkerThread 'Idle
    -> WatcherState 'IssueImplement 'Implementing

  IssueImplementing
    :: IssueConfig
    -> Maybe PrNumber
    -> WorkerThread 'Active
    -> WatcherState 'IssueImplement 'Implementing

  IssueHandoffReady
    :: IssueConfig
    -> PrNumber
    -> WorkerThread 'Idle
    -> Maybe (ReviewerThread 'Idle)
    -> WatcherState 'IssueImplement 'Implementing

  IssueHandoffInitialized
    :: IssueConfig
    -> PrNumber
    -> WorkerThread 'Idle
    -> Maybe (ReviewerThread 'Idle)
    -> WatcherState 'IssueImplement 'Implementing

  IssueWaitingForPrMerge
    :: IssueConfig
    -> PrNumber
    -> WorkerThread 'Idle
    -> Maybe (ReviewerThread 'Idle)
    -> WatcherState 'IssueImplement 'Implementing

  IssuePostMergeReviewPendingReviewer
    :: IssueConfig
    -> PrNumber
    -> WorkerThread 'Idle
    -> WatcherState 'IssueImplement 'Implementing

  IssuePostMergeReviewReady
    :: IssueConfig
    -> PrNumber
    -> WorkerThread 'Idle
    -> ReviewerThread 'Idle
    -> WatcherState 'IssueImplement 'Implementing

  IssuePostMergeReviewing
    :: IssueConfig
    -> PrNumber
    -> WorkerThread 'Idle
    -> CommitSha
    -> ReviewerThread 'Active
    -> WatcherState 'IssueImplement 'Implementing

  IssueWaitingForIssueClose
    :: IssueConfig
    -> PrNumber
    -> WatcherState 'IssueImplement 'Implementing

  PrCheckingReviews
    :: PrConfig
    -> WorkerThread 'Idle
    -> ReviewerThread 'Idle
    -> WatcherState 'PrReview 'CheckingReviews

  PrFixingReviews
    :: PrConfig
    -> ReviewEvidence
    -> WorkerThread 'Active
    -> ReviewerThread 'Idle
    -> WatcherState 'PrReview 'FixingReviews

  PrReviewFixQueued
    :: PrConfig
    -> ReviewEvidence
    -> WorkerThread 'Idle
    -> ReviewerThread 'Idle
    -> WatcherState 'PrReview 'CheckingReviews

  PrVerifyingReviewFix
    :: PrConfig
    -> ReviewEvidence
    -> WorkerThread 'Idle
    -> ReviewerThread 'Idle
    -> WatcherState 'PrReview 'CheckingReviews

  PrReviewingClean
    :: PrConfig
    -> CommitSha
    -> SomeReviewContext
    -> WorkerThread 'Idle
    -> ReviewerThread 'Active
    -> WatcherState 'PrReview 'ReviewingClean

  PrWaitingForMergeability
    :: PrConfig
    -> CleanReviewEvidence
    -> WorkerThread 'Idle
    -> ReviewerThread 'Idle
    -> WatcherState 'PrReview 'WaitingMergeability

  PrMerging
    :: PrConfig
    -> CleanReviewEvidence
    -> WatcherState 'PrReview 'Merging

  BlockedState
    :: BlockedReason
    -> WatcherState domain 'Blocked

  CompleteState
    :: CompletionEvidence domain
    -> WatcherState domain 'Complete

  StoppedState
    :: StopReason
    -> WatcherState domain 'Stopped

deriving stock instance Eq (WatcherState domain phase)
deriving stock instance Show (WatcherState domain phase)

data SomeWatcherState where
  SomeWatcherState :: (KnownDomain domain, KnownPhase phase) => WatcherState domain phase -> SomeWatcherState

deriving stock instance Show SomeWatcherState

knownDomain :: forall domain. KnownDomain domain => Domain
knownDomain =
  fromSing (sing @domain)

withDomain :: Domain -> (forall domain. KnownDomain domain => Proxy domain -> r) -> r
withDomain PrReview f = f (Proxy @'PrReview)
withDomain IssueImplement f = f (Proxy @'IssueImplement)
withDomain IssuePlanning f = f (Proxy @'IssuePlanning)

knownPhase :: forall phase. KnownPhase phase => Phase
knownPhase =
  fromSing (sing @phase)

domainOf :: forall domain phase. KnownDomain domain => WatcherState domain phase -> Domain
domainOf _ = knownDomain @domain

phaseOf :: forall domain phase. KnownPhase phase => WatcherState domain phase -> Phase
phaseOf _ = knownPhase @phase

someDomain :: SomeWatcherState -> Domain
someDomain (SomeWatcherState state) = domainOf state

somePhase :: SomeWatcherState -> Phase
somePhase (SomeWatcherState state) = phaseOf state

someDomainIs :: forall domain. KnownDomain domain => SomeWatcherState -> Bool
someDomainIs state =
  someDomain state == knownDomain @domain

somePhaseIs :: forall phase. KnownPhase phase => SomeWatcherState -> Bool
somePhaseIs state =
  somePhase state == knownPhase @phase

isTerminalState :: SomeWatcherState -> Bool
isTerminalState (SomeWatcherState (_ :: WatcherState domain phase)) = isTerminalPhaseSing (sing @phase)
