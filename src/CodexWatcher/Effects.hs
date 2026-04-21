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
  StartReviewerTurn :: ThreadId -> Effect 'CanStartTurn
  PushBranch :: BranchName -> Effect 'CanMutateLocal
  CreatePullRequest :: IssueConfig -> Effect 'CanMutateGitHub
  ResolveReviewThread :: ReviewThreadId -> Effect 'CanMutateGitHub
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
  SomeEffect left == SomeEffect right = show left == show right

type EffectPlan = [SomeEffect]

effectMutability :: Effect mutability -> Mutability
effectMutability ReadOpenIssues {} = ReadOnly
effectMutability ReadOpenPullRequests {} = ReadOnly
effectMutability ReadReviewThreads {} = ReadOnly
effectMutability StartPlannerTurn {} = CanStartTurn
effectMutability StartWorkerTurn {} = CanStartTurn
effectMutability StartReviewerTurn {} = CanStartTurn
effectMutability PushBranch {} = CanMutateLocal
effectMutability CreatePullRequest {} = CanMutateGitHub
effectMutability ResolveReviewThread {} = CanMutateGitHub
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
