{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.Workflow.Agent.Codex
  ( agentThreadReadRequest
  , agentThreadInterruptRequest
  , agentThreadPlanFromThreadStartOptions
  , agentThreadStartRequest
  , agentTurnStartRequest
  , cachedAgentTurnStartInterpreter
  , interruptAgentTurn
  , parseAgentThreadStart
  , parseAgentTurnInterrupt
  , parseAgentTurnReadResult
  , parseAgentTurnStart
  , readAgentTurn
  , startAgentThread
  , startAgentTurn
  ) where

import CodexWatcher.AppServerProtocol (AppServerRequest)
import CodexWatcher.Workflow.Agent.Codex.Client
  ( AppServerClientFailure
  , AppServerTurn
  , latestTurnById
  , parseThreadReadTurns
  , parseThreadStartThreadId
  , parseTurnStartTurnId
  , threadSystemError
  )
import CodexWatcher.Workflow.Agent.Codex.Interpreter (AppServerInterpreter (..))
import CodexWatcher.Workflow.Agent.Codex.Protocol
  ( agentThreadReadRequest
  , agentThreadInterruptRequest
  , agentThreadPlanFromThreadStartOptions
  , agentThreadStartRequest
  , agentTurnStartRequest
  )
import CodexWatcher.Workflow.Agent.Ids (RequestId)
import CodexWatcher.Workflow.Agent.Types
  ( AgentTurnPlan (..)
  , AgentThreadPlan (..)
  , AgentThreadStart (..)
  , AgentTurnInterrupt (..)
  , AgentTurnReadResult (..)
  , AgentTurnStart (..)
  , TurnRef (..)
  )
import Data.Aeson (Value)

parseAgentThreadStart :: AgentThreadPlan -> Value -> Either AppServerClientFailure AgentThreadStart
parseAgentThreadStart plan value = do
  threadId <- parseThreadStartThreadId value
  pure
    AgentThreadStart
      { agentThreadStartRoleId = plan.agentThreadPlanRoleId
      , agentThreadStartThreadId = threadId
      }

parseAgentTurnStart :: AgentTurnPlan -> Value -> Either AppServerClientFailure AgentTurnStart
parseAgentTurnStart plan value = do
  turnId <- parseTurnStartTurnId value
  pure
    AgentTurnStart
      { agentTurnStartRoleId = plan.agentTurnPlanRoleId
      , agentTurnStartThreadId = plan.agentTurnPlanThreadId
      , agentTurnStartTurnId = turnId
      }

parseAgentTurnReadResult :: TurnRef agentRole output -> Value -> Either AppServerClientFailure (AgentTurnReadResult AppServerTurn)
parseAgentTurnReadResult turnRef value = do
  turns <- parseThreadReadTurns value
  pure
    AgentTurnReadResult
      { agentTurnReadTurn = latestTurnById turnRef.turnRefTurnId turns
      , agentTurnReadThreadSystemError = threadSystemError value
      }

parseAgentTurnInterrupt :: TurnRef agentRole output -> Value -> Either AppServerClientFailure AgentTurnInterrupt
parseAgentTurnInterrupt turnRef _value =
  Right
    AgentTurnInterrupt
      { agentTurnInterruptThreadId = turnRef.turnRefThreadId
      , agentTurnInterruptTurnId = turnRef.turnRefTurnId
      }

startAgentTurn
  :: Monad m
  => AppServerInterpreter m
  -> RequestId
  -> AgentTurnPlan
  -> m (Either AppServerClientFailure AgentTurnStart)
startAgentTurn interpreter requestId plan =
  parseAgentTurnStart plan <$> interpreter.appServerSendRequest (agentTurnStartRequest requestId plan)

startAgentThread
  :: Monad m
  => AppServerInterpreter m
  -> RequestId
  -> AgentThreadPlan
  -> m (Either AppServerClientFailure AgentThreadStart)
startAgentThread interpreter requestId plan =
  parseAgentThreadStart plan <$> interpreter.appServerSendRequest (agentThreadStartRequest requestId plan)

readAgentTurn
  :: Monad m
  => AppServerInterpreter m
  -> RequestId
  -> TurnRef agentRole output
  -> m (Either AppServerClientFailure (AgentTurnReadResult AppServerTurn))
readAgentTurn interpreter requestId turnRef =
  parseAgentTurnReadResult turnRef <$> interpreter.appServerSendRequest (agentThreadReadRequest requestId turnRef)

interruptAgentTurn
  :: Monad m
  => AppServerInterpreter m
  -> RequestId
  -> TurnRef agentRole output
  -> m (Either AppServerClientFailure AgentTurnInterrupt)
interruptAgentTurn interpreter requestId turnRef =
  parseAgentTurnInterrupt turnRef <$> interpreter.appServerSendRequest (agentThreadInterruptRequest requestId turnRef)

cachedAgentTurnStartInterpreter :: Monad m => AppServerInterpreter m -> AppServerRequest -> Value -> AppServerInterpreter m
cachedAgentTurnStartInterpreter interpreter expectedRequest response =
  AppServerInterpreter \request ->
    if request == expectedRequest
      then pure response
      else interpreter.appServerSendRequest request
