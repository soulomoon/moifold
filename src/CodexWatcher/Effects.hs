{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.Effects
  ( ActionKind (..)
  , Effect (..)
  , SomeEffect (..)
  , EffectPlan
  , SomeEffectAction (..)
  , actionKindText
  , effectActionSing
  , hasMutation
  , someEffectAction
  ) where

import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId, ThreadId)
import CodexWatcher.Core.Kinds (ActionKind (..), KnownAction, KnownMutability, Mutability (..), SActionKind (..), SMutability (..))
import CodexWatcher.Core.Reason (BlockedReason)
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig)
import CodexWatcher.Domain.IssuePlanning.Types (IssueCreationRequest, PlanningGraph)
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence, PrConfig, ReviewEvidence)
import Data.Singletons (SingI (..))
import Data.Singletons.Decide (decideEquality)
import Data.Text (Text)
import Data.Type.Equality ((:~:) (Refl))

data Effect (action :: ActionKind) (mutability :: Mutability) where
  ReadOpenIssues :: RepoName -> Effect 'ReadOpenIssuesAction 'ReadOnly
  ReadOpenPullRequests :: RepoName -> Effect 'ReadOpenPullRequestsAction 'ReadOnly
  ReadReviewThreads :: PrConfig -> Effect 'ReadReviewThreadsAction 'ReadOnly
  StartPlannerTurn :: ThreadId -> Effect 'StartPlannerTurnAction 'CanStartTurn
  StartWorkerTurn :: ReviewEvidence -> ThreadId -> Effect 'StartWorkerTurnAction 'CanStartTurn
  StartIssuePlanWorkerTurn :: IssueConfig -> PrNumber -> ThreadId -> Effect 'StartIssuePlanWorkerTurnAction 'CanStartTurn
  StartIssueImplementationWorkerTurn :: ThreadId -> Effect 'StartIssueImplementationWorkerTurnAction 'CanStartTurn
  StartReviewerTurn :: PrConfig -> CommitSha -> ThreadId -> Effect 'StartReviewerTurnAction 'CanStartTurn
  StartReviewerVerificationTurn :: PrConfig -> ReviewEvidence -> CommitSha -> ThreadId -> Effect 'StartReviewerVerificationTurnAction 'CanStartTurn
  StartIssueFinalReviewTurn :: IssueConfig -> PrNumber -> CommitSha -> ThreadId -> Effect 'StartIssueFinalReviewTurnAction 'CanStartTurn
  PushBranch :: BranchName -> Effect 'PushBranchAction 'CanMutateLocal
  CreateIssue :: RepoName -> IssueCreationRequest -> Effect 'CreateIssueAction 'CanMutateGitHub
  CreatePullRequest :: IssueConfig -> Effect 'CreatePullRequestAction 'CanMutateGitHub
  UpdatePullRequestBody :: IssueConfig -> PrNumber -> Effect 'UpdatePullRequestBodyAction 'CanMutateGitHub
  UpdateIssueFollowUp :: IssueConfig -> ReviewEvidence -> Effect 'UpdateIssueFollowUpAction 'CanMutateGitHub
  CloseIssue :: IssueConfig -> PrNumber -> Effect 'CloseIssueAction 'CanMutateGitHub
  ResolveReviewThread :: ReviewThreadId -> Effect 'ResolveReviewThreadAction 'CanMutateGitHub
  ReplyReviewThread :: ReviewThreadId -> Text -> Effect 'ReplyReviewThreadAction 'CanMutateGitHub
  PublishReviewFindings :: PrConfig -> ReviewEvidence -> Effect 'PublishReviewFindingsAction 'CanMutateGitHub
  RecordIssuePlan :: IssueConfig -> PrNumber -> Text -> Effect 'RecordIssuePlanAction 'CanMutateLocal
  RecordPlanningGraph :: PlanningGraph -> Effect 'RecordPlanningGraphAction 'CanMutateLocal
  RecordBlocked :: BlockedReason -> Effect 'RecordBlockedAction 'CanMutateLocal
  MergePullRequest :: PrNumber -> CleanReviewEvidence -> Effect 'MergePullRequestAction 'CanMerge
  StopDaemon :: Effect 'StopDaemonAction 'ReadOnly
  SleepUntilNextPoll :: Effect 'SleepUntilNextPollAction 'ReadOnly

