{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.Workflow.Agent.Codex.Protocol
  ( agentThreadInterruptRequest
  , agentThreadReadRequest
  , agentTurnStartRequest
  ) where

import CodexWatcher.AppServerProtocol
  ( AppServerRequest
  , TurnStartOptions (..)
  , threadReadRequest
  , turnInterruptRequest
  , turnStartRequest
  )
import CodexWatcher.Workflow.Agent.Ids (RequestId)
import CodexWatcher.Workflow.Agent.Types
  ( AgentTurnPlan (..)
  , TurnRef (..)
  )

agentTurnStartRequest :: RequestId -> AgentTurnPlan -> AppServerRequest
agentTurnStartRequest requestId plan =
  turnStartRequest
    requestId
    TurnStartOptions
      { turnThreadId = plan.agentTurnPlanThreadId
      , turnCwd = plan.agentTurnPlanCwd
      , turnEffort = plan.agentTurnPlanEffort
      , turnModel = plan.agentTurnPlanModel
      , turnApprovalPolicy = plan.agentTurnPlanApprovalPolicy
      , turnSandboxPolicy = plan.agentTurnPlanSandboxPolicy
      , turnInput = plan.agentTurnPlanInput
      , turnOutputSchema = plan.agentTurnPlanOutputSchema
      , turnCollaborationMode = plan.agentTurnPlanCollaborationMode
      }

agentThreadReadRequest :: RequestId -> TurnRef agentRole output -> AppServerRequest
agentThreadReadRequest requestId turnRef =
  threadReadRequest requestId turnRef.turnRefThreadId True

agentThreadInterruptRequest :: RequestId -> TurnRef agentRole output -> AppServerRequest
agentThreadInterruptRequest requestId turnRef =
  turnInterruptRequest requestId turnRef.turnRefThreadId turnRef.turnRefTurnId
