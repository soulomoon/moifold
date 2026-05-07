{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.EventLog.Core
  ( EventLogFixtureContract (..)
  , WorkflowReplayFailure (..)
  , WorkflowReplaySummary (..)
  , WorkflowTransitionFailure (..)
  , formatWorkflowReplayFailure
  , replayWorkflowEventLog
  , replayWorkflowEventLogDetailed
  , validateEventLogFixtureContract
  ) where

import CodexWatcher.Workflow.Spec (WorkflowSpec (..))
import Data.Text (Text)
import Data.Text qualified as Text

data WorkflowTransitionFailure spec = WorkflowTransitionFailure
  { workflowTransitionEvent :: WorkflowEvent spec
  , workflowTransitionError :: WorkflowError spec
  }

data EventLogFixtureContract spec = EventLogFixtureContract
  { fixtureExpectedStateLabel :: Text
  , fixtureExpectedEventCount :: Maybe Int
  }

data WorkflowReplayFailure spec = WorkflowReplayFailure
  { workflowReplayFailureEventIndex :: Int
  , workflowReplayFailureEvent :: Maybe (WorkflowEvent spec)
  , workflowReplayFailureEventLabel :: Text
  , workflowReplayFailurePriorStateLabel :: Maybe Text
  , workflowReplayFailureReason :: Text
  }

data WorkflowReplaySummary spec = WorkflowReplaySummary
  { workflowReplaySummaryState :: WorkflowState spec
  , workflowReplaySummaryEffects :: [WorkflowEffectPlan spec]
  , workflowReplaySummaryEventCount :: Int
  , workflowReplaySummaryTerminalEventIndex :: Maybe Int
  }

replayWorkflowEventLog
  :: forall spec. WorkflowSpec spec
  => [WorkflowEvent spec]
  -> Either (WorkflowError spec) (WorkflowReplayResult spec)
replayWorkflowEventLog =
  workflowReplayEvents @spec

replayWorkflowEventLogDetailed
  :: forall spec. WorkflowSpec spec
  => (WorkflowError spec -> Text)
  -> [WorkflowEvent spec]
  -> Either (WorkflowReplayFailure spec) (WorkflowReplaySummary spec)
replayWorkflowEventLogDetailed renderError = \case
  [] ->
    Left
      WorkflowReplayFailure
        { workflowReplayFailureEventIndex = 1
        , workflowReplayFailureEvent = Nothing
        , workflowReplayFailureEventLabel = "<empty>"
        , workflowReplayFailurePriorStateLabel = Nothing
        , workflowReplayFailureReason = "event log is empty"
        }
  firstEvent : restEvents ->
    case workflowInitialEvent @spec firstEvent of
      Left reason ->
        Left
          WorkflowReplayFailure
            { workflowReplayFailureEventIndex = 1
            , workflowReplayFailureEvent = Just firstEvent
            , workflowReplayFailureEventLabel = workflowEventLabel @spec firstEvent
            , workflowReplayFailurePriorStateLabel = Nothing
            , workflowReplayFailureReason = renderError reason
            }
      Right (initialState, initialEffects) ->
        replayRest
          2
          initialState
          [initialEffects]
          (terminalIndex @spec 1 initialState Nothing)
          restEvents
 where
  replayRest index state effects maybeTerminalIndex = \case
    [] ->
      Right
        WorkflowReplaySummary
          { workflowReplaySummaryState = state
          , workflowReplaySummaryEffects = reverse effects
          , workflowReplaySummaryEventCount = index - 1
          , workflowReplaySummaryTerminalEventIndex = maybeTerminalIndex
          }
    event : rest ->
      case workflowApplyEvent @spec state event of
        Left reason ->
          Left
            WorkflowReplayFailure
              { workflowReplayFailureEventIndex = index
              , workflowReplayFailureEvent = Just event
              , workflowReplayFailureEventLabel = workflowEventLabel @spec event
              , workflowReplayFailurePriorStateLabel = Just (workflowStateLabel @spec state)
              , workflowReplayFailureReason = renderError reason
              }
        Right (state', eventEffects) ->
          replayRest
            (index + 1)
            state'
            (eventEffects : effects)
            (terminalIndex @spec index state' maybeTerminalIndex)
            rest

terminalIndex :: forall spec. WorkflowSpec spec => Int -> WorkflowState spec -> Maybe Int -> Maybe Int
terminalIndex index state current =
  case current of
    Just terminal -> Just terminal
    Nothing ->
      if workflowIsTerminal @spec state
        then Just index
        else Nothing

validateEventLogFixtureContract
  :: forall spec. WorkflowSpec spec
  => EventLogFixtureContract spec
  -> WorkflowReplaySummary spec
  -> Either Text ()
validateEventLogFixtureContract contract summary
  | workflowStateLabel @spec summary.workflowReplaySummaryState /= contract.fixtureExpectedStateLabel =
      Left
        ( "expected final state "
            <> contract.fixtureExpectedStateLabel
            <> ", got "
            <> workflowStateLabel @spec summary.workflowReplaySummaryState
        )
  | Just expectedCount <- contract.fixtureExpectedEventCount
  , summary.workflowReplaySummaryEventCount /= expectedCount =
      Left
        ( "expected "
            <> showText expectedCount
            <> " events, got "
            <> showText summary.workflowReplaySummaryEventCount
        )
  | otherwise =
      Right ()

formatWorkflowReplayFailure :: WorkflowReplayFailure spec -> Text
formatWorkflowReplayFailure failure =
  "event "
    <> showText failure.workflowReplayFailureEventIndex
    <> " ("
    <> failure.workflowReplayFailureEventLabel
    <> "): "
    <> maybe "" (\label -> "after " <> label <> ": ") failure.workflowReplayFailurePriorStateLabel
    <> failure.workflowReplayFailureReason

showText :: Show a => a -> Text
showText =
  Text.pack . show
