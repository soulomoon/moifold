{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Workflow.Agent
  ( AgentOutputClass (..)
  , AgentRole (..)
  , ClassifiedAgentOutput (..)
  , TurnRef (..)
  , classifyAgentRoleTurn
  ) where

import CodexWatcher.AppServerClient (AppServerTurn)
import CodexWatcher.Core.Ids (ThreadId, TurnId)
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

data TurnRef agentRole output = TurnRef
  { turnRefThreadId :: ThreadId
  , turnRefTurnId :: TurnId
  }
  deriving stock (Eq, Show)

classifyAgentRoleTurn :: AgentRole input output -> AppServerTurn -> Either Text (ClassifiedAgentOutput output)
classifyAgentRoleTurn =
  agentClassifyTurn
