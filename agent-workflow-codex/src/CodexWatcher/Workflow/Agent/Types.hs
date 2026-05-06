{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Workflow.Agent.Types
  ( AgentRoleId (..)
  , AgentTurnPlan (..)
  , AgentTurnReadFailure (..)
  , AgentTurnReadResult (..)
  , AgentTurnStart (..)
  , FinalReviewerAgent
  , IssueImplementationWorkerAgent
  , IssuePlanWorkerAgent
  , PlannerAgent
  , PrReviewVerificationReviewerAgent
  , PrReviewWorkerAgent
  , ReviewerAgent
  , TurnRef (..)
  , finalReviewerAgentRoleId
  , issueImplementationWorkerAgentRoleId
  , issuePlanWorkerAgentRoleId
  , plannerAgentRoleId
  , prReviewVerificationReviewerAgentRoleId
  , prReviewWorkerAgentRoleId
  , reviewerAgentRoleId
  ) where

import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)
import Data.Aeson (Value)
import Data.Text (Text)

newtype AgentRoleId = AgentRoleId
  { unAgentRoleId :: Text
  }
  deriving stock (Eq, Ord, Show)

data AgentTurnPlan = AgentTurnPlan
  { agentTurnPlanRoleId :: AgentRoleId
  , agentTurnPlanThreadId :: ThreadId
  , agentTurnPlanCwd :: FilePath
  , agentTurnPlanEffort :: Text
  , agentTurnPlanModel :: Text
  , agentTurnPlanApprovalPolicy :: Text
  , agentTurnPlanSandboxPolicy :: Text
  , agentTurnPlanInput :: Text
  , agentTurnPlanOutputSchema :: Maybe Value
  , agentTurnPlanCollaborationMode :: Maybe Value
  }
  deriving stock (Eq, Show)

data AgentTurnStart = AgentTurnStart
  { agentTurnStartRoleId :: AgentRoleId
  , agentTurnStartThreadId :: ThreadId
  , agentTurnStartTurnId :: TurnId
  }
  deriving stock (Eq, Show)

data AgentTurnReadResult turn = AgentTurnReadResult
  { agentTurnReadTurn :: Maybe turn
  , agentTurnReadThreadSystemError :: Maybe Text
  }
  deriving stock (Eq, Show)

data AgentTurnReadFailure failure = AgentTurnReadFailure
  { agentTurnReadFailure :: failure
  }
  deriving stock (Eq, Show)

data TurnRef agentRole output = TurnRef
  { turnRefThreadId :: ThreadId
  , turnRefTurnId :: TurnId
  }
  deriving stock (Eq, Show)

data PlannerAgent

data PrReviewWorkerAgent

data IssuePlanWorkerAgent

data IssueImplementationWorkerAgent

data ReviewerAgent

data PrReviewVerificationReviewerAgent

data FinalReviewerAgent

plannerAgentRoleId :: AgentRoleId
plannerAgentRoleId =
  AgentRoleId "planner"

prReviewWorkerAgentRoleId :: AgentRoleId
prReviewWorkerAgentRoleId =
  AgentRoleId "pr-review-worker"

issuePlanWorkerAgentRoleId :: AgentRoleId
issuePlanWorkerAgentRoleId =
  AgentRoleId "issue-plan-worker"

issueImplementationWorkerAgentRoleId :: AgentRoleId
issueImplementationWorkerAgentRoleId =
  AgentRoleId "issue-implementation-worker"

reviewerAgentRoleId :: AgentRoleId
reviewerAgentRoleId =
  AgentRoleId "reviewer"

prReviewVerificationReviewerAgentRoleId :: AgentRoleId
prReviewVerificationReviewerAgentRoleId =
  AgentRoleId "pr-review-verification-reviewer"

finalReviewerAgentRoleId :: AgentRoleId
finalReviewerAgentRoleId =
  AgentRoleId "final-reviewer"
