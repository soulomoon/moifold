{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Typed agent role metadata, thread and turn plans, turn references, retry
-- decisions, and side-effect scope labels. Concrete role scheduling and prompt
-- policy remain outside the adapter package.
module CodexWatcher.Workflow.Agent.Types
  ( AgentRoleId (..)
  , AgentRetryDecision (..)
  , AgentRetryPolicy (..)
  , AgentRetryReason (..)
  , AgentSideEffectScope (..)
  , AgentThreadPlan (..)
  , AgentThreadStart (..)
  , AgentTurnInterrupt (..)
  , AgentTurnPlan (..)
  , AgentTurnReadFailure (..)
  , AgentTurnReadResult (..)
  , AgentTurnStart (..)
  , TurnRef (..)
  , agentRetryDecision
  , defaultAgentRetryPolicy
  , agentTurnStartRef
  ) where

import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)
import Data.Aeson (Value)
import Data.Text (Text)

newtype AgentRoleId = AgentRoleId
  { unAgentRoleId :: Text
  }
  deriving stock (Eq, Ord, Show)

data AgentThreadPlan = AgentThreadPlan
  { agentThreadPlanRoleId :: AgentRoleId
  , agentThreadPlanCwd :: FilePath
  , agentThreadPlanApprovalPolicy :: Text
  , agentThreadPlanSandbox :: Text
  , agentThreadPlanModel :: Text
  , agentThreadPlanDeveloperInstructions :: Text
  }
  deriving stock (Eq, Show)

data AgentThreadStart = AgentThreadStart
  { agentThreadStartRoleId :: AgentRoleId
  , agentThreadStartThreadId :: ThreadId
  }
  deriving stock (Eq, Show)

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

data AgentTurnInterrupt = AgentTurnInterrupt
  { agentTurnInterruptThreadId :: ThreadId
  , agentTurnInterruptTurnId :: TurnId
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

agentTurnStartRef :: AgentTurnStart -> TurnRef agentRole output
agentTurnStartRef turnStart =
  TurnRef
    { turnRefThreadId = turnStart.agentTurnStartThreadId
    , turnRefTurnId = turnStart.agentTurnStartTurnId
    }

data AgentRetryReason
  = RetryMalformedOutput
  | RetryIncompleteOutput
  | RetryTransientFailure
  deriving stock (Eq, Show)

data AgentRetryDecision
  = AgentRetryAllowed AgentRetryReason
  | AgentRetryExhausted AgentRetryReason
  | AgentRetryNotApplicable
  deriving stock (Eq, Show)

data AgentRetryPolicy = AgentRetryPolicy
  { agentMaxMalformedRetries :: Int
  , agentMaxIncompleteRetries :: Int
  , agentMaxTransientFailureRetries :: Int
  }
  deriving stock (Eq, Show)

data AgentSideEffectScope
  = AgentReadOnly
  | AgentWritesWorktree
  | AgentMutatesRemote
  | AgentUnknownSideEffects
  deriving stock (Eq, Show)

defaultAgentRetryPolicy :: AgentRetryPolicy
defaultAgentRetryPolicy =
  AgentRetryPolicy
    { agentMaxMalformedRetries = 2
    , agentMaxIncompleteRetries = 3
    , agentMaxTransientFailureRetries = 5
    }

agentRetryDecision :: AgentRetryPolicy -> AgentRetryReason -> Int -> AgentRetryDecision
agentRetryDecision policy reason attemptsSoFar
  | attemptsSoFar < maxAttempts reason =
      AgentRetryAllowed reason
  | otherwise =
      AgentRetryExhausted reason
 where
  maxAttempts = \case
    RetryMalformedOutput -> policy.agentMaxMalformedRetries
    RetryIncompleteOutput -> policy.agentMaxIncompleteRetries
    RetryTransientFailure -> policy.agentMaxTransientFailureRetries
