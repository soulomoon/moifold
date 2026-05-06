{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.EventLog
  ( EventLogFixtureContract (..)
  , WorkflowTransitionFailure (..)
  , applyMoifoldWorkflowEvent
  , initializeMoifoldWorkflow
  , replayMoifoldWorkflowEvents
  , replayWorkflowEventLog
  ) where

import CodexWatcher.Effects (EffectPlan)
import CodexWatcher.EventLog.Replay (applyEvent, initializeFromEvent, replayEventLog)
import CodexWatcher.EventLog.Types (EventReplayResult, ReplayFailure, WatcherEvent)
import CodexWatcher.Core.State (SomeWatcherState)
import CodexWatcher.Workflow.Types (WorkflowSpec (..))
import Data.Text (Text)

data WorkflowTransitionFailure spec = WorkflowTransitionFailure
  { workflowTransitionEvent :: WorkflowEvent spec
  , workflowTransitionError :: WorkflowError spec
  }

data EventLogFixtureContract spec = EventLogFixtureContract
  { fixtureExpectedStateLabel :: Text
  , fixtureExpectedEventCount :: Maybe Int
  }

replayWorkflowEventLog
  :: forall spec. WorkflowSpec spec
  => [WorkflowEvent spec]
  -> Either (WorkflowError spec) (WorkflowReplayResult spec)
replayWorkflowEventLog =
  workflowReplayEvents @spec

initializeMoifoldWorkflow :: WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
initializeMoifoldWorkflow =
  initializeFromEvent

applyMoifoldWorkflowEvent :: SomeWatcherState -> WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
applyMoifoldWorkflowEvent =
  applyEvent

replayMoifoldWorkflowEvents :: [WatcherEvent] -> Either ReplayFailure EventReplayResult
replayMoifoldWorkflowEvents =
  replayEventLog
