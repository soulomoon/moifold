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
  , effectMutabilitySing
  , effectMutability
  , effectPlanMutabilities
  , isMutationSing
  , isMutation
  , hasMutation
  ) where

import CodexWatcher.Types
import Data.Singletons (SingI (..), SingKind (..), SomeSing (..))
import Data.Text (Text)

data Effect (mutability :: Mutability) where
  ReadOpenIssues :: RepoName -> Effect 'ReadOnly
  ReadOpenPullRequests :: RepoName -> Effect 'ReadOnly
  ReadReviewThreads :: PrConfig -> Effect 'ReadOnly
  StartPlannerTurn :: ThreadId -> Effect 'CanStartTurn
  StartWorkerTurn :: ThreadId -> Effect 'CanStartTurn
  StartIssuePlanWorkerTurn :: IssueConfig -> PrNumber -> ThreadId -> Effect 'CanStartTurn
  StartIssueImplementationWorkerTurn :: ThreadId -> Effect 'CanStartTurn
  StartReviewerTurn :: PrConfig -> CommitSha -> ThreadId -> Effect 'CanStartTurn
  PushBranch :: BranchName -> Effect 'CanMutateLocal
  CreateIssue :: RepoName -> IssueCreationRequest -> Effect 'CanMutateGitHub
  CreatePullRequest :: IssueConfig -> Effect 'CanMutateGitHub
  UpdatePullRequestBody :: IssueConfig -> PrNumber -> Effect 'CanMutateGitHub
  CloseIssue :: IssueConfig -> PrNumber -> Effect 'CanMutateGitHub
  ResolveReviewThread :: ReviewThreadId -> Effect 'CanMutateGitHub
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
  SomeEffect (ReadOpenIssues left) == SomeEffect (ReadOpenIssues right) = left == right
  SomeEffect (ReadOpenPullRequests left) == SomeEffect (ReadOpenPullRequests right) = left == right
  SomeEffect (ReadReviewThreads left) == SomeEffect (ReadReviewThreads right) = left == right
  SomeEffect (StartPlannerTurn left) == SomeEffect (StartPlannerTurn right) = left == right
  SomeEffect (StartWorkerTurn left) == SomeEffect (StartWorkerTurn right) = left == right
  SomeEffect (StartIssuePlanWorkerTurn leftConfig leftPr leftThread) == SomeEffect (StartIssuePlanWorkerTurn rightConfig rightPr rightThread) =
    leftConfig == rightConfig && leftPr == rightPr && leftThread == rightThread
  SomeEffect (StartIssueImplementationWorkerTurn left) == SomeEffect (StartIssueImplementationWorkerTurn right) = left == right
  SomeEffect (StartReviewerTurn leftConfig leftCommit leftThread) == SomeEffect (StartReviewerTurn rightConfig rightCommit rightThread) =
    leftConfig == rightConfig && leftCommit == rightCommit && leftThread == rightThread
  SomeEffect (PushBranch left) == SomeEffect (PushBranch right) = left == right
  SomeEffect (CreateIssue leftRepo leftRequest) == SomeEffect (CreateIssue rightRepo rightRequest) =
    leftRepo == rightRepo && leftRequest == rightRequest
  SomeEffect (CreatePullRequest left) == SomeEffect (CreatePullRequest right) = left == right
  SomeEffect (UpdatePullRequestBody leftConfig leftPr) == SomeEffect (UpdatePullRequestBody rightConfig rightPr) =
    leftConfig == rightConfig && leftPr == rightPr
  SomeEffect (CloseIssue leftConfig leftPr) == SomeEffect (CloseIssue rightConfig rightPr) =
    leftConfig == rightConfig && leftPr == rightPr
  SomeEffect (ResolveReviewThread left) == SomeEffect (ResolveReviewThread right) = left == right
  SomeEffect (RecordIssuePlan leftConfig leftPr leftPlan) == SomeEffect (RecordIssuePlan rightConfig rightPr rightPlan) =
    leftConfig == rightConfig && leftPr == rightPr && leftPlan == rightPlan
  SomeEffect (RecordPlanningGraph left) == SomeEffect (RecordPlanningGraph right) = left == right
  SomeEffect (RecordBlocked left) == SomeEffect (RecordBlocked right) = left == right
  SomeEffect (MergePullRequest leftPr leftEvidence) == SomeEffect (MergePullRequest rightPr rightEvidence) =
    leftPr == rightPr && leftEvidence == rightEvidence
  SomeEffect StopDaemon == SomeEffect StopDaemon = True
  SomeEffect SleepUntilNextPoll == SomeEffect SleepUntilNextPoll = True
  SomeEffect _ == SomeEffect _ = False

type EffectPlan = [SomeEffect]

effectMutabilitySing :: forall mutability. KnownMutability mutability => Effect mutability -> SMutability mutability
effectMutabilitySing _ = sing @mutability

effectMutability :: KnownMutability mutability => Effect mutability -> Mutability
effectMutability = fromSing . effectMutabilitySing

effectPlanMutabilities :: EffectPlan -> [Mutability]
effectPlanMutabilities = fmap (\(SomeEffect effect) -> effectMutability effect)

isMutationSing :: SMutability mutability -> Bool
isMutationSing SReadOnly = False
isMutationSing _ = True

isMutation :: Mutability -> Bool
isMutation mutability =
  case toSing mutability of
    SomeSing mutability' -> isMutationSing mutability'

hasMutation :: EffectPlan -> Bool
hasMutation = any (\(SomeEffect effect) -> isMutationSing (effectMutabilitySing effect))
