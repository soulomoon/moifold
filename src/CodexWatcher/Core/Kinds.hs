{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneKindSignatures #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module CodexWatcher.Core.Kinds
  ( Domain (..)
  , SDomain (..)
  , Phase (..)
  , SPhase (..)
  , ThreadActivity (..)
  , ActionKind (..)
  , SActionKind (..)
  , Mutability (..)
  , SMutability (..)
  , KnownDomain
  , KnownPhase
  , KnownAction
  , KnownMutability
  , domainSing
  , phaseSing
  , isTerminalPhase
  , isTerminalPhaseSing
  ) where

import Data.Aeson (ToJSON (..))
import Data.Kind (Constraint)
import Data.Singletons (SingI (..))
import Data.Singletons.TH (genSingletons, singDecideInstances)

data Domain
  = IssuePlanning
  | IssueImplement
  | PrReview
  deriving stock (Eq, Show)

instance ToJSON Domain where
  toJSON = \case
    IssuePlanning -> "issue-planning"
    IssueImplement -> "issue-implement"
    PrReview -> "pr-review"

type KnownDomain :: Domain -> Constraint
type KnownDomain domain = SingI domain

data Phase
  = Initialized
  | PlanMode
  | Implementing
  | CheckingReviews
  | FixingReviews
  | ReviewingClean
  | WaitingMergeability
  | Merging
  | Blocked
  | Complete
  | Stopped
  deriving stock (Eq, Show)

type KnownPhase :: Phase -> Constraint
type KnownPhase phase = SingI phase

data ThreadActivity
  = Idle
  | Active
  deriving stock (Eq, Show)

data ActionKind
  = ReadOpenIssuesAction
  | ReadOpenPullRequestsAction
  | ReadReviewThreadsAction
  | StartPlannerTurnAction
  | StartWorkerTurnAction
  | StartIssuePlanWorkerTurnAction
  | StartIssueImplementationWorkerTurnAction
  | StartReviewerTurnAction
  | StartReviewerVerificationTurnAction
  | StartIssueFinalReviewTurnAction
  | PushBranchAction
  | CreateIssueAction
  | CreatePullRequestAction
  | UpdatePullRequestBodyAction
  | UpdateIssueFollowUpAction
  | CloseIssueAction
  | ResolveReviewThreadAction
  | ReplyReviewThreadAction
  | PublishReviewFindingsAction
  | DismissRequestChangesReviewAction
  | RecordIssuePlanAction
  | RecordPlanningGraphAction
  | RecordBlockedAction
  | MergePullRequestAction
  | StopDaemonAction
  | SleepUntilNextPollAction
  deriving stock (Eq, Show)

data Mutability
  = ReadOnly
  | CanStartTurn
  | CanMutateLocal
  | CanMutateGitHub
  | CanMerge
  deriving stock (Eq, Show)

$(genSingletons [''Domain, ''Phase, ''ActionKind, ''Mutability])
$(singDecideInstances [''ActionKind, ''Mutability])

type KnownAction :: ActionKind -> Constraint
type KnownAction action = SingI action

type KnownMutability :: Mutability -> Constraint
type KnownMutability mutability = SingI mutability

domainSing :: forall domain. KnownDomain domain => SDomain domain
domainSing =
  sing @domain

phaseSing :: forall phase. KnownPhase phase => SPhase phase
phaseSing =
  sing @phase

isTerminalPhase :: Phase -> Bool
isTerminalPhase Blocked = True
isTerminalPhase Complete = True
isTerminalPhase Stopped = True
isTerminalPhase _ = False

isTerminalPhaseSing :: SPhase phase -> Bool
isTerminalPhaseSing SBlocked = True
isTerminalPhaseSing SComplete = True
isTerminalPhaseSing SStopped = True
isTerminalPhaseSing _ = False
