{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}

module CodexWatcher.Effects
  ( Effect (..)
  , SomeEffect (..)
  , EffectPlan
  , effectMutability
  , effectPlanMutabilities
  , isMutation
  , hasMutation
  ) where

import CodexWatcher.Types

data Effect (mutability :: Mutability) where
  ReadOpenIssues :: RepoName -> Effect 'ReadOnly
  ReadOpenPullRequests :: RepoName -> Effect 'ReadOnly
  ReadReviewThreads :: PrConfig -> Effect 'ReadOnly
  StartPlannerTurn :: ThreadId -> Effect 'CanStartTurn
  StartWorkerTurn :: ThreadId -> Effect 'CanStartTurn
  StartIssueTriageWorkerTurn :: ThreadId -> Effect 'CanStartTurn
  StartIssuePlanWorkerTurn :: IssueConfig -> ThreadId -> Effect 'CanStartTurn
  StartIssueImplementationWorkerTurn :: ThreadId -> Effect 'CanStartTurn
  StartReviewerTurn :: PrConfig -> CommitSha -> ThreadId -> Effect 'CanStartTurn
  PushBranch :: BranchName -> Effect 'CanMutateLocal
  CreateIssue :: RepoName -> IssueCreationRequest -> Effect 'CanMutateGitHub
  CreatePullRequest :: IssueConfig -> Effect 'CanMutateGitHub
  UpdatePullRequestBody :: IssueConfig -> PrNumber -> Effect 'CanMutateGitHub
  ResolveReviewThread :: ReviewThreadId -> Effect 'CanMutateGitHub
  RecordPlanningGraph :: PlanningGraph -> Effect 'CanMutateLocal
  RecordBlocked :: BlockedReason -> Effect 'CanMutateLocal
  MergePullRequest :: PrNumber -> CleanReviewEvidence -> Effect 'CanMerge
  StopDaemon :: Effect 'ReadOnly
  SleepUntilNextPoll :: Effect 'ReadOnly

deriving stock instance Eq (Effect mutability)
deriving stock instance Show (Effect mutability)

data SomeEffect where
  SomeEffect :: Effect mutability -> SomeEffect

deriving stock instance Show SomeEffect

instance Eq SomeEffect where
  SomeEffect (ReadOpenIssues left) == SomeEffect (ReadOpenIssues right) = left == right
  SomeEffect (ReadOpenPullRequests left) == SomeEffect (ReadOpenPullRequests right) = left == right
  SomeEffect (ReadReviewThreads left) == SomeEffect (ReadReviewThreads right) = left == right
  SomeEffect (StartPlannerTurn left) == SomeEffect (StartPlannerTurn right) = left == right
  SomeEffect (StartWorkerTurn left) == SomeEffect (StartWorkerTurn right) = left == right
  SomeEffect (StartIssueTriageWorkerTurn left) == SomeEffect (StartIssueTriageWorkerTurn right) = left == right
  SomeEffect (StartIssuePlanWorkerTurn leftConfig leftThread) == SomeEffect (StartIssuePlanWorkerTurn rightConfig rightThread) =
    leftConfig == rightConfig && leftThread == rightThread
  SomeEffect (StartIssueImplementationWorkerTurn left) == SomeEffect (StartIssueImplementationWorkerTurn right) = left == right
  SomeEffect (StartReviewerTurn leftConfig leftCommit leftThread) == SomeEffect (StartReviewerTurn rightConfig rightCommit rightThread) =
    leftConfig == rightConfig && leftCommit == rightCommit && leftThread == rightThread
  SomeEffect (PushBranch left) == SomeEffect (PushBranch right) = left == right
  SomeEffect (CreateIssue leftRepo leftRequest) == SomeEffect (CreateIssue rightRepo rightRequest) =
    leftRepo == rightRepo && leftRequest == rightRequest
  SomeEffect (CreatePullRequest left) == SomeEffect (CreatePullRequest right) = left == right
  SomeEffect (UpdatePullRequestBody leftConfig leftPr) == SomeEffect (UpdatePullRequestBody rightConfig rightPr) =
    leftConfig == rightConfig && leftPr == rightPr
  SomeEffect (ResolveReviewThread left) == SomeEffect (ResolveReviewThread right) = left == right
  SomeEffect (RecordPlanningGraph left) == SomeEffect (RecordPlanningGraph right) = left == right
  SomeEffect (RecordBlocked left) == SomeEffect (RecordBlocked right) = left == right
  SomeEffect (MergePullRequest leftPr leftEvidence) == SomeEffect (MergePullRequest rightPr rightEvidence) =
    leftPr == rightPr && leftEvidence == rightEvidence
  SomeEffect StopDaemon == SomeEffect StopDaemon = True
  SomeEffect SleepUntilNextPoll == SomeEffect SleepUntilNextPoll = True
  SomeEffect _ == SomeEffect _ = False

type EffectPlan = [SomeEffect]

effectMutability :: Effect mutability -> Mutability
effectMutability ReadOpenIssues {} = ReadOnly
effectMutability ReadOpenPullRequests {} = ReadOnly
effectMutability ReadReviewThreads {} = ReadOnly
effectMutability StartPlannerTurn {} = CanStartTurn
effectMutability StartWorkerTurn {} = CanStartTurn
effectMutability StartIssueTriageWorkerTurn {} = CanStartTurn
effectMutability StartIssuePlanWorkerTurn {} = CanStartTurn
effectMutability StartIssueImplementationWorkerTurn {} = CanStartTurn
effectMutability StartReviewerTurn {} = CanStartTurn
effectMutability PushBranch {} = CanMutateLocal
effectMutability CreateIssue {} = CanMutateGitHub
effectMutability CreatePullRequest {} = CanMutateGitHub
effectMutability UpdatePullRequestBody {} = CanMutateGitHub
effectMutability ResolveReviewThread {} = CanMutateGitHub
effectMutability RecordPlanningGraph {} = CanMutateLocal
effectMutability RecordBlocked {} = CanMutateLocal
effectMutability MergePullRequest {} = CanMerge
effectMutability StopDaemon = ReadOnly
effectMutability SleepUntilNextPoll = ReadOnly

effectPlanMutabilities :: EffectPlan -> [Mutability]
effectPlanMutabilities = fmap (\(SomeEffect effect) -> effectMutability effect)

isMutation :: Mutability -> Bool
isMutation ReadOnly = False
isMutation CanStartTurn = True
isMutation CanMutateLocal = True
isMutation CanMutateGitHub = True
isMutation CanMerge = True

hasMutation :: EffectPlan -> Bool
hasMutation = any (isMutation . (\(SomeEffect effect) -> effectMutability effect))
