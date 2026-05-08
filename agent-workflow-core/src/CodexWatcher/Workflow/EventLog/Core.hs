{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

-- | Pure workflow event-log replay helpers, fixture contracts, replay
-- summaries, and transition diagnostics. The core package does not read files,
-- execute effects, or own concrete event schemas.
module CodexWatcher.Workflow.EventLog.Core
  ( EventLogFixtureContract (..)
  , WorkflowReplayFailure (..)
  , WorkflowReplaySummary (..)
  , WorkflowTransitionFailure (..)
  , applyWorkflowEvent
  , formatWorkflowReplayFailure
  , formatWorkflowTransitionFailure
  , initializeWorkflowEvent
  , replayWorkflowEventLog
  , replayWorkflowEventLogDetailed
  , validateEventLogFixtureContract
  ) where

import CodexWatcher.Workflow.Spec (WorkflowSpec (..))
import Data.Text (Text)
import Data.Text qualified as Text

data WorkflowTransitionFailure spec = WorkflowTransitionFailure
  { workflowTransitionEvent :: WorkflowEvent spec
  , workflowTransitionEventLabel :: Text
  , workflowTransitionPriorStateLabel :: Maybe Text
  , workflowTransitionError :: WorkflowError spec
  , workflowTransitionReason :: Text
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

initializeWorkflowEvent
  :: forall spec. WorkflowSpec spec
  => (WorkflowError spec -> Text)
  -> WorkflowEvent spec
  -> Either (WorkflowTransitionFailure spec) (WorkflowState spec, WorkflowEffectPlan spec)
initializeWorkflowEvent renderError event =
  case workflowInitialEvent @spec event of
    Left reason ->
      Left (workflowTransitionFailure @spec renderError Nothing event reason)
    Right initialized ->
      Right initialized

applyWorkflowEvent
  :: forall spec. WorkflowSpec spec
  => (WorkflowError spec -> Text)
  -> WorkflowState spec
  -> WorkflowEvent spec
  -> Either (WorkflowTransitionFailure spec) (WorkflowState spec, WorkflowEffectPlan spec)
applyWorkflowEvent renderError state event =
  case workflowApplyEvent @spec state event of
    Left reason ->
      Left (workflowTransitionFailure @spec renderError (Just state) event reason)
    Right applied ->
      Right applied

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
    case initializeWorkflowEvent @spec renderError firstEvent of
      Left failure ->
        Left (replayFailureFromTransition 1 failure)
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
      case applyWorkflowEvent @spec renderError state event of
        Left failure ->
          Left (replayFailureFromTransition index failure)
        Right (state', eventEffects) ->
          replayRest
            (index + 1)
            state'
            (eventEffects : effects)
            (terminalIndex @spec index state' maybeTerminalIndex)
            rest

workflowTransitionFailure
  :: forall spec. WorkflowSpec spec
  => (WorkflowError spec -> Text)
  -> Maybe (WorkflowState spec)
  -> WorkflowEvent spec
  -> WorkflowError spec
  -> WorkflowTransitionFailure spec
workflowTransitionFailure renderError maybeState event errorValue =
  WorkflowTransitionFailure
    { workflowTransitionEvent = event
    , workflowTransitionEventLabel = workflowEventLabel @spec event
    , workflowTransitionPriorStateLabel = workflowStateLabel @spec <$> maybeState
    , workflowTransitionError = errorValue
    , workflowTransitionReason = renderError errorValue
    }

replayFailureFromTransition :: Int -> WorkflowTransitionFailure spec -> WorkflowReplayFailure spec
replayFailureFromTransition index failure =
  WorkflowReplayFailure
    { workflowReplayFailureEventIndex = index
    , workflowReplayFailureEvent = Just failure.workflowTransitionEvent
    , workflowReplayFailureEventLabel = failure.workflowTransitionEventLabel
    , workflowReplayFailurePriorStateLabel = failure.workflowTransitionPriorStateLabel
    , workflowReplayFailureReason = failure.workflowTransitionReason
    }

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

formatWorkflowTransitionFailure :: WorkflowTransitionFailure spec -> Text
formatWorkflowTransitionFailure failure =
  "event ("
    <> failure.workflowTransitionEventLabel
    <> "): "
    <> maybe "" (\label -> "after " <> label <> ": ") failure.workflowTransitionPriorStateLabel
    <> failure.workflowTransitionReason

showText :: Show a => a -> Text
showText =
  Text.pack . show
