{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Workflow.Agent
  ( AgentOutputClass (..)
  , AgentRole (..)
  , ClassifiedAgentOutput (..)
  , module CodexWatcher.Workflow.Agent.Types
  , classifyAgentRoleTurn
  ) where

import CodexWatcher.AppServerClient (AppServerTurn)
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
  , agentClassifyTurn :: AppServerTurn -> Either Text (ClassifiedAgentOutput output)
  }

classifyAgentRoleTurn :: AgentRole input output -> AppServerTurn -> Either Text (ClassifiedAgentOutput output)
classifyAgentRoleTurn =
  agentClassifyTurn
