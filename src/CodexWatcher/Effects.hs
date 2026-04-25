{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.Effects
  ( Effect (..)
  , SomeEffect (..)
  , EffectPlan
  , hasMutation
  ) where

import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId, ThreadId)
import CodexWatcher.Core.Kinds (KnownMutability, Mutability (..), SMutability (..))
import CodexWatcher.Core.Reason (BlockedReason)
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig)
import CodexWatcher.Domain.IssuePlanning.Types (IssueCreationRequest, PlanningGraph)
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence, PrConfig, ReviewEvidence)
import Data.Singletons (SingI (..))
import Data.Singletons.Decide (decideEquality)
import Data.Text (Text)
import Data.Type.Equality ((:~:) (Refl))

data Effect (mutability :: Mutability) where
  ReadOpenIssues :: RepoName -> Effect 'ReadOnly
  ReadOpenPullRequests :: RepoName -> Effect 'ReadOnly
  ReadReviewThreads :: PrConfig -> Effect 'ReadOnly
  StartPlannerTurn :: ThreadId -> Effect 'CanStartTurn
  StartWorkerTurn :: ThreadId -> Effect 'CanStartTurn
  StartIssuePlanWorkerTurn :: IssueConfig -> PrNumber -> ThreadId -> Effect 'CanStartTurn
  StartIssueImplementationWorkerTurn :: ThreadId -> Effect 'CanStartTurn
  StartReviewerTurn :: PrConfig -> CommitSha -> ThreadId -> Effect 'CanStartTurn
  StartReviewerVerificationTurn :: PrConfig -> ReviewEvidence -> CommitSha -> ThreadId -> Effect 'CanStartTurn
  PushBranch :: BranchName -> Effect 'CanMutateLocal
  CreateIssue :: RepoName -> IssueCreationRequest -> Effect 'CanMutateGitHub
  CreatePullRequest :: IssueConfig -> Effect 'CanMutateGitHub
  UpdatePullRequestBody :: IssueConfig -> PrNumber -> Effect 'CanMutateGitHub
  CloseIssue :: IssueConfig -> PrNumber -> Effect 'CanMutateGitHub
  ResolveReviewThread :: ReviewThreadId -> Effect 'CanMutateGitHub
  RequestChangesReview :: PrConfig -> ReviewEvidence -> Effect 'CanMutateGitHub
  RecordIssuePlan :: IssueConfig -> PrNumber -> Text -> Effect 'CanMutateLocal
  RecordPlanningGraph :: PlanningGraph -> Effect 'CanMutateLocal
  RecordBlocked :: BlockedReason -> Effect 'CanMutateLocal
  MergePullRequest :: PrNumber -> CleanReviewEvidence -> Effect 'CanMerge
  StopDaemon :: Effect 'ReadOnly
  SleepUntilNextPoll :: Effect 'ReadOnly

deriving stock instance Eq (Effect mutability)
deriving stock instance Show (Effect mutability)

data SomeEffect where
  SomeEffect :: KnownMutability mutability => Effect mutability -> SomeEffect

deriving stock instance Show SomeEffect

instance Eq SomeEffect where
  SomeEffect left == SomeEffect right =
    case decideEquality (effectMutabilitySing left) (effectMutabilitySing right) of
      Just Refl -> left == right
      Nothing -> False

type EffectPlan = [SomeEffect]

effectMutabilitySing :: forall mutability. KnownMutability mutability => Effect mutability -> SMutability mutability
effectMutabilitySing _ = sing @mutability

isMutationSing :: SMutability mutability -> Bool
isMutationSing SReadOnly = False
isMutationSing _ = True

hasMutation :: EffectPlan -> Bool
hasMutation = any (\(SomeEffect effect) -> isMutationSing (effectMutabilitySing effect))
