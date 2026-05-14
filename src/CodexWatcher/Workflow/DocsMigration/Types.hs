{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Workflow.DocsMigration.Types
  ( DocsMigrationAction (..)
  , DocsMigrationActionReport (..)
  , DocsMigrationConfig (..)
  , DocsMigrationEffect (..)
  , DocsMigrationEvent (..)
  , DocsMigrationIndexedBlocked
  , DocsMigrationIndexedComplete
  , DocsMigrationIndexedDraftReady
  , DocsMigrationIndexedEffect (..)
  , DocsMigrationIndexedEffectPlan (..)
  , DocsMigrationIndexedEvent (..)
  , DocsMigrationIndexedObservation (..)
  , DocsMigrationIndexedObservedTick (..)
  , DocsMigrationIndexedReady
  , DocsMigrationIndexedReplayResult (..)
  , DocsMigrationIndexedState (..)
  , DocsMigrationIndexedTurnActive
  , DocsMigrationIndexedUninitialized
  , DocsMigrationIndexedValidated
  , DocsMigrationIndexedWorkflow
  , DocsMigrationInterpreter (..)
  , DocsMigrationObservation (..)
  , DocsMigrationOutput (..)
  , DocsMigrationReplayResult (..)
  , DocsMigrationState (..)
  , DocsMigrationTick (..)
  ) where

import CodexWatcher.Workflow.Agent
  ( ClassifiedAgentOutput
  , TurnRef
  )
import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)
import CodexWatcher.Workflow.Execution (ActionExecutionMode)
import Data.Aeson (FromJSON (..), (.:), (.:?), (.!=), withObject)
import Data.Text (Text)

data DocsMigrationIndexedWorkflow

data DocsMigrationIndexedUninitialized

data DocsMigrationIndexedReady

data DocsMigrationIndexedTurnActive

data DocsMigrationIndexedDraftReady

data DocsMigrationIndexedValidated

data DocsMigrationIndexedComplete

data DocsMigrationIndexedBlocked

newtype DocsMigrationIndexedState state =
  DocsMigrationIndexedState
    { docsMigrationIndexedStateValue :: DocsMigrationState
    }
  deriving stock (Eq, Show)

data DocsMigrationIndexedEvent source target = DocsMigrationIndexedEvent
  { docsMigrationIndexedEventSourceLabel :: Text
  , docsMigrationIndexedEventTargetLabel :: Text
  , docsMigrationIndexedEventValue :: DocsMigrationEvent
  }
  deriving stock (Eq, Show)

data DocsMigrationIndexedObservation source target = DocsMigrationIndexedObservation
  { docsMigrationIndexedObservationSourceLabel :: Text
  , docsMigrationIndexedObservationTargetLabel :: Text
  , docsMigrationIndexedObservationValue :: DocsMigrationObservation
  }
  deriving stock (Eq, Show)

data DocsMigrationIndexedObservedTick source target = DocsMigrationIndexedObservedTick
  { docsMigrationIndexedObservedTickSourceLabel :: Text
  , docsMigrationIndexedObservedTickTargetLabel :: Text
  , docsMigrationIndexedObservedTickValue :: DocsMigrationTick
  }
  deriving stock (Eq, Show)

newtype DocsMigrationIndexedEffect source target =
  DocsMigrationIndexedEffect
    { docsMigrationIndexedEffectValue :: DocsMigrationEffect
    }
  deriving stock (Eq, Show)

newtype DocsMigrationIndexedEffectPlan source target =
  DocsMigrationIndexedEffectPlan
    { docsMigrationIndexedEffectPlanValues :: [DocsMigrationEffect]
    }
  deriving stock (Eq, Show)

newtype DocsMigrationIndexedReplayResult state =
  DocsMigrationIndexedReplayResult
    { docsMigrationIndexedReplayValue :: DocsMigrationReplayResult
    }
  deriving stock (Eq, Show)

data DocsMigrationConfig = DocsMigrationConfig
  { docsMigrationSource :: FilePath
  , docsMigrationTarget :: FilePath
  , docsMigrationGoal :: Text
  }
  deriving stock (Eq, Show)

data DocsMigrationOutput = DocsMigrationOutput
  { docsMigrationOutputDraft :: Text
  , docsMigrationOutputSummary :: Text
  }
  deriving stock (Eq, Show)

instance FromJSON DocsMigrationOutput where
  parseJSON =
    withObject "DocsMigrationOutput" $ \objectValue ->
      DocsMigrationOutput
        <$> objectValue .: "draft_markdown"
        <*> objectValue .:? "summary" .!= "docs migration draft produced"

data DocsMigrationState
  = DocsMigrationReady DocsMigrationConfig
  | DocsMigrationTurnActive DocsMigrationConfig (TurnRef () DocsMigrationOutput)
  | DocsMigrationDraftReady DocsMigrationConfig Text
  | DocsMigrationValidated DocsMigrationConfig Text
  | DocsMigrationComplete Text
  | DocsMigrationBlocked Text
  deriving stock (Eq, Show)

data DocsMigrationEvent
  = DocsMigrationInitialized DocsMigrationConfig
  | DocsMigrationTurnStarted ThreadId TurnId
  | DocsMigrationDraftProduced Text Text
  | DocsMigrationValidationPassed Text
  | DocsMigrationWorkflowBlocked Text
  | DocsMigrationWorkflowCompleted Text
  deriving stock (Eq, Show)

data DocsMigrationObservation
  = DocsMigrationAgentReturned (ClassifiedAgentOutput DocsMigrationOutput)
  | DocsMigrationValidationReturned Bool Text
  deriving stock (Eq, Show)

data DocsMigrationEffect
  = StartDocsMigrationTurn DocsMigrationConfig
  | WriteDocsMigrationDraft FilePath Text
  | RunDocsMigrationValidation FilePath
  | StopDocsMigrationDaemon
  deriving stock (Eq, Show)

data DocsMigrationAction
  = StartDocsMigrationTurnAction DocsMigrationConfig
  | WriteDocsMigrationDraftAction FilePath Text
  | RunDocsMigrationValidationAction FilePath
  | StopDocsMigrationDaemonAction
  deriving stock (Eq, Show)

data DocsMigrationActionReport = DocsMigrationActionReport
  { docsMigrationActionReportMode :: ActionExecutionMode
  , docsMigrationActionReportAction :: DocsMigrationAction
  , docsMigrationActionReportExecuted :: Bool
  }
  deriving stock (Eq, Show)

data DocsMigrationInterpreter m = DocsMigrationInterpreter
  { docsMigrationStartTurn :: DocsMigrationConfig -> m ()
  , docsMigrationWriteDraft :: FilePath -> Text -> m ()
  , docsMigrationRunValidation :: FilePath -> m ()
  , docsMigrationStopDaemon :: m ()
  }

data DocsMigrationTick = DocsMigrationTick
  { docsMigrationTickEvent :: DocsMigrationEvent
  , docsMigrationTickState :: DocsMigrationState
  , docsMigrationTickEffects :: [DocsMigrationEffect]
  }
  deriving stock (Eq, Show)

data DocsMigrationReplayResult = DocsMigrationReplayResult
  { docsMigrationReplayState :: DocsMigrationState
  , docsMigrationReplayEffects :: [[DocsMigrationEffect]]
  }
  deriving stock (Eq, Show)
