{-# LANGUAGE OverloadedStrings #-}

-- | Moifold-owned Codex agent role markers and stable role identifiers.
-- The reusable Codex workflow package owns the typed start/read mechanics;
-- product workflows own their concrete roles.
module CodexWatcher.Workflow.Moifold.AgentRoles
  ( FinalReviewerAgent
  , IssueImplementationWorkerAgent
  , IssuePlanWorkerAgent
  , PlannerAgent
  , PrReviewVerificationReviewerAgent
  , PrReviewWorkerAgent
  , ReviewerAgent
  , finalReviewerAgentRoleId
  , issueImplementationWorkerAgentRoleId
  , issuePlanWorkerAgentRoleId
  , plannerAgentRoleId
  , prReviewVerificationReviewerAgentRoleId
  , prReviewWorkerAgentRoleId
  , reviewerAgentRoleId
  ) where

import CodexWatcher.Workflow.Agent.Types (AgentRoleId (..))

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