deriving stock instance Eq (Effect action mutability)
deriving stock instance Show (Effect action mutability)

data SomeEffect where
  SomeEffect :: (KnownAction action, KnownMutability mutability) => Effect action mutability -> SomeEffect

data SomeEffectAction where
  SomeEffectAction :: KnownAction action => SActionKind action -> SomeEffectAction

deriving stock instance Show SomeEffect

instance Eq SomeEffect where
  SomeEffect left == SomeEffect right =
    case decideEquality (effectActionSing left) (effectActionSing right) of
      Just Refl ->
        case decideEquality (effectMutabilitySing left) (effectMutabilitySing right) of
          Just Refl -> left == right
          Nothing -> False
      Nothing -> False

type EffectPlan = [SomeEffect]

effectActionSing :: forall action mutability. KnownAction action => Effect action mutability -> SActionKind action
effectActionSing _ = sing @action

effectMutabilitySing :: forall action mutability. KnownMutability mutability => Effect action mutability -> SMutability mutability
effectMutabilitySing _ = sing @mutability

someEffectAction :: SomeEffect -> SomeEffectAction
someEffectAction (SomeEffect effect) =
  SomeEffectAction (effectActionSing effect)

actionKindText :: SActionKind action -> Text
actionKindText SReadOpenIssuesAction = "ReadOpenIssues"
actionKindText SReadOpenPullRequestsAction = "ReadOpenPullRequests"
actionKindText SReadReviewThreadsAction = "ReadReviewThreads"
actionKindText SStartPlannerTurnAction = "StartPlannerTurn"
actionKindText SStartWorkerTurnAction = "StartWorkerTurn"
actionKindText SStartIssuePlanWorkerTurnAction = "StartIssuePlanWorkerTurn"
actionKindText SStartIssueImplementationWorkerTurnAction = "StartIssueImplementationWorkerTurn"
actionKindText SStartReviewerTurnAction = "StartReviewerTurn"
actionKindText SStartReviewerVerificationTurnAction = "StartReviewerVerificationTurn"
actionKindText SStartIssueFinalReviewTurnAction = "StartIssueFinalReviewTurn"
actionKindText SPushBranchAction = "PushBranch"
actionKindText SCreateIssueAction = "CreateIssue"
actionKindText SCreatePullRequestAction = "CreatePullRequest"
actionKindText SUpdatePullRequestBodyAction = "UpdatePullRequestBody"
actionKindText SUpdateIssueFollowUpAction = "UpdateIssueFollowUp"
actionKindText SCloseIssueAction = "CloseIssue"
actionKindText SResolveReviewThreadAction = "ResolveReviewThread"
actionKindText SReplyReviewThreadAction = "ReplyReviewThread"
actionKindText SPublishReviewFindingsAction = "PublishReviewFindings"
actionKindText SRecordIssuePlanAction = "RecordIssuePlan"
actionKindText SRecordPlanningGraphAction = "RecordPlanningGraph"
actionKindText SRecordBlockedAction = "RecordBlocked"
actionKindText SMergePullRequestAction = "MergePullRequest"
actionKindText SStopDaemonAction = "StopDaemon"
actionKindText SSleepUntilNextPollAction = "SleepUntilNextPoll"

isMutationSing :: SMutability mutability -> Bool
isMutationSing SReadOnly = False
isMutationSing _ = True

hasMutation :: EffectPlan -> Bool
hasMutation = any (\(SomeEffect effect) -> isMutationSing (effectMutabilitySing effect))
