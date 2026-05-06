{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Observation.Agent
  ( classifiedAgentTurnObservation
  , classifiedAgentTurnObservationPayload
  , planAgentTurnObservation
  ) where

import CodexWatcher.AppServerClient (AppServerTurn)
import CodexWatcher.Workflow.Agent
  ( AgentRole
  , ClassifiedAgentOutput (..)
  , classifyAgentRoleTurn
  )
import CodexWatcher.Workflow.Spec
  ( PlannedTransition
  , WorkflowSpec (..)
  , workflowPlanObservation
  )
import Data.Text (Text)

classifiedAgentTurnObservation
  :: AgentRole input output
  -> (output -> observation)
  -> AppServerTurn
  -> Either Text (ClassifiedAgentOutput observation)
classifiedAgentTurnObservation role toObservation turn =
  mapClassifiedAgentOutput toObservation <$> classifyAgentRoleTurn role turn

classifiedAgentTurnObservationPayload
  :: AgentRole input output
  -> (output -> observation)
  -> AppServerTurn
  -> Maybe observation
classifiedAgentTurnObservationPayload role toObservation turn =
  case classifiedAgentTurnObservation role toObservation turn of
    Right classified ->
      Just (classifiedOutputPayload classified)
    Left _ ->
      Nothing

planAgentTurnObservation
  :: (WorkflowSpec spec, WorkflowError spec ~ Text)
  => WorkflowState spec
  -> AgentRole input output
  -> (output -> WorkflowObservation spec)
  -> AppServerTurn
  -> Either Text (PlannedTransition spec)
planAgentTurnObservation state role toObservation turn = do
  classified <- classifiedAgentTurnObservation role toObservation turn
  workflowPlanObservation state (classifiedOutputPayload classified)

mapClassifiedAgentOutput :: (output -> observation) -> ClassifiedAgentOutput output -> ClassifiedAgentOutput observation
mapClassifiedAgentOutput toObservation classified =
  ClassifiedAgentOutput
    { classifiedOutputClass = classifiedOutputClass classified
    , classifiedOutputPayload = toObservation (classifiedOutputPayload classified)
    }
