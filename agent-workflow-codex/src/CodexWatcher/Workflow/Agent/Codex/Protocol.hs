{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.Workflow.Agent.Codex.Protocol
  ( agentThreadInterruptRequest
  , agentThreadReadRequest
  , agentThreadStartRequest
  , agentTurnStartRequest
  ) where

import CodexWatcher.AppServerProtocol
  ( AppServerRequest
  , ThreadStartOptions (..)
  , TurnStartOptions (..)
  , threadReadRequest
  , threadStartRequest
  , turnInterruptRequest
  , turnStartRequest
  )
import CodexWatcher.Workflow.Agent.Ids (RequestId)
import CodexWatcher.Workflow.Agent.Types
  ( AgentThreadPlan (..)
  , AgentTurnPlan (..)
  , TurnRef (..)
  )

agentThreadStartRequest :: RequestId -> AgentThreadPlan -> AppServerRequest
agentThreadStartRequest requestId plan =
  threadStartRequest
    requestId
    ThreadStartOptions
      { threadCwd = plan.agentThreadPlanCwd
      , threadApprovalPolicy = plan.agentThreadPlanApprovalPolicy
      , threadSandbox = plan.agentThreadPlanSandbox
      , threadModel = plan.agentThreadPlanModel
      , threadDeveloperInstructions = plan.agentThreadPlanDeveloperInstructions
      }

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
