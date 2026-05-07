{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}

module CodexWatcher.Workflow.Agent
  ( AgentOutputClass (..)
  , AgentRole (..)
  , ClassifiedAgentOutput (..)
  , agentOutputRetryReason
  , module CodexWatcher.Workflow.Agent.Types
  , classifyAgentRoleTurn
  ) where

import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)
import CodexWatcher.Workflow.Agent.Types
import Data.Aeson (Value)
import Data.Text (Text)

data AgentOutputClass
  = AgentComplete
  | AgentIncomplete
  | AgentBlocked
  | AgentProblems
  | AgentClean
  | AgentNoop
  | AgentMalformed
  deriving stock (Eq, Show)

data ClassifiedAgentOutput output = ClassifiedAgentOutput
  { classifiedOutputClass :: AgentOutputClass
  , classifiedOutputPayload :: output
  }
  deriving stock (Eq, Show)

data AgentRole input output = AgentRole
  { agentRoleName :: Text
  , renderAgentInput :: input -> Text
  , agentOutputSchema :: Maybe Value
  , agentRetryPolicy :: AgentRetryPolicy
  , agentSideEffectScope :: AgentSideEffectScope
  , agentClassifyTurn :: AppServerTurn -> Either Text (ClassifiedAgentOutput output)
  }

classifyAgentRoleTurn :: AgentRole input output -> AppServerTurn -> Either Text (ClassifiedAgentOutput output)
classifyAgentRoleTurn =
  agentClassifyTurn

agentOutputRetryReason :: AgentOutputClass -> Maybe AgentRetryReason
agentOutputRetryReason = \case
  AgentIncomplete -> Just RetryIncompleteOutput
  AgentMalformed -> Just RetryMalformedOutput
  AgentComplete -> Nothing
  AgentBlocked -> Nothing
  AgentProblems -> Nothing
  AgentClean -> Nothing
  AgentNoop -> Nothing
