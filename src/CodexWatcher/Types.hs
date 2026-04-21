{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.Types
  ( Domain (..)
  , Phase (..)
  , ThreadActivity (..)
  , Mutability (..)
  , KnownDomain (..)
  , RepoName (..)
  , IssueNumber (..)
  , PrNumber (..)
  , ThreadId (..)
  , TurnId (..)
  , BranchName (..)
  , ReviewThreadId (..)
  , CommitSha (..)
  , MergeCommit (..)
  , BlockedReason (..)
  , StopReason (..)
  , PlannerConfig (..)
  , IssueConfig (..)
  , PrConfig (..)
  , WorkerThread (..)
  , ReviewerThread (..)
  , ActiveTurn (..)
  , ReviewEvidence (..)
  , CleanReviewEvidence (..)
  , CompletionEvidence (..)
  , WatcherState (..)
  , SomeWatcherState (..)
  , domainOf
  , phaseOf
  , isTerminalPhase
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)

data Domain
  = IssuePlanning
  | IssueImplement
  | PrReview
  deriving stock (Eq, Show)

class KnownDomain (domain :: Domain) where
  knownDomain :: Domain

instance KnownDomain 'IssuePlanning where
  knownDomain = IssuePlanning

instance KnownDomain 'IssueImplement where
  knownDomain = IssueImplement

instance KnownDomain 'PrReview where
  knownDomain = PrReview

data Phase
  = Initialized
  | Triage
  | PlanMode
  | Implementing
  | CheckingReviews
  | FixingReviews
  | ReviewingClean
  | Merging
  | Blocked
  | Complete
  | Stopped
  deriving stock (Eq, Show)

data ThreadActivity
  = Idle
  | Active
  deriving stock (Eq, Show)

data Mutability
  = ReadOnly
  | CanStartTurn
  | CanMutateLocal
  | CanMutateGitHub
  | CanMerge
  deriving stock (Eq, Show)

newtype RepoName = RepoName { unRepoName :: Text }
  deriving stock (Eq, Show)

newtype IssueNumber = IssueNumber { unIssueNumber :: Int }
  deriving stock (Eq, Show)

newtype PrNumber = PrNumber { unPrNumber :: Int }
  deriving stock (Eq, Show)

newtype ThreadId = ThreadId { unThreadId :: Text }
  deriving stock (Eq, Show)

newtype TurnId = TurnId { unTurnId :: Text }
  deriving stock (Eq, Show)

newtype BranchName = BranchName { unBranchName :: Text }
  deriving stock (Eq, Show)

newtype ReviewThreadId = ReviewThreadId { unReviewThreadId :: Text }
  deriving stock (Eq, Show)

newtype CommitSha = CommitSha { unCommitSha :: Text }
  deriving stock (Eq, Show)

newtype MergeCommit = MergeCommit { unMergeCommit :: CommitSha }
  deriving stock (Eq, Show)

newtype BlockedReason = BlockedReason { unBlockedReason :: Text }
  deriving stock (Eq, Show)

newtype StopReason = StopReason { unStopReason :: Text }
  deriving stock (Eq, Show)

data PlannerConfig = PlannerConfig
  { plannerRepo :: RepoName
  , plannerMaxParallel :: Int
  }
  deriving stock (Eq, Show)

data IssueConfig = IssueConfig
  { issueRepo :: RepoName
  , issueNumber :: IssueNumber
  , issueBranch :: BranchName
  }
  deriving stock (Eq, Show)

data PrConfig = PrConfig
  { prRepo :: RepoName
  , prNumber :: PrNumber
  , prBranch :: BranchName
  }
  deriving stock (Eq, Show)

data ActiveTurn = ActiveTurn
  { activeThreadId :: ThreadId
  , activeTurnId :: TurnId
  }
  deriving stock (Eq, Show)

data WorkerThread (activity :: ThreadActivity) where
  WorkerIdle :: ThreadId -> WorkerThread 'Idle
  WorkerActive :: ActiveTurn -> WorkerThread 'Active

deriving stock instance Eq (WorkerThread activity)
deriving stock instance Show (WorkerThread activity)

data ReviewerThread (activity :: ThreadActivity) where
  ReviewerIdle :: ThreadId -> ReviewerThread 'Idle
  ReviewerActive :: ActiveTurn -> ReviewerThread 'Active

deriving stock instance Eq (ReviewerThread activity)
deriving stock instance Show (ReviewerThread activity)

data ReviewEvidence = ReviewEvidence
  { unresolvedThreads :: NonEmpty ReviewThreadId
  , reviewedCommit :: CommitSha
  }
  deriving stock (Eq, Show)

data CleanReviewEvidence = CleanReviewEvidence
  { cleanReviewCommit :: CommitSha
  , cleanReviewComment :: Text
  }
  deriving stock (Eq, Show)

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

  IssueNeedsTriage
    :: IssueConfig
    -> WorkerThread 'Idle
    -> WatcherState 'IssueImplement 'Triage

  IssueInPlanMode
    :: IssueConfig
    -> WorkerThread 'Active
    -> WatcherState 'IssueImplement 'PlanMode

  IssueImplementing
    :: IssueConfig
    -> WorkerThread 'Active
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

  PrReviewingClean
    :: PrConfig
    -> CommitSha
    -> WorkerThread 'Idle
    -> ReviewerThread 'Active
    -> WatcherState 'PrReview 'ReviewingClean

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
  SomeWatcherState :: WatcherState domain phase -> SomeWatcherState

deriving stock instance Show SomeWatcherState

domainOf :: forall domain phase. KnownDomain domain => WatcherState domain phase -> Domain
domainOf _ = knownDomain @domain

phaseOf :: WatcherState domain phase -> Phase
phaseOf PlanningReady {} = Initialized
phaseOf PlanningTurnActive {} = PlanMode
phaseOf IssueNeedsTriage {} = Triage
phaseOf IssueInPlanMode {} = PlanMode
phaseOf IssueImplementing {} = Implementing
phaseOf PrCheckingReviews {} = CheckingReviews
phaseOf PrFixingReviews {} = FixingReviews
phaseOf PrReviewingClean {} = ReviewingClean
phaseOf PrMerging {} = Merging
phaseOf BlockedState {} = Blocked
phaseOf CompleteState {} = Complete
phaseOf StoppedState {} = Stopped

isTerminalPhase :: Phase -> Bool
isTerminalPhase Blocked = True
isTerminalPhase Complete = True
isTerminalPhase Stopped = True
isTerminalPhase _ = False
